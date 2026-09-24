import 'package:flutter/material.dart';

import '../models/pembayaran.dart';
import '../models/transaksi_kredit.dart';
import '../services/payment_service.dart';
import '../services/db_helper.dart';
import '../utils/formatter.dart';
import '../utils/error_message.dart';
import '../utils/rupiah_input_formatter.dart';

class PaymentHistorySheet extends StatefulWidget {
  final TransaksiKredit transaksi;
  const PaymentHistorySheet({super.key, required this.transaksi});

  static Future<bool?> show(BuildContext context, TransaksiKredit transaksi) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PaymentHistorySheet(transaksi: transaksi),
    );
  }

  @override
  State<PaymentHistorySheet> createState() => _PaymentHistorySheetState();
}

class _PaymentHistorySheetState extends State<PaymentHistorySheet> {
  late Future<List<Pembayaran>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _paymentsFuture = DbHelper.instance.getPembayaranByTransaksi(widget.transaksi.id!);
  }

  Future<void> _editPayment(Pembayaran payment) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EditPaymentDialog(payment: payment),
    );
    if (result == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _deletePayment(Pembayaran payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Pembayaran?'),
        content: Text('Pembayaran ${Formatter.rupiah(payment.jumlah)} akan dihapus. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await DbHelper.instance.deletePembayaran(payment.id!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: FutureBuilder<List<Pembayaran>>(
          future: _paymentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return const SizedBox(
                height: 220,
                child: Center(child: Text('Gagal memuat rincian pembayaran.')),
              );
            }

            final payments = snapshot.data ?? <Pembayaran>[];
            final total = payments.fold<int>(0, (sum, item) => sum + item.jumlah);
            final remaining = (widget.transaksi.jumlah - total).clamp(0, widget.transaksi.jumlah);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Rincian Pembayaran', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Resi ${widget.transaksi.nomorResi}', maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _SummaryTile(label: 'Tagihan', value: Formatter.rupiah(widget.transaksi.jumlah))),
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
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editPayment(payment);
                              } else if (value == 'delete') {
                                await _deletePayment(payment);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit pembayaran')),
                              PopupMenuItem(value: 'delete', child: Text('Hapus pembayaran')),
                            ],
                          ),
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

class _EditPaymentDialog extends StatefulWidget {
  final Pembayaran payment;
  const _EditPaymentDialog({required this.payment});

  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;
  String? _method;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _formatAmount(widget.payment.jumlah));
    _noteController = TextEditingController(text: widget.payment.keterangan ?? '');
    _date = widget.payment.tanggal;
    final storedMethod = widget.payment.metode?.trim().toLowerCase();
    _method = storedMethod == PaymentService.transfer || storedMethod == PaymentService.cash ? storedMethod : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute, _date.second);
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) {
      _showError('Jumlah pembayaran harus lebih dari 0.');
      return;
    }

    if (_method == null) {
      _showError('Pilih metode pembayaran terlebih dahulu.');
      return;
    }

    setState(() => _saving = true);
    try {
      await PaymentService().updatePayment(
        payment: widget.payment,
        amount: amount,
        method: _method!,
        note: _noteController.text,
        date: _date,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError(friendlyError(e));
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatAmount(int amount) {
    final digits = amount.toString();
    final first = digits.length % 3;
    final buffer = StringBuffer();
    if (first != 0) buffer.write(digits.substring(0, first));
    for (var i = first; i < digits.length; i += 3) {
      if (buffer.length > 0) buffer.write('.');
      buffer.write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Pembayaran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: const [RupiahInputFormatter()],
              decoration: const InputDecoration(labelText: 'Jumlah pembayaran', prefixText: 'Rp '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Metode pembayaran'),
              items: const [
                DropdownMenuItem(value: PaymentService.cash, child: Text('Cash')),
                DropdownMenuItem(value: PaymentService.transfer, child: Text('Transfer')),
              ],
              onChanged: _saving ? null : (value) {
                if (value != null) setState(() => _method = value);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal pembayaran'),
              subtitle: Text(Formatter.tanggalPanjang(_date)),
              trailing: IconButton(icon: const Icon(Icons.calendar_month_outlined), onPressed: _saving ? null : _pickDate),
            ),
            TextField(
              controller: _noteController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Batal')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan')),
      ],
    );
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
