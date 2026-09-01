import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pembayaran.dart';
import '../models/transaksi_kredit.dart';
import '../providers/piutang_provider.dart';
import '../utils/formatter.dart';

class PaymentDialog extends StatefulWidget {
  final TransaksiKredit transaksi;
  final VoidCallback? onSaved;
  const PaymentDialog({super.key, required this.transaksi, this.onSaved});

  static Future<void> show(BuildContext context, TransaksiKredit transaksi, {VoidCallback? onSaved}) =>
      showDialog<void>(context: context, builder: (_) => PaymentDialog(transaksi: transaksi, onSaved: onSaved));

  @override State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _jumlah = TextEditingController();
  final _keterangan = TextEditingController();
  String _metode = 'cash';
  bool _saving = false;

  String _cleanError(Object e) => e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  @override void dispose() { _jumlah.dispose(); _keterangan.dispose(); super.dispose(); }

  Future<void> _save() async {
    final value = int.tryParse(_jumlah.text.replaceAll('.', '').replaceAll(',', '').trim());
    if (value == null || value <= 0 || value > widget.transaksi.sisa) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah pembayaran tidak valid.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<PiutangProvider>().tambahPembayaran(Pembayaran(
        transaksiId: widget.transaksi.id!, tanggal: DateTime.now(), jumlah: value,
        metode: _metode,
        keterangan: _keterangan.text.trim().isEmpty ? null : _keterangan.text.trim(),
      ));
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanError(e))));
    }
  }

  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Pembayaran ${widget.transaksi.nomorResi}', maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(color: scheme.surfaceContainerHighest, child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sisa tagihan'), Text(Formatter.rupiah(widget.transaksi.sisa), style: const TextStyle(fontWeight: FontWeight.bold))]))),
        const SizedBox(height: 12),
        TextField(controller: _jumlah, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah pembayaran', prefixText: 'Rp ', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        const Text('Metode pembayaran', style: TextStyle(fontWeight: FontWeight.w600)),
        RadioGroup<String>(
          groupValue: _metode,
          onChanged: (String? value) {
            if (_saving || value == null) return;
            setState(() => _metode = value);
          },
          child: const Column(children: [
            RadioListTile<String>(dense: true, contentPadding: EdgeInsets.zero, value: 'cash', title: Text('Cash'), secondary: Icon(Icons.payments_outlined)),
            RadioListTile<String>(dense: true, contentPadding: EdgeInsets.zero, value: 'transfer', title: Text('Transfer'), secondary: Icon(Icons.account_balance_outlined)),
          ]),
        ),
        TextField(controller: _keterangan, maxLines: 2, decoration: const InputDecoration(labelText: 'Keterangan (opsional)', border: OutlineInputBorder())),
      ])),
      actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Batal')), FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.check), label: Text(_saving ? 'Menyimpan...' : 'Simpan'))],
    );
  }
}