import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/piutang_provider.dart';
import '../utils/formatter.dart';
import 'pelanggan_screen.dart';
import 'laporan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int> summary = {};
  Map<String, int> aging = {};
  Map<String, int> monthly = {};
  List<Map<String, dynamic>> topCustomers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<PiutangProvider>();
    try {
      final results = await Future.wait<dynamic>([
        provider.ringkasanTotal(),
        provider.agingPiutang(),
        provider.dashboardBulan(),
        provider.topPiutangPelanggan(),
      ]);
      if (!mounted) return;
      setState(() {
        summary = Map<String, int>.from(results[0] as Map);
        aging = Map<String, int>.from(results[1] as Map);
        monthly = Map<String, int>.from(results[2] as Map);
        topCustomers = List<Map<String, dynamic>>.from(results[3] as List);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat dashboard: $e')));
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    await _load();
  }

  Future<void> _backup() async {
    try {
      await context.read<PiutangProvider>().backupDatabase();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piutang Usaha', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(onPressed: _backup, tooltip: 'Backup', icon: const Icon(Icons.backup_outlined))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 280),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(24)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('TOTAL PIUTANG', style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: .75), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .8)),
                      const SizedBox(height: 6),
                      Text(Formatter.rupiah(summary['sisa_piutang'] ?? 0), style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 20),
                      Row(children: [Expanded(child: _heroValue('Total Kredit', summary['total_kredit'] ?? 0)), Expanded(child: _heroValue('Total Dibayar', summary['total_dibayar'] ?? 0))]),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  _section('Ringkasan Bulan Ini'),
                  Row(children: [Expanded(child: _metric(Icons.add_chart, 'Kredit', monthly['kredit'] ?? 0)), const SizedBox(width: 10), Expanded(child: _metric(Icons.payments_outlined, 'Pembayaran', monthly['pembayaran'] ?? 0))]),
                  const SizedBox(height: 22),
                  _section('Umur Piutang'),
                  Card(child: Column(children: [_agingRow('0–30 hari', aging['0_30'] ?? 0), _agingRow('31–60 hari', aging['31_60'] ?? 0), _agingRow('61–90 hari', aging['61_90'] ?? 0), _agingRow('>90 hari', aging['91_plus'] ?? 0)])),
                  const SizedBox(height: 22),
                  _section('Piutang Terbesar'),
                  Card(child: topCustomers.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Text('Belum ada piutang.')) : Column(children: topCustomers.take(5).map((r) {
                    final name = '${r['nama'] ?? ''}';
                    final value = (r['sisa_piutang'] as num?)?.toInt() ?? 0;
                    return ListTile(leading: CircleAvatar(child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase())), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: Text(Formatter.rupiah(value), style: const TextStyle(fontWeight: FontWeight.w700)));
                  }).toList())),
                  const SizedBox(height: 22),
                  _section('Menu Utama'),
                  _menu(Icons.people_outline, 'Pelanggan', 'Kelola pelanggan dan transaksi', () => _open(const PelangganScreen())),
                  _menu(Icons.description_outlined, 'Laporan', 'Laporan transaksi dan pembayaran', () => _open(const LaporanScreen())),
                ],
              ),
      ),
    );
  }

  Widget _section(String text) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)));
  Widget _heroValue(String label, int value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4), Text(Formatter.rupiah(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]);
  Widget _metric(IconData icon, String label, int value) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [CircleAvatar(radius: 20, child: Icon(icon, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 13)), const SizedBox(height: 4), Text(Formatter.rupiah(value), style: const TextStyle(fontWeight: FontWeight.w700))]))])));
  Widget _agingRow(String label, int value) => ListTile(dense: true, title: Text(label), trailing: Text(Formatter.rupiah(value), style: const TextStyle(fontWeight: FontWeight.w700)));
  Widget _menu(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), leading: CircleAvatar(child: Icon(icon)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap));
}
