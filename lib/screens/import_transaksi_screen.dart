import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/import_transaksi_row.dart';
import '../services/import_transaksi_service.dart';
import '../providers/piutang_provider.dart';
import '../utils/formatter.dart';

class ImportTransaksiScreen extends StatefulWidget {
  const ImportTransaksiScreen({super.key});
  @override State<ImportTransaksiScreen> createState() => _ImportTransaksiScreenState();
}

class _ImportTransaksiScreenState extends State<ImportTransaksiScreen> {
  ImportPreview? _preview;
  bool _busy = false;

  Future<void> _template() async {
    try {
      await ImportTransaksiService.saveTemplate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template Excel siap digunakan.')));
    } catch (e) { _error(e); }
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final preview = await ImportTransaksiService.pickAndPreview();
      if (!mounted) return;
      setState(() => _preview = preview);
      if (preview != null && preview.errors.isNotEmpty) _errorText(preview.errors.join('\n'));
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null || !preview.canImport || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi import'),
        content: Text('Import ' + preview.rows.length.toString() + ' transaksi? Pelanggan yang belum ada akan dibuat otomatis. Nomor resi yang sudah ada akan ditolak dan seluruh proses dibatalkan jika ada satu baris gagal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ImportTransaksiService.importRows(preview.rows);
      if (!mounted) return;
      await context.read<PiutangProvider>().muatPelanggan();
      setState(() => _preview = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.imported.toString() + ' transaksi berhasil diimport.')));
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _error(Object e) => _errorText(e.toString().replaceFirst('Exception: ', ''));
  void _errorText(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Import Transaksi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Import massal Excel / CSV', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('Gunakan template agar nama kolom dan format data sesuai. Data divalidasi sebelum masuk database.'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _template, icon: const Icon(Icons.download_outlined), label: const Text('Template'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.upload_file_outlined), label: const Text('Pilih File'))),
            ]),
          ]))),
          if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (preview != null && !_busy) ...[
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.description_outlined), const SizedBox(width: 8),
                Expanded(child: Text(preview.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 12),
              if (preview.errors.isNotEmpty)
                Text(preview.errors.join('\n'), style: TextStyle(color: Theme.of(context).colorScheme.error))
              else ...[
                Text(preview.rows.length.toString() + ' transaksi siap diimport.', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                SizedBox(height: 310, child: ListView.separated(
                  itemCount: preview.rows.length > 50 ? 50 : preview.rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) => _rowTile(preview.rows[index], index + 1),
                )),
                if (preview.rows.length > 50) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Preview menampilkan 50 baris pertama. Semua baris tetap akan diimport.')),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _import, icon: const Icon(Icons.check_circle_outline), label: const Text('Konfirmasi & Import'))),
              ],
            ]))),
          ],
          const SizedBox(height: 18),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kolom yang tersedia', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('nama_pelanggan, no_hp, alamat, tanggal, nomor_resi, nama_penerima, kota_tujuan, quantity, berat, jumlah, catatan'),
            SizedBox(height: 8),
            Text('Tanggal: YYYY-MM-DD atau DD/MM/YYYY. Jumlah dalam Rupiah, berat dalam kg.'),
          ]))),
        ],
      ),
    );
  }

  Widget _rowTile(ImportTransaksiRow row, int number) => ListTile(
    dense: true, contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(radius: 15, child: Text(number.toString(), style: const TextStyle(fontSize: 11))),
    title: Text(row.nomorResi + ' • ' + row.namaPelanggan, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(row.namaPenerima + ' • ' + row.kotaTujuan + ' • Qty ' + row.quantity.toString() + ' • ' + row.berat.toString() + ' kg'),
    trailing: Text(Formatter.rupiah(row.jumlah), style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
