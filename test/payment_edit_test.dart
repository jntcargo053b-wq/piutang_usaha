import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/models/pelanggan.dart';
import 'package:piutang_usaha/models/pembayaran.dart';
import 'package:piutang_usaha/models/transaksi_kredit.dart';
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

  Future<(int, int, Pembayaran)> fixture({int transactionAmount = 100000, int paymentAmount = 40000}) async {
    final customerId = await db.insertPelanggan(Pelanggan(nama: 'Pelanggan Edit Pembayaran'));
    final transactionId = await db.insertTransaksi(TransaksiKredit(
      pelangganId: customerId,
      tanggal: DateTime(2026, 8, 1),
      nomorResi: 'EDIT-1',
      namaPenerima: 'Penerima',
      kotaTujuan: 'Jakarta',
      jumlah: transactionAmount,
    ));
    final paymentId = await db.insertPembayaran(Pembayaran(
      transaksiId: transactionId,
      tanggal: DateTime(2026, 8, 10),
      jumlah: paymentAmount,
      metode: 'cash',
      keterangan: 'Awal',
    ));
    final payment = (await db.getPembayaranByTransaksi(transactionId)).single;
    expect(payment.id, paymentId);
    return (customerId, transactionId, payment);
  }

  test('editing payment amount updates transaction balance and keeps identity', () async {
    final (_, transactionId, payment) = await fixture();

    await PaymentService(db: db).updatePayment(
      payment: payment,
      amount: 60000,
      method: PaymentService.transfer,
      note: 'Koreksi',
      date: DateTime(2026, 8, 12),
    );

    final updatedPayment = (await db.getPembayaranByTransaksi(transactionId)).single;
    final transaction = (await db.getTransaksiById(transactionId))!;
    expect(updatedPayment.id, payment.id);
    expect(updatedPayment.transaksiId, transactionId);
    expect(updatedPayment.jumlah, 60000);
    expect(updatedPayment.metode, 'transfer');
    expect(updatedPayment.keterangan, 'Koreksi');
    expect(updatedPayment.tanggal, DateTime(2026, 8, 12));
    expect(transaction.totalDibayar, 60000);
    expect(transaction.sisa, 40000);
  });

  test('editing payment cannot make total payments exceed transaction amount', () async {
    final (_, transactionId, payment) = await fixture(transactionAmount: 100000, paymentAmount: 40000);
    await db.insertPembayaran(Pembayaran(
      transaksiId: transactionId,
      tanggal: DateTime(2026, 8, 11),
      jumlah: 30000,
      metode: 'transfer',
    ));

    await expectLater(
      PaymentService(db: db).updatePayment(
        payment: payment,
        amount: 80000,
        method: PaymentService.cash,
      ),
      throwsA(isA<ArgumentError>()),
    );

    final history = await db.getPembayaranByTransaksi(transactionId);
    expect(history.first.jumlah, 40000);
    expect(history.last.jumlah, 30000);
  });

  test('editing payment rejects invalid method without changing data', () async {
    final (_, transactionId, payment) = await fixture();

    await expectLater(
      PaymentService(db: db).updatePayment(
        payment: payment,
        amount: 50000,
        method: 'qris',
      ),
      throwsA(isA<ArgumentError>()),
    );

    final updated = (await db.getPembayaranByTransaksi(transactionId)).single;
    expect(updated.jumlah, 40000);
    expect(updated.metode, 'cash');
  });

  test('editing a fully paid payment downward reopens outstanding balance', () async {
    final (_, transactionId, payment) = await fixture(paymentAmount: 100000);

    await PaymentService(db: db).updatePayment(
      payment: payment,
      amount: 70000,
      method: PaymentService.cash,
    );

    final transaction = (await db.getTransaksiById(transactionId))!;
    expect(transaction.totalDibayar, 70000);
    expect(transaction.sisa, 30000);
    expect(transaction.lunas, isFalse);
  });
}
