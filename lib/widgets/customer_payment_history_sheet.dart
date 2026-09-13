import 'package:flutter/material.dart';

import '../utils/formatter.dart';
import '../services/db_helper.dart';

class CustomerPaymentHistorySheet extends StatelessWidget {
  final int pelangganId;
  final String namaPelanggan;

  const CustomerPaymentHistorySheet({
    super.key,
    required this.pelangganId,
    required this.namaPelanggan,
  });

  static Future<void> show(
    BuildContext context, {
    required int pelangganId,
    required String namaPelanggan,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CustomerPaymentHistorySheet(
        pelangganId: pelangganId,
        namaPelanggan: namaPelanggan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: FutureBuilder<_HistoryData>(
            future: _load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Gagal memuat riwayat pembayaran pelanggan.'),
                );
              }

              final data = snapshot.data ?? const _HistoryData.empty();
              final remaining = (data.totalTagihan - data.totalDibayar).clamp(
                0,
                data.totalTagihan,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Riwayat Pembayaran',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    namaPelanggan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: 'Total Piutang',
                          value: Formatter.rupiah(data.totalTagihan),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Total Dibayar',
                          value: Formatter.rupiah(data.totalDibayar),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Sisa',
                          value: Formatter.rupiah(remaining),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.history_outlined),
                      const SizedBox(width: 8),
                      Text(
                        'Tanggal Transfer & Pembayaran',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: data.payments.isEmpty
                        ? const Center(child: Text('Belum ada pembayaran.'))
                        : ListView.separated(
                            itemCount: data.payments.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final payment = data.payments[index];
                              final method = _methodLabel(payment['metode']);
                              final note = '${payment['keterangan'] ?? ''}'.trim();
                              final resi = '${payment['nomor_resi'] ?? ''}'.trim();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  Formatter.rupiah(
                                    (payment['jumlah'] as num?)?.toInt() ?? 0,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${Formatter.tanggalPanjang(DateTime.tryParse('${payment['tanggal']}') ?? DateTime.now())} • $method'
                                  '${resi.isEmpty ? '' : '\nResi: $resi'}'
                                  '${note.isEmpty ? '' : '\n$note'}',
                                ),
                                isThreeLine: resi.isNotEmpty || note.isNotEmpty,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_HistoryData> _load() async {
    final db = await DbHelper.instance.database;
    final totals = await db.rawQuery(
      '''SELECT
          COALESCE((SELECT SUM(jumlah) FROM transaksi_kredit WHERE pelanggan_id = ?), 0) AS total_tagihan,
          COALESCE((SELECT SUM(p.jumlah)
                    FROM pembayaran p
                    JOIN transaksi_kredit t ON t.id = p.transaksi_id
                    WHERE t.pelanggan_id = ?), 0) AS total_dibayar''',
      [pelangganId, pelangganId],
    );
    final payments = await db.rawQuery(
      '''SELECT p.id, p.tanggal, p.jumlah, p.metode, p.keterangan,
                t.nomor_resi
         FROM pembayaran p
         JOIN transaksi_kredit t ON t.id = p.transaksi_id
         WHERE t.pelanggan_id = ?
         ORDER BY p.tanggal DESC, p.id DESC''',
      [pelangganId],
    );

    final row = totals.first;
    return _HistoryData(
      totalTagihan: (row['total_tagihan'] as num?)?.toInt() ?? 0,
      totalDibayar: (row['total_dibayar'] as num?)?.toInt() ?? 0,
      payments: payments,
    );
  }

  static String _methodLabel(Object? value) {
    switch ('$value'.trim().toLowerCase()) {
      case 'transfer':
        return 'Transfer';
      case 'cash':
        return 'Cash';
      default:
        return 'Metode tidak dicatat';
    }
  }
}

class _HistoryData {
  final int totalTagihan;
  final int totalDibayar;
  final List<Map<String, dynamic>> payments;

  const _HistoryData({
    required this.totalTagihan,
    required this.totalDibayar,
    required this.payments,
  });

  const _HistoryData.empty()
      : totalTagihan = 0,
        totalDibayar = 0,
        payments = const [];
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
