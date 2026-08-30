import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pelanggan.dart';
import '../models/transaksi_kredit.dart';
import '../models/pembayaran.dart';
import '../providers/piutang_provider.dart';
import '../services/customer_report_service.dart';
import '../utils/formatter.dart';

class DetailPelangganScreen extends StatefulWidget {
  final Pelanggan pelanggan;
  const DetailPelangganScreen({super.key, required this.pelanggan});

  @override
  State<DetailPelangganScreen> createState() => _DetailPelangganScreenState();
}

class _DetailPelangganScreenState extends State<DetailPelangganScreen> {
  List<TransaksiKredit> rows = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final provider = context.read<PiutangProvider>();
    final result = await provider.muatTransaksi(widget.pelanggan.id!);
    if (!mounted) return;
    setState(() { rows = result; loading = false; });
  }

  Future<Map<int, List<Pembayaran>>> _loadPembayaran() async {
    final db = context.read<PiutangProvider>().db;
    final result = <int, List<Pembayaran>>{};
    for (final transaksi in rows) {
      result[transaksi.id!] = await db.getPembayaranByTransaksi(transaksi.id!);
    }
    return result;
  }

  Future<void> _laporanPelanggan() async {
    if (loading) return;
    try {
      final pembayaran = await _loadPembayaran();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Laporan PDF'),
              subtitle: const Text('Kredit, pembayaran, dan sisa piutang'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await CustomerReportService.sharePdf(namaPelanggan: widget.pelanggan.nama, transaksi: rows, pembayaran: pembayaran);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Laporan Excel'),
              subtitle: const Text('Data kredit dan riwayat pembayaran'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await CustomerReportService.shareExcel(namaPelanggan: widget.pelanggan.nama, transaksi: rows, pembayaran: pembayaran);
              },
            ),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat laporan: $e')));
    }
  }

  Future<void> _transaksi() async {
    final formKey = GlobalKey<FormState>();
    final res = TextEditingController(), recv = TextEditingController(), city = TextEditingController(), amount = TextEditingController(), note = TextEditingController();
    DateTime date = DateTime.now(); bool saving = false;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 12),
        child: SingleChildScrollView(child: Form(key: formKey, child: Column(children: [
          Text('Tambah Transaksi Kredit', style: Theme.of(ctx).textTheme.titleLarge),
          TextFormField(controller: res, decoration: const InputDecoration(labelText: 'Nomor Resi *'), validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null),
          TextFormField(controller: recv, decoration: const InputDecoration(labelText: 'Nama Penerima *'), validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null),
          TextFormField(controller: city, decoration: const InputDecoration(labelText: 'Kota Tujuan *'), validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null),
          TextFormField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah *'), validator: (v) { final n = int.tryParse((v ?? '').replaceAll('.', '')); return n == null || n <= 0 ? 'Jumlah tidak valid' : null; }),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan')),
          ListTile(title: Text(Formatter.tanggalPanjang(date)), trailing: const Icon(Icons.calendar_today), onTap: () async { final selected = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date); if (selected != null) setSheetState(() => date = selected); }),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: saving ? null : () async { if (!formKey.currentState!.validate()) return; setSheetState(() => saving = true); try { await ctx.read<PiutangProvider>().tambahTransaksi(TransaksiKredit(pelangganId: widget.pelanggan.id!, tanggal: date, nomorResi: res.text.trim(), namaPenerima: recv.text.trim(), kotaTujuan: city.text.trim(), jumlah: int.parse(amount.text.replaceAll('.', '')), catatan: note.text.trim().isEmpty ? null : note.text.trim())); if (ctx.mounted) Navigator.pop(ctx); if (mounted) await _load(); } catch (e) { if (ctx.mounted) { setSheetState(() => saving = false); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'))); } } }, child: saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'))),
        ]))),
      )),
    );
    res.dispose(); recv.dispose(); city.dispose(); amount.dispose(); note.dispose();
  }

  Future<void> _bayar(TransaksiKredit transaksi) async {
    final amount = TextEditingController(), note = TextEditingController(); bool saving = false;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Text('Pembayaran ${transaksi.nomorResi}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Sisa: ${Formatter.rupiah(transaksi.sisa)}'), TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah')), TextField(controller: note, decoration: const InputDecoration(labelText: 'Keterangan'))]),
      actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Batal')), ElevatedButton(onPressed: saving ? null : () async { final value = int.tryParse(amount.text.replaceAll('.', '')); if (value == null || value <= 0 || value > transaksi.sisa) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Jumlah pembayaran tidak valid'))); return; } setDialogState(() => saving = true); try { await ctx.read<PiutangProvider>().tambahPembayaran(Pembayaran(transaksiId: transaksi.id!, tanggal: DateTime.now(), jumlah: value, keterangan: note.text.trim().isEmpty ? null : note.text.trim())); if (ctx.mounted) Navigator.pop(ctx); if (mounted) await _load(); } catch (e) { if (ctx.mounted) { setDialogState(() => saving = false); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'))); } } }, child: saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Bayar'))],
    )));
    amount.dispose(); note.dispose();
  }

  Future<void> _hapusTransaksi(TransaksiKredit transaksi) async {
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Hapus transaksi?'), content: const Text('Riwayat pembayaran juga akan terhapus.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus'))]));
    if (ok != true || !mounted) return;
    try { await context.read<PiutangProvider>().hapusTransaksi(transaksi.id!); if (mounted) await _load(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pelanggan.nama), actions: [IconButton(onPressed: loading ? null : _laporanPelanggan, tooltip: 'Laporan pelanggan', icon: const Icon(Icons.description))]),
      floatingActionButton: FloatingActionButton(onPressed: _transaksi, child: const Icon(Icons.add)),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView.builder(physics: const AlwaysScrollableScrollPhysics(), itemCount: rows.length, itemBuilder: (context, index) { final transaksi = rows[index]; return Card(child: ListTile(title: Text(transaksi.nomorResi), subtitle: Text('${transaksi.namaPenerima} • ${transaksi.kotaTujuan}\n${Formatter.tanggalPendek(transaksi.tanggal)}'), isThreeLine: true, trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(Formatter.rupiah(transaksi.sisa), style: const TextStyle(fontWeight: FontWeight.bold)), if (!transaksi.lunas) TextButton(onPressed: () => _bayar(transaksi), child: const Text('Bayar'))]), onLongPress: () => showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(child: ListTile(leading: const Icon(Icons.delete), title: const Text('Hapus transaksi'), onTap: () { Navigator.pop(sheetContext); _hapusTransaksi(transaksi); })))); }))
    );
  }
}
