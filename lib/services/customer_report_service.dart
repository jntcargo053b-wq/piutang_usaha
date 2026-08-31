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

class CustomerReportService {
  static Future<void> sharePdf({required String namaPelanggan, required List<TransaksiKredit> transaksi, required Map<int, List<Pembayaran>> pembayaran}) async {
    final settings = await ReportHeaderSettings.load();
    final sorted = List<TransaksiKredit>.from(transaksi)..sort((a,b)=>a.tanggal.compareTo(b.tanggal));
    final total = sorted.fold<int>(0,(sum,t)=>sum+t.jumlah);
    final firstDate=sorted.isEmpty?DateTime.now():sorted.first.tanggal; final lastDate=sorted.isEmpty?DateTime.now():sorted.last.tanggal;
    pw.MemoryImage? logo;
    if(settings.logoPath!=null){final file=File(settings.logoPath!);if(await file.exists())logo=pw.MemoryImage(await file.readAsBytes());}
    final doc=pw.Document();
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.fromLTRB(28,30,28,30),build:(_)=>[
      pw.Container(padding:const pw.EdgeInsets.only(bottom:12),decoration:const pw.BoxDecoration(border:pw.Border(bottom:pw.BorderSide(width:1.2))),child:pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.center,children:[if(logo!=null)pw.Container(width:58,height:58,padding:const pw.EdgeInsets.only(right:10),child:pw.Image(logo!,fit:pw.BoxFit.contain)),pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text(settings.companyName,style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:4),pw.Text(settings.reportTitle,style:pw.TextStyle(fontSize:11,fontWeight:pw.FontWeight.bold))]))])),
      pw.SizedBox(height:14),pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Expanded(child:_infoBlock('PELANGGAN',namaPelanggan)),pw.SizedBox(width:18),pw.Expanded(child:_infoBlock('PERIODE PENAGIHAN','${Formatter.tanggalPendek(firstDate)} - ${Formatter.tanggalPendek(lastDate)}'))]),pw.SizedBox(height:18),pw.Text('RINCIAN TRANSAKSI',style:pw.TextStyle(fontSize:11,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:6),_transactionTable(sorted),pw.SizedBox(height:12),pw.Text('Terbilang:',style:pw.TextStyle(fontSize:8,fontWeight:pw.FontWeight.bold)),pw.Text('${_terbilang(total)} rupiah',style:const pw.TextStyle(fontSize:9)),pw.SizedBox(height:18),pw.Text('Jumlah transaksi: ${sorted.length}',style:const pw.TextStyle(fontSize:8))]));
    final dir=await getTemporaryDirectory();final safeName=namaPelanggan.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'),'_');final file=File(p.join(dir.path,'laporan_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf'));await file.writeAsBytes(await doc.save());await SharePlus.instance.share(ShareParams(files:[XFile(file.path)],text:'Laporan transaksi pelanggan $namaPelanggan'));
  }
  static pw.Widget _infoBlock(String label,String value)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text(label,style:pw.TextStyle(fontSize:7,color:PdfColors.grey700,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:2),pw.Text(value,maxLines:2,overflow:pw.TextOverflow.clip,style:const pw.TextStyle(fontSize:9))]);
  static pw.Widget _transactionTable(List<TransaksiKredit> transaksi){
    // ignore: prefer_const_declarations
    final headerStyle=pw.TextStyle(fontSize:7.5,fontWeight:pw.FontWeight.bold); const bodyStyle=pw.TextStyle(fontSize:7.2);
    final rows=<pw.TableRow>[pw.TableRow(repeat:true,decoration:const pw.BoxDecoration(color:PdfColors.grey200),children:[_cell('No',headerStyle,align:pw.TextAlign.center),_cell('Tanggal',headerStyle),_cell('Resi',headerStyle),_cell('Penerima',headerStyle),_cell('Kota',headerStyle),_cell('Total',headerStyle,align:pw.TextAlign.right)])];
    for(var i=0;i<transaksi.length;i++){final t=transaksi[i];rows.add(pw.TableRow(children:[_cell('${i+1}',bodyStyle,align:pw.TextAlign.center),_cell(Formatter.tanggalPendek(t.tanggal),bodyStyle),_cell(t.nomorResi,bodyStyle),_cell(t.namaPenerima,bodyStyle),_cell(t.kotaTujuan,bodyStyle),_cell(Formatter.rupiah(t.jumlah),bodyStyle,align:pw.TextAlign.right)]));}
    rows.add(pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.grey100),children:[_cell('',headerStyle),_cell('',headerStyle),_cell('',headerStyle),_cell('',headerStyle),_cell('TOTAL TAGIHAN',headerStyle,align:pw.TextAlign.right),_cell(Formatter.rupiah(transaksi.fold<int>(0,(sum,t)=>sum+t.jumlah)),headerStyle,align:pw.TextAlign.right)]));
    return pw.Table(border:pw.TableBorder.all(color:PdfColors.grey500,width:.5),columnWidths:const{0:pw.FixedColumnWidth(22),1:pw.FixedColumnWidth(55),2:pw.FlexColumnWidth(1.15),3:pw.FlexColumnWidth(1.25),4:pw.FlexColumnWidth(1.35),5:pw.FixedColumnWidth(72)},defaultVerticalAlignment:pw.TableCellVerticalAlignment.middle,children:rows);
  }
  static pw.Widget _cell(String value,pw.TextStyle style,{pw.TextAlign align=pw.TextAlign.left})=>pw.Padding(padding:const pw.EdgeInsets.symmetric(horizontal:4,vertical:4),child:pw.Text(value,style:style,textAlign:align,maxLines:3,overflow:pw.TextOverflow.clip));
  static String _terbilang(int value){
    if(value==0)return'Nol';
    final negative=value<0; final magnitude=value.abs();
    const words=['Nol','Satu','Dua','Tiga','Empat','Lima','Enam','Tujuh','Delapan','Sembilan','Sepuluh','Sebelas'];
    String convert(int n){if(n<12)return words[n];if(n<20)return'${convert(n-10)} Belas';if(n<100)return'${convert(n~/10)} Puluh${n%10==0?'':' ${convert(n%10)}'}';if(n<200)return'Seratus${n%100==0?'':' ${convert(n%100)}'}';if(n<1000)return'${convert(n~/100)} Ratus${n%100==0?'':' ${convert(n%100)}'}';if(n<2000)return'Seribu${n%1000==0?'':' ${convert(n%1000)}'}';if(n<1000000)return'${convert(n~/1000)} Ribu${n%1000==0?'':' ${convert(n%1000)}'}';if(n<1000000000)return'${convert(n~/1000000)} Juta${n%1000000==0?'':' ${convert(n%1000000)}'}';return'${convert(n~/1000000000)} Miliar${n%1000000000==0?'':' ${convert(n%1000000000)}'}';}
    return negative?'Minus ${convert(magnitude)}':convert(magnitude);
  }
  static Future<void> shareExcel({required String namaPelanggan,required List<TransaksiKredit> transaksi,required Map<int,List<Pembayaran>> pembayaran}) async {final settings=await ReportHeaderSettings.load();final sorted=List<TransaksiKredit>.from(transaksi)..sort((a,b)=>a.tanggal.compareTo(b.tanggal));final total=sorted.fold<int>(0,(sum,t)=>sum+t.jumlah);final firstDate=sorted.isEmpty?DateTime.now():sorted.first.tanggal;final lastDate=sorted.isEmpty?DateTime.now():sorted.last.tanggal;final excel=Excel.createExcel();final sheet=excel['Laporan'];sheet.appendRow([TextCellValue(settings.companyName)]);sheet.appendRow([TextCellValue(settings.reportTitle)]);sheet.appendRow([TextCellValue('Pelanggan'),TextCellValue(namaPelanggan)]);sheet.appendRow([TextCellValue('Periode Penagihan'),TextCellValue('${Formatter.tanggalPendek(firstDate)} - ${Formatter.tanggalPendek(lastDate)}')]);sheet.appendRow([]);sheet.appendRow([TextCellValue('No'),TextCellValue('Tanggal'),TextCellValue('Resi'),TextCellValue('Penerima'),TextCellValue('Kota'),TextCellValue('Total')]);for(var i=0;i<sorted.length;i++){final t=sorted[i];sheet.appendRow([IntCellValue(i+1),TextCellValue(Formatter.tanggalPendek(t.tanggal)),TextCellValue(t.nomorResi),TextCellValue(t.namaPenerima),TextCellValue(t.kotaTujuan),IntCellValue(t.jumlah)]);}sheet.appendRow([TextCellValue(''),TextCellValue(''),TextCellValue(''),TextCellValue(''),TextCellValue('TOTAL TAGIHAN'),IntCellValue(total)]);sheet.appendRow([]);sheet.appendRow([TextCellValue('Terbilang'),TextCellValue('${_terbilang(total)} rupiah')]);final bytes=excel.encode();if(bytes==null)throw Exception('Gagal membuat Excel.');final dir=await getTemporaryDirectory();final safeName=namaPelanggan.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'),'_');final file=File(p.join(dir.path,'laporan_${safeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx'));await file.writeAsBytes(bytes);await SharePlus.instance.share(ShareParams(files:[XFile(file.path)],text:'Laporan transaksi pelanggan $namaPelanggan'));}
}
