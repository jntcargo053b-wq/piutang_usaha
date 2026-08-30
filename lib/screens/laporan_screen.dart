import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/piutang_provider.dart';
import '../services/export_service.dart';
import '../utils/formatter.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});
  @override State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  DateTime dari = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime sampai = DateTime.now();
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> payments = [];
  bool loading = false;

  String _friendlyError(Object e) { final text = e.toString(); return text.startsWith('Exception: ') ? text.substring(11) : text; }

  Future<void> _load() async {
    if (dari.isAfter(sampai)) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal mulai tidak boleh lebih besar dari tanggal akhir.'))); return; }
    if (mounted) setState(() => loading = true);
    try {
      final provider = context.read<PiutangProvider>();
      final resultRows = await provider.rekapPeriode(dari, sampai);
      final resultPayments = await provider.pembayaranPeriode(dari, sampai);
      if (!mounted) return;
      setState(() { rows = resultRows; payments = resultPayments; });
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e)))); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _pick(bool start) async {
    final selected = await showDatePicker(context: context, initialDate: start ? dari : sampai, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (selected == null || !mounted) return;
    setState(() { if (start) { dari = selected; } else { sampai = selected; } });
  }

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); }); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalKredit = rows.fold<int>(0, (sum, row) => sum + (row['jumlah'] as num).toInt());
    final totalPembayaranPeriode = payments.fold<int>(0, (sum, row) => sum + (row['jumlah'] as num).toInt());
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan'), actions: [
        IconButton(onPressed: rows.isEmpty ? null : () => ExportService.exportRekapKePdf(rows, dari, sampai), icon: const Icon(Icons.picture_as_pdf)),
        IconButton(onPressed: rows.isEmpty ? null : () => ExportService.exportRekapKeExcel(rows), icon: const Icon(Icons.table_view)),
      ]),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(child: Row(children: [
            Expanded(child: ListTile(title: const Text('Dari'), subtitle: Text(Formatter.tanggalPendek(dari)), onTap: () => _pick(true))),
            Expanded(child: ListTile(title: const Text('Sampai'), subtitle: Text(Formatter.tanggalPendek(sampai)), onTap: () => _pick(false))),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ])),
          Card(child: ListTile(title: const Text('Kredit pada periode'), trailing: Text(Formatter.rupiah(totalKredit), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)))),
          Card(child: ListTile(title: const Text('Pembayaran diterima pada periode'), trailing: Text(Formatter.rupiah(totalPembayaranPeriode), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 8),
          Text('Rekap transaksi', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20), child: Column(children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: scheme.primary),
              const SizedBox(height: 12),
              Text('Belum ada transaksi pada periode ini.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Coba ubah rentang tanggal lalu tekan tombol refresh.', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ])))
          else
            ...rows.map((row) {
              final kredit = (row['jumlah'] as num).toInt();
              final dibayarTotal = (row['total_dibayar'] as num).toInt();
              final dibayarPeriode = (row['dibayar_periode'] as num?)?.toInt() ?? 0;
              return Card(child: ListTile(
                title: Text('${row['nama_pelanggan']} • ${row['nomor_resi']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${row['nama_penerima']} • ${row['kota_tujuan']}\nDibayar periode: ${Formatter.rupiah(dibayarPeriode)}', maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Text(Formatter.rupiah(kredit - dibayarTotal), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ));
            }),
        ],
      ),
    );
  }
}
