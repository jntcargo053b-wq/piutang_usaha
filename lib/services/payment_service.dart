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

    await _db.insertPembayaran(Pembayaran(
      transaksiId: transaksi.id!,
      tanggal: date ?? DateTime.now(),
      jumlah: amount,
      metode: method,
      keterangan: note?.trim().isEmpty == true ? null : note?.trim(),
    ));
  }

  Future<void> updatePayment({
    required Pembayaran payment,
    required int amount,
    required String method,
    String? note,
    DateTime? date,
  }) async {
    if (payment.id == null) throw StateError('Pembayaran tidak valid.');
    if (payment.transaksiId <= 0) {
      throw StateError('Transaksi pembayaran tidak valid.');
    }
    _validateMethod(method);
    if (amount <= 0) {
      throw ArgumentError('Jumlah pembayaran harus lebih dari 0.');
    }

    await (await _db.database).transaction((txn) async {
      final existingRows = await txn.query(
        'pembayaran',
        columns: ['id', 'transaksi_id', 'tanggal'],
        where: 'id = ?',
        whereArgs: [payment.id],
        limit: 1,
      );
      if (existingRows.isEmpty) throw StateError('Pembayaran tidak ditemukan.');
      final storedTransactionId =
          (existingRows.first['transaksi_id'] as num).toInt();
      if (storedTransactionId != payment.transaksiId) {
        throw StateError('Transaksi pembayaran tidak sesuai.');
      }

      final transactionRows = await txn.rawQuery(
        'SELECT t.*, COALESCE(SUM(p.jumlah), 0) AS total_dibayar '
        'FROM transaksi_kredit t '
        'LEFT JOIN pembayaran p ON p.transaksi_id = t.id '
        'WHERE t.id = ? GROUP BY t.id',
        [storedTransactionId],
      );
      if (transactionRows.isEmpty) {
        throw StateError('Transaksi tidak ditemukan.');
      }
      final transaction = TransaksiKredit.fromMap(transactionRows.first);

      final otherRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(jumlah), 0) AS total '
        'FROM pembayaran WHERE transaksi_id = ? AND id != ?',
        [storedTransactionId, payment.id],
      );
      final otherTotal = (otherRows.first['total'] as num?)?.toInt() ?? 0;
      if (otherTotal + amount > transaction.jumlah) {
        throw ArgumentError('Jumlah pembayaran melebihi total tagihan.');
      }

      final storedDate = DateTime.parse(
        existingRows.first['tanggal'] as String,
      );
      await txn.update(
        'pembayaran',
        {
          'tanggal': (date ?? storedDate).toIso8601String(),
          'jumlah': amount,
          'metode': method,
          'keterangan': note?.trim().isEmpty == true ? null : note?.trim(),
        },
        where: 'id = ?',
        whereArgs: [payment.id],
      );
    });
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

    final paymentDate = date ?? DateTime.now();
    final cleanNote = note?.trim();

    return (await _db.database).transaction((txn) async {
      // Reload balances inside the same transaction. The list supplied by the
      // UI may be stale after another payment/edit/delete has changed the DB.
      final ids = transactions
          .map((t) => t.id)
          .whereType<int>()
          .toSet()
          .toList(growable: false);
      final current = <TransaksiKredit>[];
      for (final id in ids) {
        final transaksi = await _db.getTransaksiByIdInTransaction(txn, id);
        if (transaksi == null) {
          throw ValidasiException('Transaksi pembayaran tidak ditemukan.');
        }
        if (transaksi.sisa > 0) current.add(transaksi);
      }
      current.sort((a, b) {
        final byDate = a.tanggal.compareTo(b.tanggal);
        return byDate != 0 ? byDate : a.id!.compareTo(b.id!);
      });

      var remaining = amount;
      var allocated = 0;

      for (final transaksi in current) {
        if (remaining == 0) break;
        final portion = remaining < transaksi.sisa ? remaining : transaksi.sisa;
        await _db.insertPembayaranInTransaction(
          txn,
          Pembayaran(
            transaksiId: transaksi.id!,
            tanggal: paymentDate,
            jumlah: portion,
            metode: method,
            keterangan: cleanNote?.isEmpty == true ? null : cleanNote,
          ),
        );
        remaining -= portion;
        allocated += portion;
      }

      if (remaining != 0 || allocated != amount) {
        throw ArgumentError('Pembayaran melebihi total sisa piutang pelanggan.');
      }
      return allocated;
    });
  }
}
