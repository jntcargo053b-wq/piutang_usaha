import 'package:flutter/material.dart';
import '../models/transaksi_kredit.dart';
import '../services/payment_service.dart';
import '../utils/formatter.dart';

class CustomerPaymentSheet extends StatefulWidget {
  final List<TransaksiKredit> transactions;
  final Future<void> Function()? onSaved;

  const CustomerPaymentSheet({
    super.key,
    required this.transactions,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context,
    List<TransaksiKredit> transactions, {
    Future<void> Function()? onSaved,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomerPaymentSheet(
        transactions: transactions,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<CustomerPaymentSheet> createState() => _CustomerPaymentSheetState();
}

class _CustomerPaymentSheetState extends State<CustomerPaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _service = PaymentService();
  String _method = PaymentService.cash;
  bool _saving = false;

  List<TransaksiKredit> get _outstanding =>
      widget.transactions.where((t) => t.id != null && t.sisa > 0).toList();

  int get _totalOutstanding =>
      _outstanding.fold<int>(0, (sum, t) => sum + t.sisa);

  String _cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(
      _amount.text.replaceAll('.', '').replaceAll(',', '').trim(),
    );
    if (amount == null || amount <= 0) {
      _error('Masukkan jumlah pembayaran yang valid.');
      return;
    }
    if (amount > _totalOutstanding) {
      _error('Pembayaran melebihi total sisa piutang.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.payCustomer(
        transactions: _outstanding,
        amount: amount,
        method: _method,
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onSaved?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _error(_cleanError(error));
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabled = _saving || _outstanding.isEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bayar Piutang Pelanggan',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total sisa piutang'),
                      Text(
                        Formatter.rupiah(_totalOutstanding),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_outstanding.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tidak ada transaksi yang masih memiliki tagihan.'),
                )
              else ...[
                Text(
                  'Pembayaran akan dialokasikan dari transaksi paling awal.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                ..._outstanding.map(
                  (t) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(
                      t.nomorResi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(Formatter.rupiah(t.sisa)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  enabled: !disabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah pembayaran',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: _method,
                  onChanged: disabled
                      ? (_) {}
                      : (String? value) {
                          if (value != null) setState(() => _method = value);
                        },
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: PaymentService.cash,
                        title: Text('Cash'),
                        secondary: Icon(Icons.payments_outlined),
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: PaymentService.transfer,
                        title: Text('Transfer'),
                        secondary: Icon(Icons.account_balance_outlined),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _note,
                  enabled: !disabled,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: disabled ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Pembayaran'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
