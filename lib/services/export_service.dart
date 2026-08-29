import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../utils/formatter.dart';

class ExportService {
  static Future<void> exportRekapKePdf(List<Map<String,dynamic>> rows, DateTime dari, DateTime sampai) async {
    final doc=pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape,build:(ctx)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
      pw.Text('Laporan Piutang Usaha',style=pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),
      pw.Text('Periode ${Formatter.tanggalPendek(dari)} - ${Formatter.tanggalPendek(sampai)}'),pw.SizedBox(height:12),
      pw.Expanded(child:pw.Table.fromTextArray(headers:['Tanggal','Pelanggan','Resi','Penerima','Kota','Kredit','Dibayar','Sisa'],data:rows.map((r){final k=(r['jumlah'] as num).toInt();final d=(r['total_dibayar'] as num).toInt();return [Formatter.tanggalPendek(DateTime.parse(r['tanggal'] as String)),r['nama_pelanggan']??'',r['nomor_resi']??'',r['nama_penerima']??'',r['kota_tujuan']??'',Formatter.rupiah(k),Formatter.rupiah(d),Formatter.rupiah(k-d)];}).toList()))
    ])));
    final dir=await getTemporaryDirectory(); final file=File(p.join(dir.path,'laporan_piutang_${DateTime.now().millisecondsSinceEpoch}.pdf')); await file.writeAsBytes(await doc.save()); await Share.shareXFiles([XFile(file.path)],text:'Laporan Piutang Usaha');
  }

  static Future<void> exportRekapKeExcel(List<Map<String,dynamic>> rows) async {
    final excel=Excel.createExcel(); final sheet=excel['Rekap'];
    sheet.appendRow(['Tanggal','Pelanggan','Resi','Penerima','Kota','Kredit','Dibayar','Dibayar Periode','Sisa']);
    for(final r in rows){final k=(r['jumlah'] as num).toInt();final d=(r['total_dibayar'] as num).toInt();final dp=(r['dibayar_periode'] as num?)?.toInt()??0;sheet.appendRow([r['tanggal'],r['nama_pelanggan'],r['nomor_resi'],r['nama_penerima'],r['kota_tujuan'],k,d,dp,k-d]);}
    final bytes=excel.encode();if(bytes==null)throw Exception('Gagal membuat Excel.'); final dir=await getTemporaryDirectory(); final file=File(p.join(dir.path,'laporan_piutang_${DateTime.now().millisecondsSinceEpoch}.xlsx'));await file.writeAsBytes(bytes);await Share.shareXFiles([XFile(file.path)],text:'Laporan Piutang Usaha Excel');
  }
}
