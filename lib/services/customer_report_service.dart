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
    final totalTransaksi = transaksi.fold<int>(0, (sum, t) => sum + t.jumlah);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'Laporan Transaksi Pelanggan',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Pelanggan: $namaPelanggan'),
          pw.SizedBox(height: 4),
          pw.Text('Total Transaksi: ${transaksi.length}'),
          pw.Text('Total: ${Formatter.rupiah(totalTransaksi)}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Daftar Transaksi',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Tanggal', 'Resi', 'Penerima', 'Kota', 'Total'],
            data: transaksi
                .map(
                  (t) => [
                    Formatter.tanggalPendek(t.tanggal),
                    t.nomorResi,
                    t.namaPenerima,
                    t.kotaTujuan,
                    Formatter.rupiah(t.jumlah),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final safeName = namaPelanggan.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final file = File(
      p.join(
        dir.path,
        'laporan_transaksi_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Laporan transaksi pelanggan $namaPelanggan',
      ),
    );
  }

  static Future<void> shareExcel({
    required String namaPelanggan,
    required List<TransaksiKredit> transaksi,
    required Map<int, List<Pembayaran>> pembayaran,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Transaksi'];

    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Resi'),
      TextCellValue('Penerima'),
      TextCellValue('Kota'),
      TextCellValue('Total'),
    ]);

    for (final t in transaksi) {
      sheet.appendRow([
        TextCellValue(Formatter.tanggalPendek(t.tanggal)),
        TextCellValue(t.nomorResi),
        TextCellValue(t.namaPenerima),
        TextCellValue(t.kotaTujuan),
        IntCellValue(t.jumlah),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Pelanggan'), TextCellValue(namaPelanggan)]);
    sheet.appendRow([
      TextCellValue('Jumlah Transaksi'),
      IntCellValue(transaksi.length),
    ]);
    sheet.appendRow([
      TextCellValue('Total'),
      IntCellValue(transaksi.fold<int>(0, (sum, t) => sum + t.jumlah)),
    ]);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat Excel.');

    final dir = await getTemporaryDirectory();
    final safeName = namaPelanggan.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final file = File(
      p.join(
        dir.path,
        'laporan_transaksi_${safeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      ),
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Laporan transaksi pelanggan $namaPelanggan',
      ),
    );
  }
}
