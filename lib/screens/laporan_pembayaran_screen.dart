import 'package:flutter/material.dart';
import '../models/pelanggan.dart';
import '../services/db_helper.dart';
import '../services/payment_report_service.dart';
import '../utils/formatter.dart';

class LaporanPembayaranScreen extends StatefulWidget {
  const LaporanPembayaranScreen({super.key});

  @override
  State<LaporanPembayaranScreen> createState() => _LaporanPembayaranScreenState();
}

class _LaporanPembayaranScreenState extends State<LaporanPembayaranScreen> {
  DateTime dari = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime sampai = DateTime.now();
  List<Pelanggan> customers = <Pelanggan>[];
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  String customer = 'Semua pelanggan';
  String method = 'Semua metode';
  bool loading = true;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (dari.isAfter(sampai)) {
      _error('Tanggal mulai tidak boleh lebih besar dari tanggal akhir.');
      return;
    }
    setState(() => loading = true);
    try {
      final result = await DbHelper.instance.getPembayaranPeriode(dari: dari, sampai: sampai);
      final list = await DbHelper.instance.getAllPelanggan();
      if (!mounted) return;
      setState(() {
        rows = result;
        customers = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _error(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    }
  }

  List<Map<String, dynamic>> get filteredRows => rows.where((row) {
    final customerOk = customer == 'Semua pelanggan' || '${row['nama_pelanggan'] ?? ''}' == customer;
    final rowMethod = '${row['metode'] ?? ''}';
    final methodOk = method == 'Semua metode' || rowMethod == method;
    return customerOk && methodOk;
  }).toList(growable: false);

  int get total => filteredRows.fold<int>(0, (sum, row) => sum + ((row['jumlah'] as num?)?.toInt() ?? 0));
  int get cashTotal => filteredRows.where((r) => '${r['metode'] ?? ''}' == 'cash').fold<int>(0, (s, r) => s + ((r['jumlah'] as num?)?.toInt() ?? 0));
  int get transferTotal => filteredRows.where((r) => '${r['metode'] ?? ''}' == 'transfer').fold<int>(0, (s, r) => s + ((r['jumlah'] as num?)?.toInt() ?? 0));

  Future<void> _pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? dari : sampai,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() => start ? dari = selected : sampai = selected);
    await _load();
  }

  Future<void> _export(bool pdf) async {
    if (exporting || filteredRows.isEmpty) return;
    setState(() => exporting = true);
    try {
      if (pdf) {
        await PaymentReportService.exportPdf(rows: filteredRows, dari: dari, sampai: sampai, customer: customer, method: _methodLabel(method));
      } else {
        await PaymentReportService.exportExcel(rows: filteredRows, dari: dari, sampai: sampai, customer: customer, method: _methodLabel(method));
      }
    } catch (e) {
      if (mounted) _error('Gagal mengekspor laporan: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  String _methodLabel(String value) {
    switch (value) {
      case 'cash': return 'Cash';
      case 'transfer': return 'Transfer';
      default: return value;
    }
  }

  String _displayMethod(dynamic value) {
    switch ('$value') {
      case 'cash': return 'Cash';
      case 'transfer': return 'Transfer';
      case '': return 'Tidak dicatat';
      default: return '$value';
    }
  }

  void _error(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = filteredRows;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: exporting || data.isEmpty ? null : () => _export(true), tooltip: 'Export PDF', icon: const Icon(Icons.picture_as_pdf)),
          IconButton(onPressed: exporting || data.isEmpty ? null : () => _export(false), tooltip: 'Export Excel', icon: const Icon(Icons.table_view)),
          IconButton(onPressed: exporting ? null : _load, tooltip: 'Muat ulang', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: _dateTile('Dari', dari, () => _pick(true))),
                        const SizedBox(width: 10),
                        Expanded(child: _dateTile('Sampai', sampai, () => _pick(false))),
                      ]),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: customer,
                        decoration: const InputDecoration(labelText: 'Pelanggan', prefixIcon: Icon(Icons.person_outline)),
                        items: [
                          const DropdownMenuItem(value: 'Semua pelanggan', child: Text('Semua pelanggan')),
                          ...customers.map((p) => DropdownMenuItem(value: p.nama, child: Text(p.nama, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => customer = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: const InputDecoration(labelText: 'Metode pembayaran', prefixIcon: Icon(Icons.payments_outlined)),
                        items: const [
                          DropdownMenuItem(value: 'Semua metode', child: Text('Semua metode')),
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => method = value);
                        },
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _summaryCard('Total pembayaran', total, Icons.account_balance_wallet_outlined, scheme.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: _summaryCard('Jumlah transaksi', data.length, Icons.receipt_long_outlined, scheme.secondary)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _summaryCard('Cash', cashTotal, Icons.money_outlined, scheme.tertiary)),
                  const SizedBox(width: 10),
                  Expanded(child: _summaryCard('Transfer', transferTotal, Icons.account_balance_outlined, scheme.primary)),
                ]),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Daftar pembayaran', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text('${data.length} pembayaran', style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 10),
                if (data.isEmpty)
                  Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20), child: Column(children: [
                    Icon(Icons.payments_outlined, size: 48, color: scheme.primary),
                    const SizedBox(height: 12),
                    const Text('Belum ada pembayaran pada filter ini.', textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    const Text('Ubah periode, pelanggan, atau metode pembayaran.', textAlign: TextAlign.center),
                  ])))
                else
                  ...data.map((row) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
                      leading: CircleAvatar(child: Text('${data.indexOf(row) + 1}')),
                      title: Text(Formatter.rupiah((row['jumlah'] as num?)?.toInt() ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text('${Formatter.tanggalPanjang(DateTime.parse('${row['tanggal']}'))} • ${row['nama_pelanggan'] ?? ''}\n${_displayMethod(row['metode'])}${'${row['keterangan'] ?? ''}'.trim().isEmpty ? '' : ' • ${'${row['keterangan']}'.trim()}'}', maxLines: 3, overflow: TextOverflow.ellipsis)),
                    ),
                  )),
              ],
            ),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) => Expanded(child: InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_month_outlined)),
      child: Text(Formatter.tanggalPendek(date)),
    ),
  ));

  Widget _summaryCard(String label, int value, IconData icon, Color color) => Expanded(child: Card(child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 21, color: color),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
      const SizedBox(height: 3),
      Text(label == 'Jumlah transaksi' ? '$value' : Formatter.rupiah(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    ]),
  )));
}
