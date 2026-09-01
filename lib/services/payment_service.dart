import '../models/pembayaran.dart';
import '../models/transaksi_kredit.dart';
import 'db_helper.dart';

/// Business rules for customer debt payments.
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
    if (amount > transaksi.sisa) throw ArgumentError('Pembayaran melebihi sisa tagihan.');

    await _db.insertPembayaran(Pembayaran(
      transaksiId: transaksi.id!,
      tanggal: date ?? DateTime.now(),
      jumlah: amount,
      metode: method,
      keterangan: note?.trim().isEmpty == true ? null : note?.trim(),
    ));
  }

  /// Allocates one customer payment atomically from oldest to newest.
  /// If any allocation fails, the entire payment is rolled back.
  Future<int> payCustomer({
    required List<TransaksiKredit> transactions,
    required int amount,
    required String method,
    String? note,
    DateTime? date,
  }) async {
    _validateMethod(method);
    if (amount <= 0) throw ArgumentError('Jumlah pembayaran harus lebih dari 0.');

    final outstanding = transactions.where((t) => t.id != null && t.sisa > 0).toList();
    final totalOutstanding = outstanding.fold<int>(0, (sum, t) => sum + t.sisa);
    if (totalOutstanding <= 0) throw StateError('Pelanggan tidak memiliki sisa tagihan.');
    if (amount > totalOutstanding) throw ArgumentError('Pembayaran melebihi total sisa piutang pelanggan.');

    final paymentDate = date ?? DateTime.now();
    final cleanNote = note?.trim();

    return (await _db.database).transaction((txn) async {
      var remaining = amount;
      var allocated = 0;

      for (final transaksi in outstanding) {
        if (remaining == 0) break;
        final portion = remaining < transaksi.sisa ? remaining : transaksi.sisa;
        await _db.insertPembayaranInTransaction(txn, Pembayaran(
          transaksiId: transaksi.id!,
          tanggal: paymentDate,
          jumlah: portion,
          metode: method,
          keterangan: cleanNote?.isEmpty == true ? null : cleanNote,
        ));
        remaining -= portion;
        allocated += portion;
      }

      if (remaining != 0 || allocated != amount) {
        throw StateError('Pembayaran tidak dapat dialokasikan sepenuhnya.');
      }
      return allocated;
    });
  }
}
