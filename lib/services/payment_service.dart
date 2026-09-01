import '../models/pembayaran.dart';
import '../models/transaksi_kredit.dart';
import 'db_helper.dart';

/// Business rules for customer debt payments.
///
/// Payments are always stored against a transaction so the remaining balance
/// of every invoice/receipt stays auditable. A customer-level payment is
/// allocated to outstanding transactions in their existing order.
class PaymentService {
  PaymentService({DbHelper? db}) : _db = db ?? DbHelper.instance;

  final DbHelper _db;

  static const cash = 'cash';
  static const transfer = 'transfer';

  void _validateMethod(String method) {
    if (method != cash && method != transfer) {
      throw ArgumentError('Metode pembayaran harus Cash atau Transfer.');
    }
  }

  Future<void> payTransaction({
    required TransaksiKredit transaksi,
    required int amount,
    required String method,
    String? note,
    DateTime? date,
  }) async {
    _validateMethod(method);
    if (transaksi.id == null) throw StateError('Transaksi tidak valid.');
    if (amount <= 0) throw ArgumentError('Jumlah pembayaran harus lebih dari 0.');
    if (amount > transaksi.sisa) {
      throw ArgumentError('Pembayaran melebihi sisa tagihan.');
    }

    await _db.insertPembayaran(Pembayaran(
      transaksiId: transaksi.id!,
      tanggal: date ?? DateTime.now(),
      jumlah: amount,
      metode: method,
      keterangan: note?.trim().isEmpty == true ? null : note?.trim(),
    ));
  }

  /// Allocates a customer-level payment from the oldest transaction in the
  /// list to the newest, without ever exceeding an individual balance.
  Future<int> payCustomer({
    required List<TransaksiKredit> transactions,
    required int amount,
    required String method,
    String? note,
    DateTime? date,
  }) async {
    _validateMethod(method);
    if (amount <= 0) throw ArgumentError('Jumlah pembayaran harus lebih dari 0.');

    var remaining = amount;
    var allocated = 0;
    final paymentDate = date ?? DateTime.now();

    for (final transaksi in transactions) {
      if (remaining == 0) break;
      if (transaksi.id == null || transaksi.sisa <= 0) continue;

      final portion = remaining < transaksi.sisa ? remaining : transaksi.sisa;
      await _db.insertPembayaran(Pembayaran(
        transaksiId: transaksi.id!,
        tanggal: paymentDate,
        jumlah: portion,
        metode: method,
        keterangan: note?.trim().isEmpty == true ? null : note?.trim(),
      ));
      remaining -= portion;
      allocated += portion;
    }

    if (allocated == 0) {
      throw StateError('Pelanggan tidak memiliki sisa tagihan.');
    }
    return allocated;
  }
}
