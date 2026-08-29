import 'package:intl/intl.dart';
class Formatter {
  static final _rupiah=NumberFormat.currency(locale:'id_ID',symbol:'Rp ',decimalDigits:0);
  static final _tanggalPanjang=DateFormat('d MMMM yyyy','id_ID');
  static final _tanggalPendek=DateFormat('dd/MM/yyyy');
  static String rupiah(num value)=>_rupiah.format(value);
  static String tanggalPanjang(DateTime date)=>_tanggalPanjang.format(date);
  static String tanggalPendek(DateTime date)=>_tanggalPendek.format(date);
}
