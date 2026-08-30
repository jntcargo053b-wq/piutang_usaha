import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/piutang_provider.dart';
import '../utils/formatter.dart';
import 'pelanggan_screen.dart';
import 'laporan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int>? summary, aging, monthly;
  List<Map<String, dynamic>> topCustomers = [];

  @override
  void initState() { super.initState(); _load(); WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return; context.read<PiutangProvider>().muatPelanggan(); }); }

  Future<void> _load() async {
    final p = context.read<PiutangProvider>();
    try {
      final r = await Future.wait<dynamic>([p.ringkasanTotal(), p.agingPiutang(), p.dashboardBulan(), p.topPiutangPelanggan()]);
      if (!mounted) return;
      setState(() { summary = r[0] as Map<String, int>; aging = r[1] as Map<String, int>; monthly = r[2] as Map<String, int>; topCustomers = List<Map<String, dynamic>>.from(r[3] as List); });
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat dashboard: $e'))); }
  }

  Future<void> _backup() async { try { await context.read<PiutangProvider>().backupDatabase(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }
  Future<void> _open(Widget page) async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)); if (!mounted) return; await _load(); await context.read<PiutangProvider>().muatPelanggan(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); final s = summary ?? {}; final a = aging ?? {}; final m = monthly ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Piutang Usaha', style: TextStyle(fontWeight: FontWeight.w700)), actions: [IconButton(onPressed: _backup, tooltip: 'Backup', icon: const Icon(Icons.cloud_upload_outlined))]),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), physics: const AlwaysScrollableScrollPhysics(), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total Piutang', style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: .78), fontSize: 14)), const SizedBox(height: 6),
          Text(Formatter.rupiah(s['sisa_piutang'] ?? 0), style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 28, fontWeight: FontWeight.w800)), const SizedBox(height: 18),
          Row(children: [Expanded(child: _heroStat('Kredit', s['total_kredit'] ?? 0)), Expanded(child: _heroStat('Dibayar', s['total_dibayar'] ?? 0))]),
        ])),
        const SizedBox(height: 18),
        _title('Ringkasan Bulan Ini'), Row(children: [Expanded(child: _metricCard(Icons.trending_up, 'Kredit', m['kredit'] ?? 0)), const SizedBox(width: 10), Expanded(child: _metricCard(Icons.payments_outlined, 'Pembayaran', m['pembayaran'] ?? 0))]),
        const SizedBox(height: 18), _title('Umur Piutang'),
        Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [_aging('0–30 hari', a['0_30'] ?? 0, .18), _aging('31–60 hari', a['31_60'] ?? 0, .38), _aging('61–90 hari', a['61_90'] ?? 0, .62), _aging('>90 hari', a['91_plus'] ?? 0, .86)]))),
        const SizedBox(height: 18), _title('Piutang Terbesar'),
        Card(child: topCustomers.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Text('Belum ada piutang.')) : Column(children: topCustomers.take(5).map((r) { final n='${r['nama']??''}'; final v=(r['sisa_piutang'] as num?)?.toInt()??0; return ListTile(leading: CircleAvatar(child: Text(n.isEmpty?'?':n[0].toUpperCase())), title: Text(n, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: Text(Formatter.rupiah(v), style: const TextStyle(fontWeight: FontWeight.w700)); }).toList())),
        const SizedBox(height: 18), _title('Menu'),
        _menu(Icons.people_alt_outlined, 'Pelanggan', 'Kelola pelanggan dan transaksi', () => _open(const PelangganScreen())),
        _menu(Icons.receipt_long_outlined, 'Laporan', 'Lihat dan bagikan laporan', () => _open(const LaporanScreen())),
      ])),
    );
  }

  Widget _title(String t) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w750)));
  Widget _heroStat(String t, int v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 3), Text(Formatter.rupiah(v), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]);
  Widget _metricCard(IconData i, String t, int v) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [Icon(i, size: 25), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 13)), const SizedBox(height: 4), Text(Formatter.rupiah(v), style: const TextStyle(fontWeight: FontWeight.w700))]))])));
  Widget _aging(String t, int v, double opacity) => ListTile(dense: true, title: Text(t), trailing: Text(Formatter.rupiah(v), style: const TextStyle(fontWeight: FontWeight.w700)), leading: CircleAvatar(radius: 5, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: opacity)));
  Widget _menu(IconData i, String t, String sub, VoidCallback onTap) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: CircleAvatar(child: Icon(i)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.w650)), subtitle: Text(sub), trailing: const Icon(Icons.chevron_right), onTap: onTap));
}
