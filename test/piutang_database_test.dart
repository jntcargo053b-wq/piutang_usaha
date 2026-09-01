import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/models/pelanggan.dart';
import 'package:piutang_usaha/models/transaksi_kredit.dart';
import 'package:piutang_usaha/models/pembayaran.dart';
import 'package:piutang_usaha/services/db_helper.dart';
import 'package:piutang_usaha/services/payment_service.dart';

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

  Future<int> customer() => db.insertPelanggan(Pelanggan(nama: 'Pelanggan Test'));

  Future<int> transaction(
    int customerId, {
    int amount = 100000,
    String resi = 'RESI-1',
  }) {
    return db.insertTransaksi(
      TransaksiKredit(
        pelangganId: customerId,
        tanggal: DateTime(2026, 8, 1),
        nomorResi: resi,
        namaPenerima: 'Penerima Test',
        kotaTujuan: 'Jakarta',
        jumlah: amount,
      ),
    );
  }

  test('database initializes and starts empty', () async {
    expect(await db.getAllPelanggan(), isEmpty);
  });

  test('payment equal to outstanding is accepted and closes transaction', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);

    await db.insertPembayaran(
      Pembayaran(
        transaksiId: tid,
        tanggal: DateTime(2026, 8, 10),
        jumlah: 100000,
        metode: 'cash',
      ),
    );

    final t = await db.getTransaksiById(tid);
    expect(t, isNotNull);
    expect(t!.sisa, 0);
  });

  test('overpayment is rejected', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);

    await expectLater(
      db.insertPembayaran(
        Pembayaran(
          transaksiId: tid,
          tanggal: DateTime(2026, 8, 10),
          jumlah: 100001,
          metode: 'transfer',
        ),
      ),
      throwsA(isA<ValidasiException>()),
    );

    expect(await db.getPembayaranByTransaksi(tid), isEmpty);
  });

  test('customer payment allocates oldest transactions first atomically', () async {
    final cid = await customer();
    final tid1 = await transaction(cid, amount: 100000, resi: 'RESI-1');
    final tid2 = await transaction(cid, amount: 150000, resi: 'RESI-2');

    final allocated = await PaymentService(db: db).payCustomer(
      transactions: [
        (await db.getTransaksiById(tid1))!,
        (await db.getTransaksiById(tid2))!,
      ],
      amount: 180000,
      method: PaymentService.transfer,
      date: DateTime(2026, 8, 11),
    );

    expect(allocated, 180000);
    expect((await db.getTransaksiById(tid1))!.sisa, 0);
    expect((await db.getTransaksiById(tid2))!.sisa, 70000);
  });

  test('customer payment rolls back all allocations when a later allocation fails', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);
    final invalid = TransaksiKredit(
      id: 999999,
      pelangganId: cid,
      tanggal: DateTime(2026, 8, 2),
      nomorResi: 'INVALID',
      namaPenerima: 'Penerima',
      kotaTujuan: 'Jakarta',
      jumlah: 100000,
    );

    Future<void> act() async {
      await PaymentService(db: db).payCustomer(
        transactions: [(await db.getTransaksiById(tid))!, invalid],
        amount: 150000,
        method: PaymentService.cash,
      );
    }

    await expectLater(act(), throwsA(isA<ValidasiException>()));

    expect(await db.getPembayaranByTransaksi(tid), isEmpty);
    expect((await db.getTransaksiById(tid))!.sisa, 100000);
  });

  test('update transaction rejects invalid data', () async {
    final cid = await customer();
    final tid = await transaction(cid);
    final original = await db.getTransaksiById(tid);
    expect(original, isNotNull);

    final invalid = TransaksiKredit(
      id: tid,
      pelangganId: cid,
      tanggal: original!.tanggal,
      nomorResi: original.nomorResi,
      namaPenerima: original.namaPenerima,
      kotaTujuan: original.kotaTujuan,
      jumlah: 0,
      catatan: original.catatan,
      totalDibayar: original.totalDibayar,
    );

    await expectLater(
      db.updateTransaksi(invalid),
      throwsA(isA<ValidasiException>()),
    );
  });

  test('cascade delete removes transactions and payments', () async {
    final cid = await customer();
    final tid = await transaction(cid);
    await db.insertPembayaran(
      Pembayaran(
        transaksiId: tid,
        tanggal: DateTime(2026, 8, 10),
        jumlah: 10000,
        metode: 'cash',
      ),
    );

    await db.deletePelanggan(cid);

    expect(await db.getTransaksiById(tid), isNull);
    expect(await db.getPembayaranByTransaksi(tid), isEmpty);
  });

  test('aging places outstanding balance in correct bucket', () async {
    final cid = await customer();
    await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: cid,
        tanggal: DateTime(2026, 8, 20),
        nomorResi: 'A',
        namaPenerima: 'A',
        kotaTujuan: 'Jakarta',
        jumlah: 10000,
      ),
    );
    await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: cid,
        tanggal: DateTime(2026, 7, 1),
        nomorResi: 'B',
        namaPenerima: 'B',
        kotaTujuan: 'Jakarta',
        jumlah: 20000,
      ),
    );
    await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: cid,
        tanggal: DateTime(2026, 5, 1),
        nomorResi: 'C',
        namaPenerima: 'C',
        kotaTujuan: 'Jakarta',
        jumlah: 30000,
      ),
    );
    await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: cid,
        tanggal: DateTime(2026, 1, 1),
        nomorResi: 'D',
        namaPenerima: 'D',
        kotaTujuan: 'Jakarta',
        jumlah: 40000,
      ),
    );

    final aging = await db.getAgingPiutang(asOf: DateTime(2026, 8, 31));
    expect(aging['0_30'], 10000);
    expect(aging['31_60'], 20000);
    expect(aging['61_90'], 30000);
    expect(aging['91_plus'], 40000);
  });
}
