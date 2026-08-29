import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/models/pelanggan.dart';
import 'package:piutang_usaha/models/pembayaran.dart';
import 'package:piutang_usaha/models/transaksi_kredit.dart';
import 'package:piutang_usaha/services/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = DbHelper.instance;

  setUp(() async {
    await db.tutupKoneksi();
    final path = await db.getDbPath();
    final file = File(path);
    if (await file.exists()) await file.delete();
  });

  tearDown(() async {
    await db.tutupKoneksi();
    final path = await db.getDbPath();
    final file = File(path);
    if (await file.exists()) await file.delete();
  });

  test('laporan memisahkan pembayaran periode', () async {
    final pelangganId = await db.insertPelanggan(Pelanggan(nama: 'Test'));
    final transaksiId = await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: pelangganId,
        tanggal: DateTime(2026, 8, 5),
        nomorResi: 'R1',
        namaPenerima: 'A',
        kotaTujuan: 'Malang',
        jumlah: 100000,
      ),
    );
    await db.insertPembayaran(
      Pembayaran(
        transaksiId: transaksiId,
        tanggal: DateTime(2026, 8, 10),
        jumlah: 30000,
      ),
    );
    await db.insertPembayaran(
      Pembayaran(
        transaksiId: transaksiId,
        tanggal: DateTime(2026, 9, 10),
        jumlah: 20000,
      ),
    );

    final result = await db.getRekapPeriode(
      dari: DateTime(2026, 8, 1),
      sampai: DateTime(2026, 8, 31),
    );

    expect(result.single['total_dibayar'], 50000);
    expect(result.single['dibayar_periode'], 30000);
  });

  test('overpayment ditolak', () async {
    final pelangganId = await db.insertPelanggan(Pelanggan(nama: 'Test'));
    final transaksiId = await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: pelangganId,
        tanggal: DateTime(2026, 8, 1),
        nomorResi: 'R2',
        namaPenerima: 'A',
        kotaTujuan: 'Malang',
        jumlah: 100000,
      ),
    );

    expect(
      () => db.insertPembayaran(
        Pembayaran(
          transaksiId: transaksiId,
          tanggal: DateTime(2026, 8, 2),
          jumlah: 100001,
        ),
      ),
      throwsA(isA<ValidasiException>()),
    );
  });

  test('aggregate saldo pelanggan benar', () async {
    final pelangganId = await db.insertPelanggan(Pelanggan(nama: 'Test'));
    final transaksiId = await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: pelangganId,
        tanggal: DateTime(2026, 8, 1),
        nomorResi: 'R3',
        namaPenerima: 'A',
        kotaTujuan: 'Malang',
        jumlah: 100000,
      ),
    );
    await db.insertPembayaran(
      Pembayaran(
        transaksiId: transaksiId,
        tanggal: DateTime(2026, 8, 2),
        jumlah: 25000,
      ),
    );

    final result = await db.getPelangganDenganSisa();
    expect(result.single['sisa_piutang'], 75000);
  });
}
