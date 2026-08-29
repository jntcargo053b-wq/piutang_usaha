import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/models/pelanggan.dart';
import 'package:piutang_usaha/models/pembayaran.dart';
import 'package:piutang_usaha/models/transaksi_kredit.dart';
import 'package:piutang_usaha/services/db_helper.dart';

void main(){
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db=DbHelper.instance;
  setUp(()async{await db.tutupKoneksi();final f=File(await db.getDbPath());if(await f.exists())await f.delete();});
  tearDown(()async{await db.tutupKoneksi();final f=File(await db.getDbPath());if(await f.exists())await f.delete();});
  test('laporan memisahkan pembayaran periode',()async{
    final pid=await db.insertPelanggan(Pelanggan(nama:'Test'));
    final tid=await db.insertTransaksi(TransaksiKredit(pelangganId:pid,tanggal:DateTime(2026,8,5),nomorResi:'R1',namaPenerima:'A',kotaTujuan:'Malang',jumlah:100000));
    await db.insertPembayaran(Pembayaran(transaksiId:tid,tanggal:DateTime(2026,8,10),jumlah:30000));
    await db.insertPembayaran(Pembayaran(transaksiId:tid,tanggal:DateTime(2026,9,10),jumlah:20000));
    final r=await db.getRekapPeriode(dari:DateTime(2026,8,1),sampai:DateTime(2026,8,31));
    expect(r.single['total_dibayar'],50000);expect(r.single['dibayar_periode'],30000);
  });
  test('overpayment ditolak',()async{
    final pid=await db.insertPelanggan(Pelanggan(nama:'Test'));
    final tid=await db.insertTransaksi(TransaksiKredit(pelangganId:pid,tanggal:DateTime(2026,8,1),nomorResi:'R2',namaPenerima:'A',kotaTujuan:'Malang',jumlah:100000));
    expect(()=>db.insertPembayaran(Pembayaran(transaksiId:tid,tanggal:DateTime.now(),jumlah:100001)),throwsA(isA<ValidasiException>()));
  });
  test('aggregate saldo pelanggan benar',()async{
    final pid=await db.insertPelanggan(Pelanggan(nama:'Test'));
    final tid=await db.insertTransaksi(TransaksiKredit(pelangganId:pid,tanggal:DateTime.now(),nomorResi:'R3',namaPenerima:'A',kotaTujuan:'Malang',jumlah:100000));
    await db.insertPembayaran(Pembayaran(transaksiId:tid,tanggal:DateTime.now(),jumlah:25000));
    final r=await db.getPelangganDenganSisa();expect(r.single['sisa_piutang'],75000);
  });
}
