import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../utils/formatter.dart';
import 'report_header_settings.dart';

class PaymentReportService {
  static Future<Uint8List> buildPdf({
    required List<Map<String, dynamic>> rows,
    required DateTime dari,
    required DateTime sampai,
    required String customer,
    required String method,
  }) async {
    final settings = await ReportHeaderSettings.load();
    pw.MemoryImage? logo;
    if (settings.logoPath != null) {
      final file = File(settings.logoPath!);
      if (await file.exists()) logo = pw.MemoryImage(await file.readAsBytes());
    }
    final total = rows.fold<int>(0, (sum, row) => sum + _int(row['jumlah']));
    final cash = rows.where((r) => '${r['metode'] ?? ''}' == 'cash').fold<int>(0, (s, r) => s + _int(r['jumlah']));
    final transfer = rows.where((r) => '${r['metode'] ?? ''}' == 'transfer').fold<int>(0, (s, r) => s + _int(r['jumlah']));
    final data = rows.map((row) => [
      Formatter.tanggalPendek(_date(row['tanggal'])),
      '${row['nama_pelanggan'] ?? ''}',
      Formatter.rupiah(_int(row['jumlah'])),
      _methodLabel(row['metode']),
      '${row['keterangan'] ?? ''}',
    ]).toList();

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Dicetak ${Formatter.tanggalPendek(DateTime.now())}', style: const pw.TextStyle(fontSize: 7)),
          pw.Text('Halaman ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
      build: (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.2))),
          child: pw.Row(children: [
            if (logo != null) pw.Container(width: 58, height: 58, padding: const pw.EdgeInsets.only(right: 10), child: pw.Image(logo, fit: pw.BoxFit.contain)),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(settings.companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('LAPORAN PEMBAYARAN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text('Periode ${Formatter.tanggalPendek(dari)} - ${Formatter.tanggalPendek(sampai)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Pelanggan: $customer  •  Metode: $method', style: const pw.TextStyle(fontSize: 9)),
            ])),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          _summary('TOTAL PEMBAYARAN', total),
          pw.SizedBox(width: 10),
          _summary('CASH', cash),
          pw.SizedBox(width: 10),
          _summary('TRANSFER', transfer),
        ]),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: const ['Tanggal', 'Pelanggan', 'Jumlah', 'Metode', 'Keterangan'],
          data: data,
          columnWidths: const {
            0: pw.FixedColumnWidth(65),
            1: pw.FixedColumnWidth(145),
            2: pw.FixedColumnWidth(90),
            3: pw.FixedColumnWidth(75),
            4: pw.FlexColumnWidth(),
          },
          cellAlignments: const {2: pw.Alignment.centerRight},
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
          cellPadding: const pw.EdgeInsets.all(5),
        ),
        pw.SizedBox(height: 4),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL: ${Formatter.rupiah(total)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
      ],
    ));

    return doc.save();
  }


  static Future<void> exportPdf({
    required List<Map<String, dynamic>> rows,
    required DateTime dari,
    required DateTime sampai,
    required String customer,
    required String method,
  }) async {
    final bytes = await buildPdf(
      rows: rows,
      dari: dari,
      sampai: sampai,
      customer: customer,
      method: method,
    );
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'laporan_pembayaran_${DateTime.now().millisecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Laporan Pembayaran'),
    );
  }

  static Future<void> exportExcel({
    required List<Map<String, dynamic>> rows,
    required DateTime dari,
    required DateTime sampai,
    required String customer,
    required String method,
  }) async {
    final settings = await ReportHeaderSettings.load();
    final excel = Excel.createExcel();
    final sheet = excel['Pembayaran'];
    excel.delete('Sheet1');
    final numberStyle = CellStyle(numberFormat: const CustomNumericNumFormat(formatCode: '#,##0'), horizontalAlign: HorizontalAlign.Right);
    final total = rows.fold<int>(0, (sum, row) => sum + _int(row['jumlah']));
    sheet.appendRow([TextCellValue(settings.companyName)]);
    sheet.appendRow([TextCellValue('LAPORAN PEMBAYARAN')]);
    sheet.appendRow([TextCellValue('Periode'), TextCellValue(Formatter.tanggalPendek(dari)), TextCellValue('-'), TextCellValue(Formatter.tanggalPendek(sampai))]);
    sheet.appendRow([TextCellValue('Pelanggan'), TextCellValue(customer), TextCellValue('Metode'), TextCellValue(method)]);
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Tanggal'), TextCellValue('Pelanggan'), TextCellValue('Jumlah'), TextCellValue('Metode'), TextCellValue('Keterangan')]);
    var rowIndex = 6;
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(Formatter.tanggalPendek(_date(row['tanggal']))),
        TextCellValue('${row['nama_pelanggan'] ?? ''}'),
        IntCellValue(_int(row['jumlah'])),
        TextCellValue(_methodLabel(row['metode'])),
        TextCellValue('${row['keterangan'] ?? ''}'),
      ]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = numberStyle;
      rowIndex++;
    }
    sheet.appendRow([TextCellValue('TOTAL'), TextCellValue(''), IntCellValue(total), TextCellValue(''), TextCellValue('')]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = numberStyle;
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'laporan_pembayaran_${DateTime.now().millisecondsSinceEpoch}.xlsx'));
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Gagal membuat file Excel');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Laporan Pembayaran'));
  }

  static pw.Widget _summary(String label, int value) => pw.Expanded(child: pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
      pw.SizedBox(height: 3),
      pw.Text(Formatter.rupiah(value), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    ]),
  ));

  static int _int(dynamic value) => (value as num?)?.toInt() ?? 0;
  static DateTime _date(dynamic value) => value is DateTime ? value : DateTime.parse('$value');
  static String _methodLabel(dynamic value) {
    switch ('$value') {
      case 'cash': return 'Cash';
      case 'transfer': return 'Transfer';
      case '': return 'Tidak dicatat';
      default: return '$value';
    }
  }
}
