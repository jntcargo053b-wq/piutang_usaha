import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/piutang_provider.dart';
import '../services/export_service.dart';
import '../utils/formatter.dart';
import 'laporan_pembayaran_screen.dart';
import 'report_header_settings_screen.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  DateTime dari = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime sampai = DateTime.now();
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> payments = <Map<String, dynamic>>[];
  bool loading = false;
  bool exporting = false;

  String _friendlyError(Object e) => e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  Future<void> _load() async {
    if (dari.isAfter(sampai)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanggal mulai tidak boleh lebih besar dari tanggal akhir.')),
        );
      }
      return;
    }
    if (mounted) setState(() => loading = true);
    try {
      final provider = context.read<PiutangProvider>();
      final r = await provider.rekapPeriode(dari, sampai);
      final p = await provider.pembayaranPeriode(dari, sampai);
      if (!mounted) return;
      setState(() {
        rows = r;
        payments = p;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? dari : sampai,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() => start ? dari = selected : sampai = selected);
    await _load();
  }

  Future<void> _exportPdf() async {
    if (exporting || rows.isEmpty) return;
    setState(() => exporting = true);
    try {
      await ExportService.exportRekapKePdf(rows, dari, sampai);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor PDF: ${_friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _exportExcel() async {
    if (exporting || rows.isEmpty) return;
    setState(() => exporting = true);
    try {
      await ExportService.exportRekapKeExcel(rows, dari: dari, sampai: sampai);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor Excel: ${_friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _openPaymentReport() async {
    if (exporting) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LaporanPembayaranScreen()),
    );
  }

  String _status(int kredit, int dibayar) {
    if (dibayar >= kredit && kredit > 0) return 'Lunas';
    if (dibayar > 0) return 'Sebagian';
    return 'Belum lunas';
  }

  Color _statusColor(ColorScheme scheme, String status) {
    switch (status) {
      case 'Lunas':
        return scheme.primary;
      case 'Sebagian':
        return scheme.tertiary;
      default:
        return scheme.error;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalKredit = rows.fold<int>(0, (sum, row) => sum + ((row['jumlah'] as num?)?.toInt() ?? 0));
    final totalDibayar = rows.fold<int>(0, (sum, row) => sum + ((row['total_dibayar'] as num?)?.toInt() ?? 0));
    final totalPembayaranPeriode = payments.fold<int>(0, (sum, row) => sum + ((row['jumlah'] as num?)?.toInt() ?? 0));
    final totalSisa = rows.fold<int>(0, (sum, row) {
      final kredit = (row['jumlah'] as num?)?.toInt() ?? 0;
      final dibayar = (row['total_dibayar'] as num?)?.toInt() ?? 0;
      return sum + (kredit - dibayar).clamp(0, kredit);
    });
    final lunas = rows.where((row) {
      final kredit = (row['jumlah'] as num?)?.toInt() ?? 0;
      final dibayar = (row['total_dibayar'] as num?)?.toInt() ?? 0;
      return dibayar >= kredit && kredit > 0;
    }).length;
    final belumLunas = rows.length - lunas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(
            onPressed: exporting
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportHeaderSettingsScreen()),
                    );
                  },
            tooltip: 'Header laporan',
            icon: const Icon(Icons.business_outlined),
          ),
          IconButton(
            onPressed: rows.isEmpty || exporting ? null : _exportPdf,
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            onPressed: rows.isEmpty || exporting ? null : _exportExcel,
            tooltip: 'Export Excel',
            icon: const Icon(Icons.table_view),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _dateTile('Dari', dari, () => _pick(true)),
                              const SizedBox(width: 10),
                              _dateTile('Sampai', sampai, () => _pick(false)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Terapkan Filter'),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Periode: ${Formatter.tanggalPendek(dari)} – ${Formatter.tanggalPendek(sampai)}',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.primary,
                        child: const Icon(Icons.payments_outlined),
                      ),
                      title: const Text('Laporan Pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Filter pembayaran dan export PDF/Excel'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openPaymentReport,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _summaryCard('Total kredit', Formatter.rupiah(totalKredit), Icons.receipt_long_outlined, scheme.primary),
                      const SizedBox(width: 10),
                      _summaryCard('Total dibayar', Formatter.rupiah(totalDibayar), Icons.payments_outlined, scheme.secondary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _summaryCard('Sisa piutang', Formatter.rupiah(totalSisa), Icons.account_balance_wallet_outlined, scheme.error),
                      const SizedBox(width: 10),
                      _summaryCard('Bayar periode', Formatter.rupiah(totalPembayaranPeriode), Icons.calendar_month_outlined, scheme.tertiary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _countCard('Transaksi', rows.length, Icons.list_alt_outlined, scheme.primary),
                      const SizedBox(width: 10),
                      _countCard('Lunas', lunas, Icons.check_circle_outline, scheme.primary),
                      const SizedBox(width: 10),
                      _countCard('Belum lunas', belumLunas, Icons.pending_outlined, scheme.error),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rekap transaksi', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${rows.length} transaksi', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: scheme.primary),
                            const SizedBox(height: 12),
                            Text('Belum ada transaksi pada periode ini.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                            const SizedBox(height: 6),
                            Text('Pilih rentang tanggal lain lalu tekan “Terapkan Filter”.', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  else
                    ...rows.map((row) {
                      final kredit = (row['jumlah'] as num?)?.toInt() ?? 0;
                      final dibayar = (row['total_dibayar'] as num?)?.toInt() ?? 0;
                      final dibayarPeriode = (row['dibayar_periode'] as num?)?.toInt() ?? 0;
                      final sisa = (kredit - dibayar).clamp(0, kredit);
                      final status = _status(kredit, dibayar);
                      final statusColor = _statusColor(scheme, status);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${row['nama_pelanggan'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${row['nomor_resi'] ?? ''} • ${row['nama_penerima'] ?? ''} • ${row['kota_tujuan'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              const Divider(height: 18),
                              Row(
                                children: [
                                  _amountColumn('Kredit', kredit),
                                  _amountColumn('Dibayar', dibayar),
                                  _amountColumn('Periode', dibayarPeriode),
                                  _amountColumn('Sisa', sisa),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.calendar_month_outlined),
            ),
            child: Text(Formatter.tanggalPendek(date)),
          ),
        ),
      );

  Widget _summaryCard(String label, String value, IconData icon, Color color) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 21, color: color),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 3),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
        ),
      );

  Widget _countCard(String label, int value, IconData icon, Color color) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 6),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 2),
                Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        ),
      );

  Widget _amountColumn(String label, int value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 3),
            Text(
              Formatter.rupiah(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}
