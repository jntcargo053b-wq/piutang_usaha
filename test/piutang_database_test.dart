import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/models/pelanggan.dart';
import 'package:piutang_usaha/models/transaksi_kredit.dart';
import 'package:piutang_usaha/models/pembayaran.dart';
import 'package:piutang_usaha/models/import_transaksi_row.dart';
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

  Future<int> customer([String name = 'Pelanggan Test']) =>
      db.insertPelanggan(Pelanggan(nama: name));

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

  Future<void> payment(int transactionId, int amount, {String method = 'cash'}) {
    return db.insertPembayaran(
      Pembayaran(
        transaksiId: transactionId,
        tanggal: DateTime(2026, 8, 10),
        jumlah: amount,
        metode: method,
      ),
    );
  }

  Future<TransaksiKredit> updatedTransaction(
    int id,
    int customerId,
    int amount,
  ) async {
    final current = (await db.getTransaksiById(id))!;
    return TransaksiKredit(
      id: id,
      pelangganId: customerId,
      tanggal: current.tanggal,
      nomorResi: current.nomorResi,
      namaPenerima: current.namaPenerima,
      kotaTujuan: current.kotaTujuan,
      jumlah: amount,
      berat: current.berat,
      quantity: current.quantity,
      catatan: current.catatan,
      totalDibayar: current.totalDibayar,
    );
  }

  test('database initializes and starts empty', () async {
    expect(await db.getAllPelanggan(), isEmpty);
  });

  test('payment equal to outstanding is accepted and closes transaction', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);

    await payment(tid, 100000);

    final t = await db.getTransaksiById(tid);
    expect(t, isNotNull);
    expect(t!.totalDibayar, 100000);
    expect(t.sisa, 0);
    expect(t.lunas, isTrue);
  });

  test('overpayment is rejected', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);

    await expectLater(
      payment(tid, 100001, method: 'transfer'),
      throwsA(isA<ValidasiException>()),
    );

    expect(await db.getPembayaranByTransaksi(tid), isEmpty);
  });

  test('fully paid transaction cannot receive another payment', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);
    await payment(tid, 100000);

    await expectLater(
      payment(tid, 1),
      throwsA(isA<ValidasiException>()),
    );

    final history = await db.getPembayaranByTransaksi(tid);
    expect(history, hasLength(1));
    expect(history.single.jumlah, 100000);
  });

  test('invalid payment method is rejected without creating payment', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);

    await expectLater(
      payment(tid, 10000, method: 'qris'),
      throwsA(isA<ValidasiException>()),
    );

    expect(await db.getPembayaranByTransaksi(tid), isEmpty);
  });

  test('edit transaction below actual paid total is rejected', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);
    await payment(tid, 60000);

    await expectLater(
      db.updateTransaksi(await updatedTransaction(tid, cid, 59999)),
      throwsA(isA<ValidasiException>()),
    );

    final current = (await db.getTransaksiById(tid))!;
    expect(current.jumlah, 100000);
    expect(current.totalDibayar, 60000);
    expect(current.sisa, 40000);
  });

  test('edit transaction equal to actual paid total is accepted and closes transaction', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);
    await payment(tid, 60000);

    await db.updateTransaksi(await updatedTransaction(tid, cid, 60000));

    final current = (await db.getTransaksiById(tid))!;
    expect(current.jumlah, 60000);
    expect(current.totalDibayar, 60000);
    expect(current.sisa, 0);
    expect(current.lunas, isTrue);
  });

  test('edit transaction above actual paid total preserves payment history', () async {
    final cid = await customer();
    final tid = await transaction(cid, amount: 100000);
    await payment(tid, 40000);

    await db.updateTransaksi(await updatedTransaction(tid, cid, 120000));

    final current = (await db.getTransaksiById(tid))!;
    expect(current.jumlah, 120000);
    expect(current.totalDibayar, 40000);
    expect(current.sisa, 80000);

    final history = await db.getPembayaranByTransaksi(tid);
    expect(history, hasLength(1));
    expect(history.single.jumlah, 40000);
    expect(history.single.metode, 'cash');
  });

  test('edit transaction cannot move it to another customer', () async {
    final cid1 = await customer('Pelanggan Satu');
    final cid2 = await customer('Pelanggan Dua');
    final tid = await transaction(cid1);

    await expectLater(
      db.updateTransaksi(await updatedTransaction(tid, cid2, 100000)),
      throwsA(isA<ValidasiException>()),
    );

    final current = (await db.getTransaksiById(tid))!;
    expect(current.pelangganId, cid1);
  });

  test('insert transaction with nonexistent customer is rejected', () async {
    await expectLater(
      transaction(999999),
      throwsA(isA<ValidasiException>()),
    );
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
    await payment(tid, 10000);

    await db.deletePelanggan(cid);

    expect(await db.getTransaksiById(tid), isNull);
    expect(await db.getPembayaranByTransaksi(tid), isEmpty);
  });

  test('aging places outstanding balance in correct bucket', () async {
    final cid = await customer();
    await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: cid,
        tanggal: DateTime(2026, 8, 10), // 21 days old
        nomorResi: 'A',
        namaPenerima: 'A',
        kotaTujuan: 'Jakarta',
        jumlah: 10000,
      ),
    );
    await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: cid,
        tanggal: DateTime(2026, 7, 20), // 42 days old
        nomorResi: 'B',
        namaPenerima: 'B',
        kotaTujuan: 'Jakarta',
        jumlah: 20000,
      ),
    );
    await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: cid,
        tanggal: DateTime(2026, 6, 15), // 77 days old
        nomorResi: 'C',
        namaPenerima: 'C',
        kotaTujuan: 'Jakarta',
        jumlah: 30000,
      ),
    );
    await db.insertTransaksi(
      TransaksiKredit(
        pelangganId: cid,
        tanggal: DateTime(2026, 1, 1), // 242 days old
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


  test('bulk import preflight detects duplicate resi before import', () async {
    final cid = await customer();
    await transaction(cid, resi: 'PRE-1');

    final errors = await db.validateImportRows([
      ImportTransaksiRow(
        namaPelanggan: 'Pelanggan Test',
        tanggal: DateTime(2026, 9, 10),
        nomorResi: 'PRE-1',
        namaPenerima: 'Penerima',
        kotaTujuan: 'Malang',
        quantity: 1,
        berat: 1,
        jumlah: 10000,
      ),
      ImportTransaksiRow(
        namaPelanggan: 'Pelanggan Baru',
        tanggal: DateTime(2026, 9, 11),
        nomorResi: 'PRE-2',
        namaPenerima: 'Penerima',
        kotaTujuan: 'Malang',
        quantity: 1,
        berat: 1,
        jumlah: 10000,
      ),
      ImportTransaksiRow(
        namaPelanggan: 'Pelanggan Baru',
        tanggal: DateTime(2026, 9, 12),
        nomorResi: 'PRE-2',
        namaPenerima: 'Penerima',
        kotaTujuan: 'Malang',
        quantity: 1,
        berat: 1,
        jumlah: 10000,
      ),
    ]);

    expect(errors, hasLength(2));
    expect(errors.any((e) => e.contains('PRE-1') && e.contains('database')), isTrue);
    expect(errors.any((e) => e.contains('PRE-2') && e.contains('duplikat')), isTrue);
  });

  test('bulk import creates missing customers and imports atomically', () async {
    final count = await db.importTransaksiBatch([
      ImportTransaksiRow(namaPelanggan: 'Import Satu', tanggal: DateTime(2026, 9, 1), nomorResi: 'IMP-1', namaPenerima: 'Penerima 1', kotaTujuan: 'Malang', quantity: 2, berat: 1.5, jumlah: 25000),
      ImportTransaksiRow(namaPelanggan: 'Import Dua', tanggal: DateTime(2026, 9, 2), nomorResi: 'IMP-2', namaPenerima: 'Penerima 2', kotaTujuan: 'Surabaya', quantity: 1, berat: 2, jumlah: 30000),
    ]);
    expect(count, 2);
    expect(await db.getAllPelanggan(), hasLength(2));
    expect((await db.getTransaksiByPelanggan(1)), hasLength(1));
    expect((await db.getTransaksiByPelanggan(2)), hasLength(1));

    await expectLater(
      db.importTransaksiBatch([
        ImportTransaksiRow(namaPelanggan: 'Import Tiga', tanggal: DateTime(2026, 9, 3), nomorResi: 'IMP-3', namaPenerima: 'Penerima 3', kotaTujuan: 'Jakarta', quantity: 1, berat: 1, jumlah: 10000),
        ImportTransaksiRow(namaPelanggan: 'Import Empat', tanggal: DateTime(2026, 9, 4), nomorResi: 'IMP-1', namaPenerima: 'Penerima 4', kotaTujuan: 'Jakarta', quantity: 1, berat: 1, jumlah: 10000),
      ]),
      throwsA(isA<ValidasiException>()),
    );
    expect((await db.getTransaksiByPelanggan(1)), hasLength(1));
    expect(await db.getAllPelanggan(), hasLength(2));
  });
}
