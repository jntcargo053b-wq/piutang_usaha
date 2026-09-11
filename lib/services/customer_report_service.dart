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
import 'report_header_settings.dart';

enum CustomerReportType { summary, detailed }

class CustomerReportService {
  static int _paidFor(TransaksiKredit t, Map<int, List<Pembayaran>> pembayaran) => pembayaran[t.id]?.fold<int>(0, (s, p) => s + p.jumlah) ?? 0;

  static Future<void> sharePdf({required String namaPelanggan, required List<TransaksiKredit> transaksi, required Map<int, List<Pembayaran>> pembayaran, CustomerReportType type = CustomerReportType.detailed}) async {
    final settings = await ReportHeaderSettings.load();
    final sorted = List<TransaksiKredit>.from(transaksi)..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    final total = sorted.fold<int>(0, (s, t) => s + t.jumlah);
    final paid = sorted.fold<int>(0, (s, t) => s + _paidFor(t, pembayaran));
    final remaining = (total - paid).clamp(0, total);
    final first = sorted.isEmpty ? DateTime.now() : sorted.first.tanggal;
    final last = sorted.isEmpty ? DateTime.now() : sorted.last.tanggal;
    final logo = await _loadLogo(settings.logoPath);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 30),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Dicetak ${Formatter.tanggalPendek(DateTime.now())}', style: const pw.TextStyle(fontSize: 7)),
        pw.Text('Halaman ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
      ]),
      build: (_) => [
        pw.Container(padding: const pw.EdgeInsets.only(bottom: 12), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.2))), child: pw.Row(children: [
          if (logo != null) pw.Container(width: 58, height: 58, padding: const pw.EdgeInsets.only(right: 10), child: pw.Image(logo, fit: pw.BoxFit.contain)),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(settings.companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(settings.reportTitle, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ])),
        ])),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          pw.Expanded(child: _info('PELANGGAN', namaPelanggan)),
          pw.SizedBox(width: 18),
          pw.Expanded(child: _info('PERIODE TRANSAKSI', '${Formatter.tanggalPendek(first)} - ${Formatter.tanggalPendek(last)}')),
        ]),
        pw.SizedBox(height: 18),
        pw.Text(type == CustomerReportType.summary ? 'RINCIAN TRANSAKSI' : 'RINCIAN TRANSAKSI & PIUTANG', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _table(sorted, pembayaran, type),
        pw.SizedBox(height: 12),
        if (type == CustomerReportType.summary) ...[
          pw.Text('RINGKASAN TRANSAKSI', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Total transaksi: ${Formatter.rupiah(total)}'),
        ] else ...[
          pw.Text('RINGKASAN TAGIHAN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Total transaksi: ${Formatter.rupiah(total)}'),
          pw.Text('Total pembayaran: ${Formatter.rupiah(paid)}'),
          pw.Text('Sisa tagihan: ${Formatter.rupiah(remaining)}'),
          pw.SizedBox(height: 12),
          pw.Text('Terbilang: ${_terbilang(remaining)} rupiah', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
        pw.SizedBox(height: 14),
        pw.Text('Jumlah transaksi: ${sorted.length}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ));
    final dir = await getTemporaryDirectory();
    final safe = namaPelanggan.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final suffix = type == CustomerReportType.summary ? 'ringkas' : 'lengkap';
    final file = File(p.join(dir.path, 'laporan_${safe}_${suffix}_${DateTime.now().millisecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Laporan $suffix pelanggan $namaPelanggan'));
  }

  static Future<pw.MemoryImage?> _loadLogo(String? logoPath) async {
    if (logoPath == null) return null;
    final file = File(logoPath);
    if (!await file.exists()) return null;
    return pw.MemoryImage(await file.readAsBytes());
  }

  static pw.Widget _info(String label, String value) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text(label, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 2),
    pw.Text(value, maxLines: 2, style: const pw.TextStyle(fontSize: 9)),
  ]);

  static pw.Widget _table(List<TransaksiKredit> ts, Map<int, List<Pembayaran>> p, CustomerReportType type) {
    final headers = type == CustomerReportType.summary
        ? ['No', 'Tanggal', 'Resi', 'Penerima', 'Kota', 'Qty', 'Berat', 'Total Transaksi']
        : ['No', 'Tanggal', 'Resi', 'Penerima', 'Kota', 'Total Transaksi', 'Dibayar', 'Sisa'];
    final rows = <pw.TableRow>[
      pw.TableRow(repeat: true, decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: headers.map((v) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(v, textAlign: _rightHeader(v) ? pw.TextAlign.right : pw.TextAlign.left, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
      )).toList()),
    ];
    for (var i = 0; i < ts.length; i++) {
      final t = ts[i];
      if (type == CustomerReportType.summary) {
        rows.add(pw.TableRow(children: [
          _c('${i + 1}'), _c(Formatter.tanggalPendek(t.tanggal)), _c(t.nomorResi), _c(t.namaPenerima), _c(t.kotaTujuan),
          _c('${t.quantity}', right: true), _c(_formatBerat(t.berat), right: true), _c(Formatter.rupiah(t.jumlah), right: true),
        ]));
      } else {
        final paidForTransaction = _paidFor(t, p);
        final sisa = (t.jumlah - paidForTransaction).clamp(0, t.jumlah);
        rows.add(pw.TableRow(children: [
          _c('${i + 1}'), _c(Formatter.tanggalPendek(t.tanggal)), _c(t.nomorResi), _c(t.namaPenerima), _c(t.kotaTujuan),
          _c(Formatter.rupiah(t.jumlah), right: true), _c(Formatter.rupiah(paidForTransaction), right: true), _c(Formatter.rupiah(sisa), right: true),
        ]));
      }
    }
    if (type == CustomerReportType.summary) {
      rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
        _c(''), _c(''), _c(''), _c(''), _c('TOTAL', bold: true), _c('${ts.fold<int>(0, (s, t) => s + t.quantity)}', right: true, bold: true),
        _c(_formatBerat(ts.fold<double>(0, (s, t) => s + t.berat)), right: true, bold: true), _c(Formatter.rupiah(ts.fold<int>(0, (s, t) => s + t.jumlah)), right: true, bold: true),
      ]));
    } else {
      rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
        _c(''), _c(''), _c(''), _c(''), _c('TOTAL', bold: true),
        _c(Formatter.rupiah(ts.fold<int>(0, (s, t) => s + t.jumlah)), right: true, bold: true),
        _c(Formatter.rupiah(ts.fold<int>(0, (s, t) => s + _paidFor(t, p))), right: true, bold: true),
        _c(Formatter.rupiah(ts.fold<int>(0, (s, t) => s + (t.jumlah - _paidFor(t, p)).clamp(0, t.jumlah))), right: true, bold: true),
      ]));
    }
    return pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), columnWidths: type == CustomerReportType.summary ? const {
      0: pw.FixedColumnWidth(20), 1: pw.FixedColumnWidth(48), 2: pw.FlexColumnWidth(1.1), 3: pw.FlexColumnWidth(1.25), 4: pw.FlexColumnWidth(1.15), 5: pw.FixedColumnWidth(28), 6: pw.FixedColumnWidth(38), 7: pw.FixedColumnWidth(72),
    } : const {
      0: pw.FixedColumnWidth(20), 1: pw.FixedColumnWidth(48), 2: pw.FlexColumnWidth(1.0), 3: pw.FlexColumnWidth(1.15), 4: pw.FlexColumnWidth(1.1), 5: pw.FixedColumnWidth(65), 6: pw.FixedColumnWidth(60), 7: pw.FixedColumnWidth(65),
    }, children: rows);
  }

  static bool _rightHeader(String value) => {'Qty', 'Berat', 'Total Transaksi', 'Dibayar', 'Sisa'}.contains(value);

  static pw.Widget _c(String v, {bool right = false, bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: pw.Text(v, textAlign: right ? pw.TextAlign.right : pw.TextAlign.left, style: pw.TextStyle(fontSize: 6.7, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal), maxLines: 3),
  );

  static String _formatBerat(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString().replaceAll('.', ',');
  }

  static String _terbilang(int value) {
    if (value < 0) return 'Minus ${_terbilang(-value)}';
    if (value == 0) return 'Nol';
    const w = ['Nol','Satu','Dua','Tiga','Empat','Lima','Enam','Tujuh','Delapan','Sembilan','Sepuluh','Sebelas'];
    String c(int n) {
      if (n < 12) return w[n];
      if (n < 20) return '${c(n - 10)} Belas';
      if (n < 100) return '${c(n ~/ 10)} Puluh${n % 10 == 0 ? '' : ' ${c(n % 10)}'}';
      if (n < 200) return 'Seratus${n % 100 == 0 ? '' : ' ${c(n % 100)}'}';
      if (n < 1000) return '${c(n ~/ 100)} Ratus${n % 100 == 0 ? '' : ' ${c(n % 100)}'}';
      if (n < 2000) return 'Seribu${n % 1000 == 0 ? '' : ' ${c(n % 1000)}'}';
      if (n < 1000000) return '${c(n ~/ 1000)} Ribu${n % 1000 == 0 ? '' : ' ${c(n % 1000)}'}';
      if (n < 1000000000) return '${c(n ~/ 1000000)} Juta${n % 1000000 == 0 ? '' : ' ${c(n % 1000000)}'}';
      return '${c(n ~/ 1000000000)} Miliar${n % 1000000000 == 0 ? '' : ' ${c(n % 1000000000)}'}';
    }
    return c(value);
  }

  static Future<void> shareExcel({required String namaPelanggan, required List<TransaksiKredit> transaksi, required Map<int, List<Pembayaran>> pembayaran, CustomerReportType type = CustomerReportType.detailed}) async {
    final settings = await ReportHeaderSettings.load();
    final sorted = List<TransaksiKredit>.from(transaksi)..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    final total = sorted.fold<int>(0, (s, t) => s + t.jumlah);
    final paid = sorted.fold<int>(0, (s, t) => s + _paidFor(t, pembayaran));
    final remaining = (total - paid).clamp(0, total);
    final e = Excel.createExcel();
    final s = e['Laporan'];
    s.appendRow([TextCellValue(settings.companyName)]);
    s.appendRow([TextCellValue(settings.reportTitle)]);
    s.appendRow([TextCellValue('Pelanggan'), TextCellValue(namaPelanggan)]);
    s.appendRow([TextCellValue('Periode Transaksi'), TextCellValue('${Formatter.tanggalPendek(sorted.isEmpty ? DateTime.now() : sorted.first.tanggal)} - ${Formatter.tanggalPendek(sorted.isEmpty ? DateTime.now() : sorted.last.tanggal)}')]);
    s.appendRow([]);
    if (type == CustomerReportType.summary) {
      s.appendRow([TextCellValue('No'), TextCellValue('Tanggal'), TextCellValue('Resi'), TextCellValue('Penerima'), TextCellValue('Kota'), TextCellValue('Qty'), TextCellValue('Berat'), TextCellValue('Total Transaksi')]);
      for (var i = 0; i < sorted.length; i++) {
        final t = sorted[i];
        s.appendRow([IntCellValue(i + 1), TextCellValue(Formatter.tanggalPendek(t.tanggal)), TextCellValue(t.nomorResi), TextCellValue(t.namaPenerima), TextCellValue(t.kotaTujuan), IntCellValue(t.quantity), DoubleCellValue(t.berat), IntCellValue(t.jumlah)]);
      }
      s.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue('TOTAL'), IntCellValue(sorted.fold<int>(0, (sum, t) => sum + t.quantity)), DoubleCellValue(sorted.fold<double>(0, (sum, t) => sum + t.berat)), IntCellValue(total)]);
      s.appendRow([TextCellValue('Total Transaksi'), IntCellValue(total)]);
    } else {
      s.appendRow([TextCellValue('No'), TextCellValue('Tanggal'), TextCellValue('Resi'), TextCellValue('Penerima'), TextCellValue('Kota'), TextCellValue('Total Transaksi'), TextCellValue('Dibayar'), TextCellValue('Sisa')]);
      for (var i = 0; i < sorted.length; i++) {
        final t = sorted[i];
        final paidForTransaction = _paidFor(t, pembayaran);
        final sisa = (t.jumlah - paidForTransaction).clamp(0, t.jumlah);
        s.appendRow([IntCellValue(i + 1), TextCellValue(Formatter.tanggalPendek(t.tanggal)), TextCellValue(t.nomorResi), TextCellValue(t.namaPenerima), TextCellValue(t.kotaTujuan), IntCellValue(t.jumlah), IntCellValue(paidForTransaction), IntCellValue(sisa)]);
      }
      s.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue('TOTAL'), IntCellValue(total), IntCellValue(paid), IntCellValue(remaining)]);
      s.appendRow([TextCellValue('Total Transaksi'), IntCellValue(total)]);
      s.appendRow([TextCellValue('Total Pembayaran'), IntCellValue(paid)]);
      s.appendRow([TextCellValue('Sisa Tagihan'), IntCellValue(remaining)]);
      s.appendRow([TextCellValue('Terbilang'), TextCellValue('${_terbilang(remaining)} rupiah')]);
    }
    final bytes = e.encode();
    if (bytes == null) throw Exception('Gagal membuat Excel.');
    final dir = await getTemporaryDirectory();
    final safe = namaPelanggan.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final suffix = type == CustomerReportType.summary ? 'ringkas' : 'lengkap';
    final f = File(p.join(dir.path, 'laporan_${safe}_${suffix}_${DateTime.now().millisecondsSinceEpoch}.xlsx'));
    await f.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'Laporan $suffix pelanggan $namaPelanggan'));
  }
}
