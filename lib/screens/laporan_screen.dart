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
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> payments = [];
  bool loading = false;
  bool exporting = false;

  String statusFilter = 'Semua status';
  String customerFilter = 'Semua pelanggan';
  String agingFilter = 'Semua umur';

  String _err(Object e) => e.toString().replaceFirst(
        RegExp(r'^Exception:\s*'),
        '',
      );

  int _i(dynamic value) => (value as num?)?.toInt() ?? 0;

  DateTime _d(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse('$value') ?? DateTime.now();
  }

  String _status(Map<String, dynamic> row) {
    final kredit = _i(row['jumlah']);
    final dibayar = _i(row['total_dibayar']);
    if (kredit > 0 && dibayar >= kredit) return 'Lunas';
    if (dibayar > 0) return 'Sebagian';
    return 'Belum lunas';
  }

  int _age(Map<String, dynamic> row) {
    final days = DateTime.now().difference(_d(row['tanggal'])).inDays;
    return days < 0 ? 0 : days;
  }

  String _ageLabel(Map<String, dynamic> row) {
    final days = _age(row);
    if (days <= 7) return '0–7 hari';
    if (days <= 30) return '8–30 hari';
    if (days <= 60) return '31–60 hari';
    if (days <= 90) return '61–90 hari';
    return '>90 hari';
  }

  List<Map<String, dynamic>> get filteredRows {
    return rows.where((row) {
      final name = '${row['nama_pelanggan'] ?? ''}';
      final customerMatch =
          customerFilter == 'Semua pelanggan' || name == customerFilter;
      final statusMatch =
          statusFilter == 'Semua status' || _status(row) == statusFilter;
      final outstanding = _i(row['jumlah']) - _i(row['total_dibayar']);
      final agingMatch = agingFilter == 'Semua umur' ||
          (outstanding > 0 && _ageLabel(row) == agingFilter);
      return customerMatch && statusMatch && agingMatch;
    }).toList();
  }

  Future<void> _load() async {
    if (dari.isAfter(sampai)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal mulai tidak boleh lebih besar dari tanggal akhir.'),
          ),
        );
      }
      return;
    }

    setState(() => loading = true);
    try {
      final provider = context.read<PiutangProvider>();
      final result = await provider.rekapPeriode(dari, sampai);
      final paymentResult = await provider.pembayaranPeriode(dari, sampai);
      if (mounted) {
        setState(() {
          rows = result;
          payments = paymentResult;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e))),
        );
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

    setState(() {
      if (start) {
        dari = selected;
      } else {
        sampai = selected;
      }
    });
    await _load();
  }

  Future<void> _chooseCustomer() async {
    final list = context.read<PiutangProvider>().daftarPelanggan;
    final controller = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = controller.text.trim().toLowerCase();
            final filtered = list
                .where((customer) =>
                    customer.nama.toLowerCase().contains(query))
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * .75,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Pilih Pelanggan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Ketik nama pelanggan...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.people_outline),
                              title: const Text('Semua pelanggan'),
                              onTap: () => Navigator.pop(
                                sheetContext,
                                'Semua pelanggan',
                              ),
                            ),
                            ...filtered.map(
                              (customer) => ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(customer.nama),
                                onTap: () => Navigator.pop(
                                  sheetContext,
                                  customer.nama,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    if (result != null && mounted) {
      setState(() => customerFilter = result);
    }
  }

  void _reset() {
    setState(() {
      statusFilter = 'Semua status';
      customerFilter = 'Semua pelanggan';
      agingFilter = 'Semua umur';
    });
  }

  Future<void> _pdf() async {
    final data = filteredRows;
    if (exporting || data.isEmpty) return;

    setState(() => exporting = true);
    try {
      await ExportService.exportRekapKePdf(data, dari, sampai);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor PDF: ${_err(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _excel() async {
    final data = filteredRows;
    if (exporting || data.isEmpty) return;

    setState(() => exporting = true);
    try {
      await ExportService.exportRekapKeExcel(
        data,
        dari: dari,
        sampai: sampai,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor Excel: ${_err(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
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
    final data = filteredRows;
    final kredit = data.fold<int>(
      0,
      (total, row) => total + _i(row['jumlah']),
    );
    final dibayar = data.fold<int>(
      0,
      (total, row) => total + _i(row['total_dibayar']),
    );
    final periode = data.fold<int>(
      0,
      (total, row) => total + _i(row['dibayar_periode']),
    );
    final sisa = data.fold<int>(
      0,
      (total, row) => total +
          (_i(row['jumlah']) - _i(row['total_dibayar']))
              .clamp(0, _i(row['jumlah']))
              .toInt(),
    );
    final lunas = data.where((row) => _status(row) == 'Lunas').length;
    final belum = data.where((row) => _status(row) != 'Lunas').length;
    final active = statusFilter != 'Semua status' ||
        customerFilter != 'Semua pelanggan' ||
        agingFilter != 'Semua umur';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Laporan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: exporting
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportHeaderSettingsScreen(),
                      ),
                    ),
            icon: const Icon(Icons.business_outlined),
            tooltip: 'Header laporan',
          ),
          IconButton(
            onPressed: data.isEmpty || exporting ? null : _pdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
          ),
          IconButton(
            onPressed: data.isEmpty || exporting ? null : _excel,
            icon: const Icon(Icons.table_view),
            tooltip: 'Export Excel',
          ),
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
                          Text(
                            'Periode: ${Formatter.tanggalPendek(dari)} – ${Formatter.tanggalPendek(sampai)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter Laporan',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Status piutang',
                              prefixIcon: Icon(Icons.filter_alt_outlined),
                            ),
                            items: const [
                              'Semua status',
                              'Belum lunas',
                              'Sebagian',
                              'Lunas',
                            ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(
                              () => statusFilter = value ?? 'Semua status',
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: _chooseCustomer,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Pelanggan',
                                prefixIcon: Icon(Icons.person_search_outlined),
                                suffixIcon: Icon(Icons.chevron_right),
                              ),
                              child: Text(customerFilter),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: agingFilter,
                            decoration: const InputDecoration(
                              labelText: 'Umur piutang',
                              prefixIcon: Icon(Icons.schedule_outlined),
                            ),
                            items: const [
                              'Semua umur',
                              '0–7 hari',
                              '8–30 hari',
                              '31–60 hari',
                              '61–90 hari',
                              '>90 hari',
                            ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(
                              () => agingFilter = value ?? 'Semua umur',
                            ),
                          ),
                          if (active)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _reset,
                                icon: const Icon(Icons.clear),
                                label: const Text('Reset filter'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.primary,
                        child: const Icon(Icons.payments_outlined),
                      ),
                      title: const Text(
                        'Laporan Pembayaran',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text('Filter pembayaran dan export PDF/Excel'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LaporanPembayaranScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _summary(
                        'Total kredit',
                        kredit,
                        Icons.receipt_long_outlined,
                        scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      _summary(
                        'Total dibayar',
                        dibayar,
                        Icons.payments_outlined,
                        scheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _summary(
                        'Sisa piutang',
                        sisa,
                        Icons.account_balance_wallet_outlined,
                        scheme.error,
                      ),
                      const SizedBox(width: 10),
                      _summary(
                        'Bayar periode',
                        periode,
                        Icons.calendar_month_outlined,
                        scheme.tertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _count(
                        'Transaksi',
                        data.length,
                        Icons.list_alt_outlined,
                        scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      _count(
                        'Lunas',
                        lunas,
                        Icons.check_circle_outline,
                        scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      _count(
                        'Belum lunas',
                        belum,
                        Icons.pending_outlined,
                        scheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rekap transaksi',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${data.length} transaksi',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (data.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          rows.isEmpty
                              ? 'Belum ada transaksi pada periode ini.'
                              : 'Tidak ada transaksi yang cocok dengan filter.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...data.map((row) {
                      final kreditRow = _i(row['jumlah']);
                      final dibayarRow = _i(row['total_dibayar']);
                      final periodeRow = _i(row['dibayar_periode']);
                      final sisaRow = (kreditRow - dibayarRow)
                          .clamp(0, kreditRow)
                          .toInt();
                      final status = _status(row);
                      final statusColor = status == 'Lunas'
                          ? scheme.primary
                          : status == 'Sebagian'
                              ? scheme.tertiary
                              : scheme.error;

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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
                              Text(
                                'Umur: ${_age(row)} hari • ${_ageLabel(row)}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const Divider(height: 18),
                              Row(
                                children: [
                                  _amount('Kredit', kreditRow),
                                  _amount('Dibayar', dibayarRow),
                                  _amount('Periode', periodeRow),
                                  _amount('Sisa', sisaRow),
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

  Widget _dateTile(String label, DateTime date, VoidCallback tap) {
    return Expanded(
      child: InkWell(
        onTap: tap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          child: Text(Formatter.tanggalPendek(date)),
        ),
      ),
    );
  }

  Widget _summary(String label, int value, IconData icon, Color color) {
    return Expanded(
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
              Text(
                Formatter.rupiah(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _count(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amount(String label, int value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 3),
          Text(
            Formatter.rupiah(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
