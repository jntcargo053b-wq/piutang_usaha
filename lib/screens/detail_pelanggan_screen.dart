import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../data/indonesia_cities.dart';
import '../models/pelanggan.dart';
import '../models/pembayaran.dart';
import '../models/transaksi_kredit.dart';
import '../providers/piutang_provider.dart';
import '../services/customer_report_service.dart';
import '../services/db_helper.dart';
import '../utils/formatter.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/customer_payment_sheet.dart';
import '../widgets/customer_payment_history_sheet.dart';
import '../widgets/payment_dialog.dart';

enum _TransactionStatusFilter { all, unpaid, partial, paid }

class DetailPelangganScreen extends StatefulWidget {
  final Pelanggan pelanggan;
  const DetailPelangganScreen({super.key, required this.pelanggan});
  @override State<DetailPelangganScreen> createState() => _DetailPelangganScreenState();
}

class _DetailPelangganScreenState extends State<DetailPelangganScreen> {
  List<TransaksiKredit> rows = <TransaksiKredit>[];
  bool loading = true;
  _TransactionStatusFilter _statusFilter = _TransactionStatusFilter.all;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
    _load();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    final value = _searchController.text;
    if (value.trim().isEmpty) {
      if (mounted && _searchQuery.isNotEmpty) setState(() => _searchQuery = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _searchQuery == value) return;
      setState(() => _searchQuery = value);
    });
  }

  @override void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<PiutangProvider>().muatTransaksi(widget.pelanggan.id!);
      if (!mounted) return;
      setState(() { rows = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showError('Gagal memuat transaksi: $e');
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _riwayatPembayaran() async {
    await CustomerPaymentHistorySheet.show(context, pelangganId: widget.pelanggan.id!, namaPelanggan: widget.pelanggan.nama);
  }

  Future<Map<int, List<Pembayaran>>> _loadPembayaran() async {
    final ids = rows.map((transaksi) => transaksi.id!).toList(growable: false);
    return DbHelper.instance.getPembayaranByTransaksiIds(ids);
  }

  Future<void> _laporanPelanggan() async {
    try {
      final pembayaran = await _loadPembayaran();
      if (!mounted) return;
      final type = await showModalBottomSheet<CustomerReportType>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Jenis Laporan', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Pilih isi laporan pelanggan yang ingin dibuat.')),
        ListTile(leading: const Icon(Icons.receipt_long_outlined), title: const Text('Ringkas — Total Transaksi'), subtitle: const Text('Riwayat transaksi dan nilai transaksi asli.'), onTap: () => Navigator.pop(sheetContext, CustomerReportType.summary)),
        ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: const Text('Lengkap — Transaksi & Piutang'), subtitle: const Text('Total transaksi, pembayaran, dan sisa tagihan.'), onTap: () => Navigator.pop(sheetContext, CustomerReportType.detailed)),
        const SizedBox(height: 8),
      ])));
      if (!mounted || type == null) return;
      final format = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(type == CustomerReportType.summary ? 'Ringkas — Pilih Format' : 'Lengkap — Pilih Format', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Pilih format laporan yang akan dibagikan.')),
        ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('PDF'), subtitle: const Text('Laporan siap cetak dan dibagikan.'), onTap: () => Navigator.pop(sheetContext, 'pdf')),
        ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('Excel'), subtitle: const Text('Laporan dalam bentuk spreadsheet.'), onTap: () => Navigator.pop(sheetContext, 'excel')),
        const SizedBox(height: 8),
      ])));
      if (!mounted || format == null) return;
      if (format == 'pdf') {
        await CustomerReportService.sharePdf(namaPelanggan: widget.pelanggan.nama, transaksi: rows, pembayaran: pembayaran, type: type);
      } else {
        await CustomerReportService.shareExcel(namaPelanggan: widget.pelanggan.nama, transaksi: rows, pembayaran: pembayaran, type: type);
      }
    } catch (e) {
      if (mounted) _showError('Gagal membuat laporan: $e');
    }
  }

  Future<String?> _pilihKota(String current) => showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (_) => _CityPicker(initialValue: current));
  Future<String?> _scanResi() => Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()));

  Future<void> _transaksi({TransaksiKredit? existing}) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final res = TextEditingController(text: existing?.nomorResi ?? '');
    final penerima = TextEditingController(text: existing?.namaPenerima ?? '');
    final kota = TextEditingController(text: existing?.kotaTujuan ?? '');
    final jumlah = TextEditingController(text: existing == null ? '' : existing.jumlah.toString());
    final berat = TextEditingController(text: existing == null ? '' : _formatBerat(existing.berat));
    final quantity = TextEditingController(text: existing?.quantity.toString() ?? '1');
    final catatan = TextEditingController(text: existing?.catatan ?? '');
    DateTime tanggal = existing?.tanggal ?? DateTime.now();
    bool saving = false;
    try {
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(child: Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(isEdit ? 'Edit Transaksi Kredit' : 'Tambah Transaksi Kredit', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            IconButton(tooltip: 'Tutup', onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
          ]),
          Text(isEdit ? 'Perbarui data transaksi tanpa mengubah riwayat pembayaran.' : 'Isi data pengiriman dan tagihan. Field bertanda * wajib diisi.', style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 16),
          const _FormSectionTitle(icon: Icons.local_shipping_outlined, title: 'Informasi Pengiriman'),
          const SizedBox(height: 10),
          TextFormField(controller: res, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: 'Nomor Resi *', border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: 'Scan barcode', icon: const Icon(Icons.qr_code_scanner), onPressed: () async {
            final scanned = await _scanResi();
            if (!ctx.mounted) return;
            if (scanned != null && scanned.trim().isNotEmpty) setSheetState(() { res.text = scanned.trim(); res.selection = TextSelection.collapsed(offset: res.text.length); });
          })), validator: (value) => value == null || value.trim().isEmpty ? 'Nomor resi wajib diisi' : null),
          const SizedBox(height: 10),
          TextFormField(controller: penerima, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Nama Penerima *', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Nama penerima wajib diisi' : null),
          const SizedBox(height: 16),
          const _FormSectionTitle(icon: Icons.place_outlined, title: 'Tujuan & Paket'),
          const SizedBox(height: 10),
          TextFormField(controller: kota, readOnly: true, decoration: const InputDecoration(labelText: 'Kota Tujuan *', hintText: 'Pilih kabupaten/kota', border: OutlineInputBorder(), suffixIcon: Icon(Icons.arrow_drop_down)), onTap: () async {
            final selected = await _pilihKota(kota.text);
            if (!ctx.mounted) return;
            if (selected != null) setSheetState(() => kota.text = selected);
          }, validator: (value) => value == null || value.trim().isEmpty ? 'Kota tujuan wajib dipilih' : null),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(controller: quantity, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Quantity *', hintText: '1', border: OutlineInputBorder()), validator: (value) { final n = int.tryParse((value ?? '').trim()); return n == null || n <= 0 ? 'Quantity tidak valid' : null; })),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(controller: berat, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Berat (kg) *', hintText: '0,5', suffixText: 'kg', border: OutlineInputBorder()), validator: (value) { final n = double.tryParse((value ?? '').trim().replaceAll(',', '.')); return n == null || n <= 0 ? 'Berat tidak valid' : null; })),
          ]),
          const SizedBox(height: 16),
          const _FormSectionTitle(icon: Icons.payments_outlined, title: 'Nilai Transaksi'),
          const SizedBox(height: 10),
          TextFormField(controller: jumlah, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, inputFormatters: const [RupiahInputFormatter()], decoration: const InputDecoration(labelText: 'Jumlah *', prefixText: 'Rp ', border: OutlineInputBorder()), validator: (value) {
            final n = int.tryParse((value ?? '').replaceAll('.', '').trim());
            if (n == null || n <= 0) return 'Jumlah tidak valid';
            // Final paid-total validation is performed atomically by DbHelper using current DB data.
            return null;
          }),
          const SizedBox(height: 16),
          const _FormSectionTitle(icon: Icons.notes_outlined, title: 'Catatan & Tanggal'),
          const SizedBox(height: 10),
          TextFormField(controller: catatan, decoration: const InputDecoration(labelText: 'Catatan', hintText: 'Opsional', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 4),
          Card(margin: EdgeInsets.zero, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.calendar_today_outlined), title: const Text('Tanggal transaksi', style: TextStyle(fontSize: 12)), subtitle: Text(Formatter.tanggalPanjang(tanggal), style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right), onTap: () async {
            final selected = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: tanggal);
            if (!ctx.mounted) return;
            if (selected != null) setSheetState(() => tanggal = selected);
          })),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: saving ? null : () async {
            if (!formKey.currentState!.validate()) return;
            setSheetState(() => saving = true);
            try {
              final transaksi = TransaksiKredit(id: existing?.id, pelangganId: widget.pelanggan.id!, tanggal: tanggal, nomorResi: res.text.trim(), namaPenerima: penerima.text.trim(), kotaTujuan: kota.text.trim(), jumlah: int.parse(jumlah.text.replaceAll('.', '').trim()), berat: double.parse(berat.text.trim().replaceAll(',', '.')), quantity: int.parse(quantity.text.trim()), catatan: catatan.text.trim().isEmpty ? null : catatan.text.trim(), totalDibayar: existing?.totalDibayar ?? 0);
              if (isEdit) {
                await DbHelper.instance.updateTransaksi(transaksi);
                if (!ctx.mounted) return;
                await ctx.read<PiutangProvider>().muatPelanggan();
              } else {
                await ctx.read<PiutangProvider>().tambahTransaksi(transaksi);
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) await _load();
            } catch (e) {
              if (!ctx.mounted) return;
              setSheetState(() => saving = false);
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
            }
          }, icon: const Icon(Icons.save_outlined), label: saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isEdit ? 'Simpan Perubahan' : 'Simpan Transaksi')),
        ]))),
      )));
    } finally {
      res.dispose(); penerima.dispose(); kota.dispose(); jumlah.dispose(); berat.dispose(); quantity.dispose(); catatan.dispose();
    }
  }

  Future<void> _bayar(TransaksiKredit transaksi) async { await PaymentDialog.show(context, transaksi, onSaved: () async { if (mounted) await _load(); }); }
  Future<void> _bayarSemua() async { if (!mounted) return; await CustomerPaymentSheet.show(context, rows, namaPelanggan: widget.pelanggan.nama, onSaved: () async { if (mounted) await _load(); }); }

  Future<void> _hapusTransaksi(TransaksiKredit transaksi) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Hapus transaksi?'), content: const Text('Riwayat pembayaran juga akan terhapus.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus'))]));
    if (confirmed != true || !mounted) return;
    try { await context.read<PiutangProvider>().hapusTransaksi(transaksi.id!); if (mounted) await _load(); } catch (e) { if (mounted) _showError('$e'); }
  }

  String _statusLabel(TransaksiKredit transaksi) {
    if (transaksi.sisa <= 0) return 'Lunas';
    if (transaksi.totalDibayar > 0) return 'Sebagian';
    return 'Belum Lunas';
  }

  Color _statusContainerColor(ColorScheme scheme, TransaksiKredit transaksi) {
    if (transaksi.sisa <= 0) return scheme.secondaryContainer;
    if (transaksi.totalDibayar > 0) return scheme.primaryContainer;
    return scheme.errorContainer;
  }

  Color _statusTextColor(ColorScheme scheme, TransaksiKredit transaksi) {
    if (transaksi.sisa <= 0) return scheme.onSecondaryContainer;
    if (transaksi.totalDibayar > 0) return scheme.onPrimaryContainer;
    return scheme.onErrorContainer;
  }

  bool _matchesFilter(TransaksiKredit transaksi) {
    switch (_statusFilter) {
      case _TransactionStatusFilter.all: return true;
      case _TransactionStatusFilter.unpaid: return transaksi.totalDibayar <= 0 && transaksi.sisa > 0;
      case _TransactionStatusFilter.partial: return transaksi.totalDibayar > 0 && transaksi.sisa > 0;
      case _TransactionStatusFilter.paid: return transaksi.sisa <= 0;
    }
  }

  List<TransaksiKredit> get _filteredRows {
    final query = _searchQuery.trim().toLowerCase();
    return rows.where((transaksi) {
      if (!_matchesFilter(transaksi)) return false;
      if (query.isEmpty) return true;
      return transaksi.nomorResi.toLowerCase().contains(query) || transaksi.namaPenerima.toLowerCase().contains(query) || transaksi.kotaTujuan.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  String _filterLabel(_TransactionStatusFilter filter) {
    switch (filter) {
      case _TransactionStatusFilter.all: return 'Semua';
      case _TransactionStatusFilter.unpaid: return 'Belum Lunas';
      case _TransactionStatusFilter.partial: return 'Sebagian';
      case _TransactionStatusFilter.paid: return 'Lunas';
    }
  }

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme, hasOutstanding = rows.any((t) => t.sisa > 0), filteredRows = _filteredRows;
    return Scaffold(
      appBar: AppBar(title: Text(widget.pelanggan.nama, maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(onPressed: loading ? null : _riwayatPembayaran, tooltip: 'Riwayat pembayaran', icon: const Icon(Icons.history_outlined)), if (hasOutstanding) IconButton(onPressed: loading ? null : _bayarSemua, tooltip: 'Bayar piutang', icon: const Icon(Icons.payments_outlined)), IconButton(onPressed: loading ? null : _laporanPelanggan, tooltip: 'Laporan pelanggan', icon: const Icon(Icons.description_outlined))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _transaksi, icon: const Icon(Icons.add), label: const Text('Transaksi')),
      body: loading ? const Center(child: CircularProgressIndicator()) : rows.isEmpty
          ? RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 150), Icon(Icons.receipt_long_outlined, size: 56, color: scheme.primary), const SizedBox(height: 12), Center(child: Text('Belum ada transaksi.', style: theme.textTheme.titleMedium)), const SizedBox(height: 4), Center(child: Text('Tekan tombol Transaksi untuk menambahkan.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium))]))
          : RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), physics: const AlwaysScrollableScrollPhysics(), itemCount: filteredRows.length + 1, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
              if (index == 0) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(controller: _searchController, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), suffixIcon: _searchQuery.isEmpty ? null : IconButton(tooltip: 'Bersihkan', icon: const Icon(Icons.clear), onPressed: _searchController.clear), labelText: 'Cari resi, penerima, atau kota', border: const OutlineInputBorder())),
                  const SizedBox(height: 8),
                  SizedBox(height: 42, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _TransactionStatusFilter.values.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) {
                    final filter = _TransactionStatusFilter.values[i];
                    return ChoiceChip(label: Text(_filterLabel(filter)), selected: _statusFilter == filter, onSelected: (_) => setState(() => _statusFilter = filter));
                  })),
                  const SizedBox(height: 2),
                  Text('${filteredRows.length} transaksi ditampilkan', style: theme.textTheme.bodySmall),
                ]);
              }
              final transaksi = filteredRows[index - 1];
              final statusLabel = _statusLabel(transaksi);
              final statusBg = _statusContainerColor(scheme, transaksi);
              final statusFg = _statusTextColor(scheme, transaksi);
              return Card(clipBehavior: Clip.antiAlias, child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(children: [
                  Expanded(child: Text(transaksi.nomorResi, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)), child: Text(statusLabel, style: theme.textTheme.labelSmall?.copyWith(color: statusFg, fontWeight: FontWeight.w700))),
                ]),
                subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${transaksi.namaPenerima} • ${transaksi.kotaTujuan}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Qty ${transaksi.quantity} • ${_formatBerat(transaksi.berat)} kg'),
                  const SizedBox(height: 4),
                  Text(Formatter.tanggalPanjang(transaksi.tanggal)),
                  const SizedBox(height: 10),
                  Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Tagihan', style: theme.textTheme.bodySmall), Text(Formatter.rupiah(transaksi.jumlah), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Dibayar', style: theme.textTheme.bodySmall), Text(Formatter.rupiah(transaksi.totalDibayar), style: theme.textTheme.bodyMedium)]),
                    const Divider(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Sisa', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)), Text(Formatter.rupiah(transaksi.sisa < 0 ? 0 : transaksi.sisa), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800))]),
                  ])),
                ])),
                trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'bayar') _bayar(transaksi); if (value == 'edit') _transaksi(existing: transaksi); if (value == 'hapus') _hapusTransaksi(transaksi); }, itemBuilder: (_) { final items = <PopupMenuEntry<String>>[]; if (transaksi.sisa > 0) items.add(const PopupMenuItem(value: 'bayar', child: Text('Bayar'))); items.add(const PopupMenuItem(value: 'edit', child: Text('Edit'))); items.add(const PopupMenuItem(value: 'hapus', child: Text('Hapus'))); return items; }),
                leading: CircleAvatar(backgroundColor: statusBg, foregroundColor: statusFg, child: Icon(transaksi.sisa <= 0 ? Icons.check : Icons.receipt_long_outlined)),
              ));
            })),
    );
  }

  String _formatBerat(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString().replaceAll('.', ',');
}

class _FormSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _FormSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [Icon(icon, size: 19, color: scheme.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))]);
  }
}

class _CityPicker extends StatefulWidget {
  final String initialValue;
  const _CityPicker({required this.initialValue});
  @override State<_CityPicker> createState() => _CityPickerState();
}
class _CityPickerState extends State<_CityPicker> {
  late final TextEditingController searchController;
  String query = '';
  @override void initState() { super.initState(); searchController = TextEditingController(text: widget.initialValue); searchController.addListener(() { if (mounted) setState(() => query = searchController.text); }); }
  @override void dispose() { searchController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final cities = indonesiaCities.where((city) => city.toLowerCase().contains(normalized)).toList(growable: false);
    return SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .8, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      TextField(controller: searchController, autofocus: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Cari kota/kabupaten', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      Expanded(child: ListView.builder(itemCount: cities.length, itemBuilder: (_, index) => ListTile(title: Text(cities[index]), onTap: () => Navigator.pop(context, cities[index])))),
    ]))));
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();
  @override State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}
class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool handled = false;
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Scan Nomor Resi')), body: MobileScanner(controller: controller, onDetect: (capture) {
      if (handled) return;
      for (final barcode in capture.barcodes) { final value = barcode.rawValue?.trim(); if (value != null && value.isNotEmpty) { handled = true; Navigator.of(context).pop(value); break; } }
    }));
  }
}