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
import '../widgets/payment_dialog.dart';

class DetailPelangganScreen extends StatefulWidget {
  final Pelanggan pelanggan;

  const DetailPelangganScreen({super.key, required this.pelanggan});

  @override
  State<DetailPelangganScreen> createState() => _DetailPelangganScreenState();
}

class _DetailPelangganScreenState extends State<DetailPelangganScreen> {
  List<TransaksiKredit> rows = <TransaksiKredit>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<PiutangProvider>().muatTransaksi(widget.pelanggan.id!);
      if (!mounted) return;
      setState(() {
        rows = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showError('Gagal memuat transaksi: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<int, List<Pembayaran>>> _loadPembayaran() async {
    final result = <int, List<Pembayaran>>{};
    for (final transaksi in rows) {
      result[transaksi.id!] = await DbHelper.instance.getPembayaranByTransaksi(transaksi.id!);
    }
    return result;
  }

  Future<void> _laporanPelanggan() async {
    try {
      final pembayaran = await _loadPembayaran();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Laporan PDF'),
                subtitle: const Text('Daftar transaksi pelanggan'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await CustomerReportService.sharePdf(
                    namaPelanggan: widget.pelanggan.nama,
                    transaksi: rows,
                    pembayaran: pembayaran,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Laporan Excel'),
                subtitle: const Text('Daftar transaksi pelanggan'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await CustomerReportService.shareExcel(
                    namaPelanggan: widget.pelanggan.nama,
                    transaksi: rows,
                    pembayaran: pembayaran,
                  );
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showError('Gagal membuat laporan: $e');
    }
  }

  Future<String?> _pilihKota(String current) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CityPicker(initialValue: current),
    );
  }

  Future<String?> _scanResi() {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
  }

  Future<void> _transaksi() async {
    final formKey = GlobalKey<FormState>();
    final res = TextEditingController();
    final penerima = TextEditingController();
    final kota = TextEditingController();
    final jumlah = TextEditingController();
    final catatan = TextEditingController();
    DateTime tanggal = DateTime.now();
    bool saving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tambah Transaksi Kredit', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: res,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Nomor Resi *',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Scan barcode',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () async {
                            final scanned = await _scanResi();
                            if (!ctx.mounted) return;
                            if (scanned != null && scanned.trim().isNotEmpty) {
                              setSheetState(() {
                                res.text = scanned.trim();
                                res.selection = TextSelection.collapsed(offset: res.text.length);
                              });
                            }
                          },
                        ),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Nomor resi wajib diisi' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: penerima,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nama Penerima *', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Nama penerima wajib diisi' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: kota,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Kota Tujuan *',
                        hintText: 'Pilih kabupaten/kota',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      onTap: () async {
                        final selected = await _pilihKota(kota.text);
                        if (!ctx.mounted) return;
                        if (selected != null) setSheetState(() => kota.text = selected);
                      },
                      validator: (value) => value == null || value.trim().isEmpty ? 'Kota tujuan wajib dipilih' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: jumlah,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: const [RupiahInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Jumlah *',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final number = int.tryParse((value ?? '').replaceAll('.', '').trim());
                        if (number == null || number <= 0) return 'Jumlah tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: catatan,
                      decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(Formatter.tanggalPanjang(tanggal)),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDate: tanggal,
                        );
                        if (!ctx.mounted) return;
                        if (selected != null) setSheetState(() => tanggal = selected);
                      },
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => saving = true);
                              try {
                                await ctx.read<PiutangProvider>().tambahTransaksi(
                                  TransaksiKredit(
                                    pelangganId: widget.pelanggan.id!,
                                    tanggal: tanggal,
                                    nomorResi: res.text.trim(),
                                    namaPenerima: penerima.text.trim(),
                                    kotaTujuan: kota.text.trim(),
                                    jumlah: int.parse(jumlah.text.replaceAll('.', '').trim()),
                                    catatan: catatan.text.trim().isEmpty ? null : catatan.text.trim(),
                                  ),
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (mounted) await _load();
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setSheetState(() => saving = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                              }
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Simpan Transaksi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      res.dispose();
      penerima.dispose();
      kota.dispose();
      jumlah.dispose();
      catatan.dispose();
    }
  }

  Future<void> _bayar(TransaksiKredit transaksi) async {
    await PaymentDialog.show(context, transaksi, onSaved: () async {
      if (mounted) await _load();
    });
  }

  Future<void> _bayarSemua() async {
    if (!mounted) return;
    await CustomerPaymentSheet.show(context, rows, onSaved: () async {
      if (mounted) await _load();
    });
  }

  Future<void> _hapusTransaksi(TransaksiKredit transaksi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Riwayat pembayaran juga akan terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<PiutangProvider>().hapusTransaksi(transaksi.id!);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasOutstanding = rows.any((t) => t.sisa > 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pelanggan.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (hasOutstanding)
            IconButton(
              onPressed: loading ? null : _bayarSemua,
              tooltip: 'Bayar piutang',
              icon: const Icon(Icons.payments_outlined),
            ),
          IconButton(
            onPressed: loading ? null : _laporanPelanggan,
            tooltip: 'Laporan pelanggan',
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _transaksi,
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 150),
                      Icon(Icons.receipt_long_outlined, size: 56, color: scheme.primary),
                      const SizedBox(height: 12),
                      Center(child: Text('Belum ada transaksi.', style: theme.textTheme.titleMedium)),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Tekan tombol Transaksi untuk menambahkan.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final transaksi = rows[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(transaksi.nomorResi, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${transaksi.namaPenerima} • ${transaksi.kotaTujuan}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(Formatter.tanggalPanjang(transaksi.tanggal)),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'bayar') _bayar(transaksi);
                              if (value == 'hapus') _hapusTransaksi(transaksi);
                            },
                            itemBuilder: (_) => [
                              if (transaksi.sisa > 0)
                                const PopupMenuItem(value: 'bayar', child: Text('Bayar')),
                              const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                            ],
                          ),
                          leading: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                            child: Icon(transaksi.sisa <= 0 ? Icons.check : Icons.receipt_long_outlined),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _CityPicker extends StatefulWidget {
  final String initialValue;
  const _CityPicker({required this.initialValue});

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  late final TextEditingController searchController;
  String query = '';

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.initialValue);
    searchController.addListener(() {
      if (mounted) setState(() => query = searchController.text);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final cities = indonesiaCities.where((city) => city.toLowerCase().contains(normalized)).toList(growable: false);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Cari kota/kabupaten',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: cities.length,
                  itemBuilder: (_, index) => ListTile(
                    title: Text(cities[index]),
                    onTap: () => Navigator.pop(context, cities[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool handled = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Nomor Resi')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (handled) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue?.trim();
            if (value != null && value.isNotEmpty) {
              handled = true;
              Navigator.of(context).pop(value);
              break;
            }
          }
        },
      ),
    );
  }
}
