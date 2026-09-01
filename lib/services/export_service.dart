import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../utils/formatter.dart';
import 'report_header_settings.dart';

class ExportService {
  static Future<void> exportRekapKePdf(
    List<Map<String, dynamic>> rows,
    DateTime dari,
    DateTime sampai,
  ) async {
    final settings = await ReportHeaderSettings.load();
    pw.MemoryImage? logo;
    if (settings.logoPath != null) {
      final file = File(settings.logoPath!);
      if (await file.exists()) {
        logo = pw.MemoryImage(await file.readAsBytes());
      }
    }

    var totalKredit = 0;
    var totalDibayar = 0;
    var totalDibayarPeriode = 0;
    var totalSisa = 0;

    final data = rows.map((row) {
      final kredit = (row['jumlah'] as num).toInt();
      final dibayar = (row['total_dibayar'] as num).toInt();
      final dibayarPeriode = (row['dibayar_periode'] as num?)?.toInt() ?? 0;
      final rawDate = row['tanggal'];
      final tanggal = rawDate is String
          ? DateTime.parse(rawDate)
          : rawDate is DateTime
              ? rawDate
              : DateTime.now();
      final sisa = kredit - dibayar;

      totalKredit += kredit;
      totalDibayar += dibayar;
      totalDibayarPeriode += dibayarPeriode;
      totalSisa += sisa;

      return [
        Formatter.tanggalPendek(tanggal),
        '${row['nama_pelanggan'] ?? ''}',
        '${row['nomor_resi'] ?? ''}',
        '${row['nama_penerima'] ?? ''}',
        '${row['kota_tujuan'] ?? ''}',
        Formatter.rupiah(kredit),
        Formatter.rupiah(dibayar),
        Formatter.rupiah(dibayarPeriode),
        Formatter.rupiah(sisa),
      ];
    }).toList();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dicetak ${Formatter.tanggalPendek(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.Text(
              'Halaman ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.2)),
            ),
            child: pw.Row(
              children: [
                if (logo != null)
                  pw.Container(
                    width: 58,
                    height: 58,
                    padding: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settings.companyName,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        settings.reportTitle,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'REKAP PERIODE ${Formatter.tanggalPendek(dari)} - ${Formatter.tanggalPendek(sampai)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
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
            data: data,
            cellAlignments: const {
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                _totalCell(totalKredit),
                _totalCell(totalDibayar),
                _totalCell(totalDibayarPeriode, width: 88),
                _totalCell(totalSisa),
              ],
            ),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'laporan_piutang_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Laporan Piutang Usaha'),
    );
  }

  static pw.Widget _totalCell(int value, {double width = 78}) => pw.SizedBox(
        width: width,
        child: pw.Text(
          Formatter.rupiah(value),
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      );

  static Future<void> exportRekapKeExcel(
    List<Map<String, dynamic>> rows,
  ) async {
    final settings = await ReportHeaderSettings.load();
    final excel = Excel.createExcel();
    final sheet = excel['Rekap'];
    final numberStyle = CellStyle(
      numberFormat: CustomNumericNumFormat('#,##0'),
      horizontalAlign: HorizontalAlign.Right,
    );

    sheet.appendRow([TextCellValue(settings.companyName)]);
    sheet.appendRow([TextCellValue(settings.reportTitle)]);
    sheet.appendRow([
      TextCellValue('Periode'),
      TextCellValue(
        Formatter.tanggalPendek(
          rows.isEmpty ? DateTime.now() : _parseDate(rows.first['tanggal']),
        ),
      ),
      TextCellValue('-'),
      TextCellValue(
        Formatter.tanggalPendek(
          rows.isEmpty ? DateTime.now() : _parseDate(rows.last['tanggal']),
        ),
      ),
    ]);
    sheet.appendRow([]);
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

    var totalKredit = 0;
    var totalDibayar = 0;
    var totalDibayarPeriode = 0;
    var totalSisa = 0;
    var excelRow = 5;

    for (final row in rows) {
      final kredit = (row['jumlah'] as num).toInt();
      final dibayar = (row['total_dibayar'] as num).toInt();
      final dibayarPeriode = (row['dibayar_periode'] as num?)?.toInt() ?? 0;
      final sisa = kredit - dibayar;
      totalKredit += kredit;
      totalDibayar += dibayar;
      totalDibayarPeriode += dibayarPeriode;
      totalSisa += sisa;

      sheet.appendRow([
        TextCellValue('${row['tanggal'] ?? ''}'),
        TextCellValue('${row['nama_pelanggan'] ?? ''}'),
        TextCellValue('${row['nomor_resi'] ?? ''}'),
        TextCellValue('${row['nama_penerima'] ?? ''}'),
        TextCellValue('${row['kota_tujuan'] ?? ''}'),
        IntCellValue(kredit),
        IntCellValue(dibayar),
        IntCellValue(dibayarPeriode),
        IntCellValue(sisa),
      ]);

      for (var column = 5; column <= 8; column++) {
        sheet
            .cell(CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: excelRow,
            ))
            .cellStyle = numberStyle;
      }
      excelRow++;
    }

    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('TOTAL'),
      IntCellValue(totalKredit),
      IntCellValue(totalDibayar),
      IntCellValue(totalDibayarPeriode),
      IntCellValue(totalSisa),
    ]);
    for (var column = 5; column <= 8; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: excelRow,
          ))
          .cellStyle = numberStyle;
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat Excel.');
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'laporan_piutang_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      ),
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Laporan Piutang Usaha Excel'),
    );
  }

  static DateTime _parseDate(dynamic rawDate) {
    if (rawDate is DateTime) return rawDate;
    if (rawDate is String) return DateTime.parse(rawDate);
    return DateTime.now();
  }
}
