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
      final result = await context
          .read<PiutangProvider>()
          .muatTransaksi(widget.pelanggan.id!);
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
      result[transaksi.id!] =
          await DbHelper.instance.getPembayaranByTransaksi(transaksi.id!);
    }
    return result;
  }

  Future<void> _laporanPelanggan() async {
    try {
      final pembayaran = await _loadPembayaran();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          return SafeArea(
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
          );
        },
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
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tambah Transaksi Kredit',
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
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
                                    res.selection = TextSelection.collapsed(
                                      offset: res.text.length,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nomor resi wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: penerima,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nama Penerima *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama penerima wajib diisi';
                            }
                            return null;
                          },
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
                            if (selected != null) {
                              setSheetState(() => kota.text = selected);
                            }
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Kota tujuan wajib dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: jumlah,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final number = int.tryParse(
                              (value ?? '').replaceAll('.', '').trim(),
                            );
                            if (number == null || number <= 0) {
                              return 'Jumlah tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: catatan,
                          decoration: const InputDecoration(
                            labelText: 'Catatan',
                            border: OutlineInputBorder(),
                          ),
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
                            if (selected != null) {
                              setSheetState(() => tanggal = selected);
                            }
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
                                    await ctx
                                        .read<PiutangProvider>()
                                        .tambahTransaksi(
                                          TransaksiKredit(
                                            pelangganId: widget.pelanggan.id!,
                                            tanggal: tanggal,
                                            nomorResi: res.text.trim(),
                                            namaPenerima: penerima.text.trim(),
                                            kotaTujuan: kota.text.trim(),
                                            jumlah: int.parse(
                                              jumlah.text.replaceAll('.', '').trim(),
                                            ),
                                            catatan: catatan.text.trim().isEmpty
                                                ? null
                                                : catatan.text.trim(),
                                          ),
                                        );
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    if (mounted) await _load();
                                  } catch (e) {
                                    if (!ctx.mounted) return;
                                    setSheetState(() => saving = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.save_outlined),
                          label: saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Simpan Transaksi'),
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
    } finally {
      res.dispose();
      penerima.dispose();
      kota.dispose();
      jumlah.dispose();
      catatan.dispose();
    }
  }

  Future<void> _bayar(TransaksiKredit transaksi) async {
    final jumlah = TextEditingController();
    final keterangan = TextEditingController();
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text('Pembayaran ${transaksi.nomorResi}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Sisa: ${Formatter.rupiah(transaksi.sisa)}'),
                    ),
                    TextField(
                      controller: jumlah,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Jumlah'),
                    ),
                    TextField(
                      controller: keterangan,
                      decoration: const InputDecoration(labelText: 'Keterangan'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final value = int.tryParse(
                              jumlah.text.replaceAll('.', '').trim(),
                            );
                            if (value == null ||
                                value <= 0 ||
                                value > transaksi.sisa) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Jumlah pembayaran tidak valid'),
                                ),
                              );
                              return;
                            }
                            setDialogState(() => saving = true);
                            try {
                              await ctx
                                  .read<PiutangProvider>()
                                  .tambahPembayaran(
                                    Pembayaran(
                                      transaksiId: transaksi.id!,
                                      tanggal: DateTime.now(),
                                      jumlah: value,
                                      keterangan:
                                          keterangan.text.trim().isEmpty
                                              ? null
                                              : keterangan.text.trim(),
                                    ),
                                  );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (mounted) await _load();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setDialogState(() => saving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Bayar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      jumlah.dispose();
      keterangan.dispose();
    }
  }

  Future<void> _hapusTransaksi(TransaksiKredit transaksi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus transaksi?'),
          content: const Text('Riwayat pembayaran juga akan terhapus.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pelanggan.nama,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 56,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Belum ada transaksi.',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            transaksi.nomorResi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${transaksi.namaPenerima} • ${transaksi.kotaTujuan}\n${Formatter.tanggalPendek(transaksi.tanggal)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Formatter.rupiah(transaksi.sisa),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: transaksi.lunas
                                      ? scheme.primary
                                      : scheme.error,
                                ),
                              ),
                              if (!transaksi.lunas)
                                TextButton(
                                  onPressed: () => _bayar(transaksi),
                                  child: const Text('Bayar'),
                                ),
                            ],
                          ),
                          onLongPress: () {
                            showModalBottomSheet<void>(
                              context: context,
                              builder: (sheetContext) {
                                return SafeArea(
                                  child: ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: const Text('Hapus transaksi'),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      _hapusTransaksi(transaksi);
                                    },
                                  ),
                                );
                              },
                            );
                          },
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
  late final TextEditingController search;

  @override
  void initState() {
    super.initState();
    search = TextEditingController();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final results = query.isEmpty
        ? indonesiaCities
        : indonesiaCities
            .where((city) => city.toLowerCase().contains(query))
            .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pilih Kota/Kabupaten',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cari nama kota atau kabupaten...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final city = results[index];
                  return ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text(city),
                    selected: city == widget.initialValue,
                    onTap: () => Navigator.pop(context, city),
                  );
                },
              ),
            ),
          ],
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
  bool found = false;

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
          if (found) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue?.trim();
            if (value != null && value.isNotEmpty) {
              found = true;
              controller.stop();
              Navigator.pop(context, value);
              break;
            }
          }
        },
      ),
    );
  }
}
