import '../models/pelanggan.dart';
import 'db_helper.dart';

class TransactionSearchService {
  TransactionSearchService._();

  static Future<Set<int>> findCustomerIdsByResi(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return <int>{};

    final rows = await (await DbHelper.instance.database).query(
      'transaksi_kredit',
      columns: const ['pelanggan_id'],
      where: 'nomor_resi LIKE ?',
      whereArgs: ['%$normalized%'],
      distinct: true,
    );

    return rows
        .map((row) => row['pelanggan_id'])
        .whereType<int>()
        .toSet();
  }
}
