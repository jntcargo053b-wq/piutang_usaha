import 'package:flutter/material.dart';

import '../models/pembayaran.dart';
import '../models/transaksi_kredit.dart';
import '../services/db_helper.dart';
import '../utils/formatter.dart';

class PaymentHistorySheet extends StatelessWidget {
  final TransaksiKredit transaksi;
  const PaymentHistorySheet({super.key, required this.transaksi});

  static Future<void> show(BuildContext context, TransaksiKredit transaksi) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PaymentHistorySheet(transaksi: transaksi),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: FutureBuilder<List<Pembayaran>>(
          future: DbHelper.instance.getPembayaranByTransaksi(transaksi.id!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 220,
                child: Center(child: Text('Gagal memuat rincian pembayaran.')),
              );
            }

            final payments = snapshot.data ?? <Pembayaran>[];
            final total = payments.fold<int>(0, (sum, item) => sum + item.jumlah);
            final remaining = (transaksi.jumlah - total).clamp(0, transaksi.jumlah);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Rincian Pembayaran', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Resi ${transaksi.nomorResi}', maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _SummaryTile(label: 'Tagihan', value: Formatter.rupiah(transaksi.jumlah))),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryTile(label: 'Dibayar', value: Formatter.rupiah(total))),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryTile(label: 'Sisa', value: Formatter.rupiah(remaining))),
                  ],
                ),
                const SizedBox(height: 14),
                if (payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('Belum ada pembayaran.')),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: payments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(Formatter.rupiah(payment.jumlah), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${Formatter.tanggalPanjang(payment.tanggal)} • ${_methodLabel(payment.metode)}${payment.keterangan == null || payment.keterangan!.trim().isEmpty ? '' : '\n${payment.keterangan!.trim()}'}'),
                          isThreeLine: payment.keterangan != null && payment.keterangan!.trim().isNotEmpty,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _methodLabel(String? value) {
    switch (value) {
      case 'transfer':
        return 'Transfer';
      case 'cash':
        return 'Cash';
      case null:
      case '':
        return 'Metode tidak dicatat';
      default:
        return value;
    }
  }
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
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
