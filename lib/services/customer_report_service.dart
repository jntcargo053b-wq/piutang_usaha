import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/pembayaran.dart';
import '../models/transaksi_kredit.dart';
import '../utils/formatter.dart';

class CustomerReportService {
  static Future<void> sharePdf({
    required String namaPelanggan,
    required List<TransaksiKredit> transaksi,
    required Map<int, List<Pembayaran>> pembayaran,
  }) async {
    final doc = pw.Document();
    final totalKredit = transaksi.fold<int>(0, (s, t) => s + t.jumlah);
    final totalDibayar = transaksi.fold<int>(0, (s, t) => s + t.totalDibayar);
    final totalSisa = transaksi.fold<int>(0, (s, t) => s + t.sisa);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text('Laporan Kredit Pelanggan', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Pelanggan: $namaPelanggan'),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: const ['Total Kredit', 'Total Dibayar', 'Sisa Piutang'],
          data: [[Formatter.rupiah(totalKredit), Formatter.rupiah(totalDibayar), Formatter.rupiah(totalSisa)]],
        ),
        pw.SizedBox(height: 18),
        pw.Text('Daftar Transaksi', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const ['Tanggal', 'Resi', 'Penerima', 'Kota', 'Kredit', 'Dibayar', 'Sisa'],
          data: transaksi.map((t) => [
            Formatter.tanggalPendek(t.tanggal), t.nomorResi, t.namaPenerima, t.kotaTujuan,
            Formatter.rupiah(t.jumlah), Formatter.rupiah(t.totalDibayar), Formatter.rupiah(t.sisa),
          ]).toList(),
        ),
        pw.SizedBox(height: 18),
        pw.Text('Riwayat Pembayaran', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const ['Tanggal', 'Resi', 'Jumlah', 'Keterangan'],
          data: transaksi.expand((t) => (pembayaran[t.id] ?? []).map((b) => [
            Formatter.tanggalPendek(b.tanggal), t.nomorResi, Formatter.rupiah(b.jumlah), b.keterangan ?? '',
          ])).toList(),
        ),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final safeName = namaPelanggan.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final file = File(p.join(dir.path, 'laporan_kredit_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Laporan kredit pelanggan $namaPelanggan'));
  }

  static Future<void> shareExcel({
    required String namaPelanggan,
    required List<TransaksiKredit> transaksi,
    required Map<int, List<Pembayaran>> pembayaran,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Kredit'];
    sheet.appendRow([
      TextCellValue('Tanggal'), TextCellValue('Resi'), TextCellValue('Penerima'), TextCellValue('Kota'),
      TextCellValue('Kredit'), TextCellValue('Dibayar'), TextCellValue('Sisa'),
    ]);
    for (final t in transaksi) {
      sheet.appendRow([
        TextCellValue(Formatter.tanggalPendek(t.tanggal)), TextCellValue(t.nomorResi), TextCellValue(t.namaPenerima),
        TextCellValue(t.kotaTujuan), IntCellValue(t.jumlah), IntCellValue(t.totalDibayar), IntCellValue(t.sisa),
      ]);
    }
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Riwayat Pembayaran')]);
    sheet.appendRow([TextCellValue('Tanggal'), TextCellValue('Resi'), TextCellValue('Jumlah'), TextCellValue('Keterangan')]);
    for (final t in transaksi) {
      for (final b in pembayaran[t.id] ?? const <Pembayaran>[]) {
        sheet.appendRow([TextCellValue(Formatter.tanggalPendek(b.tanggal)), TextCellValue(t.nomorResi), IntCellValue(b.jumlah), TextCellValue(b.keterangan ?? '')]);
      }
    }
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat Excel.');
    final dir = await getTemporaryDirectory();
    final safeName = namaPelanggan.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final file = File(p.join(dir.path, 'laporan_kredit_${safeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx'));
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Laporan kredit pelanggan $namaPelanggan'));
  }
}
