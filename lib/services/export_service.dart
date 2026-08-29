import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../utils/formatter.dart';

class ExportService {
  static Future<void> exportRekapKePdf(
    List<Map<String, dynamic>> rows,
    DateTime dari,
    DateTime sampai,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Laporan Piutang Usaha',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Periode ${Formatter.tanggalPendek(dari)} - ${Formatter.tanggalPendek(sampai)}',
            ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.TableHelper.fromTextArray(
                headers: const [
                  'Tanggal',
                  'Pelanggan',
                  'Resi',
                  'Penerima',
                  'Kota',
                  'Kredit',
                  'Dibayar',
                  'Dibayar Periode',
                  'Sisa',
                ],
                data: rows.map((row) {
                  final kredit = (row['jumlah'] as num).toInt();
                  final dibayar = (row['total_dibayar'] as num).toInt();
                  final dibayarPeriode = (row['dibayar_periode'] as num?)?.toInt() ?? 0;
                  final rawDate = row['tanggal'];
                  final tanggal = rawDate is String
                      ? DateTime.parse(rawDate)
                      : rawDate is DateTime
                          ? rawDate
                          : DateTime.now();
                  return [
                    Formatter.tanggalPendek(tanggal),
                    '${row['nama_pelanggan'] ?? ''}',
                    '${row['nomor_resi'] ?? ''}',
                    '${row['nama_penerima'] ?? ''}',
                    '${row['kota_tujuan'] ?? ''}',
                    Formatter.rupiah(kredit),
                    Formatter.rupiah(dibayar),
                    Formatter.rupiah(dibayarPeriode),
                    Formatter.rupiah(kredit - dibayar),
                  ];
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'laporan_piutang_${DateTime.now().millisecondsSinceEpoch}.pdf'),
    );
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan Piutang Usaha');
  }

  static Future<void> exportRekapKeExcel(List<Map<String, dynamic>> rows) async {
    final excel = Excel.createExcel();
    final sheet = excel['Rekap'];

    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Pelanggan'),
      TextCellValue('Resi'),
      TextCellValue('Penerima'),
      TextCellValue('Kota'),
      TextCellValue('Kredit'),
      TextCellValue('Dibayar'),
      TextCellValue('Dibayar Periode'),
      TextCellValue('Sisa'),
    ]);

    for (final row in rows) {
      final kredit = (row['jumlah'] as num).toInt();
      final dibayar = (row['total_dibayar'] as num).toInt();
      final dibayarPeriode = (row['dibayar_periode'] as num?)?.toInt() ?? 0;
      sheet.appendRow([
        TextCellValue('${row['tanggal'] ?? ''}'),
        TextCellValue('${row['nama_pelanggan'] ?? ''}'),
        TextCellValue('${row['nomor_resi'] ?? ''}'),
        TextCellValue('${row['nama_penerima'] ?? ''}'),
        TextCellValue('${row['kota_tujuan'] ?? ''}'),
        IntCellValue(kredit),
        IntCellValue(dibayar),
        IntCellValue(dibayarPeriode),
        IntCellValue(kredit - dibayar),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat Excel.');
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'laporan_piutang_${DateTime.now().millisecondsSinceEpoch}.xlsx'),
    );
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan Piutang Usaha Excel');
  }
}
