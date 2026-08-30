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
  Map<String, int>? summary;
  Map<String, int>? aging;
  Map<String, int>? monthly;
  List<Map<String, dynamic>> topCustomers = [];

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PiutangProvider>().muatPelanggan();
    });
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
        summary = results[0] as Map<String, int>;
        aging = results[1] as Map<String, int>;
        monthly = results[2] as Map<String, int>;
        topCustomers = List<Map<String, dynamic>>.from(results[3] as List);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat dashboard: $e')),
      );
    }
  }

  Future<void> _backup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<PiutangProvider>().backupDatabase();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _open(Widget page) async {
    final navigator = Navigator.of(context);
    await navigator.push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    await context.read<PiutangProvider>().muatPelanggan();
  }

  @override
  Widget build(BuildContext context) {
    final s = summary ?? const <String, int>{};
    final a = aging ?? const <String, int>{};
    final m = monthly ?? const <String, int>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Piutang Usaha'),
        actions: [IconButton(onPressed: _backup, icon: const Icon(Icons.backup))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _card('Total Kredit', s['total_kredit'] ?? 0, Icons.credit_score)),
                const SizedBox(width: 8),
                Expanded(child: _card('Total Dibayar', s['total_dibayar'] ?? 0, Icons.payments)),
              ],
            ),
            _card('Sisa Piutang', s['sisa_piutang'] ?? 0, Icons.account_balance_wallet),
            const SizedBox(height: 16),
            _sectionTitle('Bulan Ini'),
            Row(
              children: [
                Expanded(child: _smallCard('Kredit', m['kredit'] ?? 0)),
                const SizedBox(width: 8),
                Expanded(child: _smallCard('Pembayaran', m['pembayaran'] ?? 0)),
              ],
            ),
            const SizedBox(height: 16),
            _sectionTitle('Umur Piutang'),
            Card(
              child: Column(
                children: [
                  _agingTile('0–30 hari', a['0_30'] ?? 0),
                  _agingTile('31–60 hari', a['31_60'] ?? 0),
                  _agingTile('61–90 hari', a['61_90'] ?? 0),
                  _agingTile('>90 hari', a['91_plus'] ?? 0),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Pelanggan dengan Piutang Terbesar'),
            Card(
              child: topCustomers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada piutang.'),
                    )
                  : Column(
                      children: topCustomers.map((r) {
                        final nama = '${r['nama'] ?? ''}';
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(nama.isEmpty ? '?' : nama.substring(0, 1).toUpperCase()),
                          ),
                          title: Text(nama),
                          trailing: Text(
                            Formatter.rupiah((r['sisa_piutang'] as num?)?.toInt() ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Pelanggan'),
              subtitle: const Text('Kelola pelanggan dan transaksi'),
              onTap: () => _open(const PelangganScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Laporan'),
              onTap: () => _open(const LaporanScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );

  Widget _card(String title, int value, IconData icon) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: Text(Formatter.rupiah(value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );

  Widget _smallCard(String title, int value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [Text(title), const SizedBox(height: 5), Text(Formatter.rupiah(value), style: const TextStyle(fontWeight: FontWeight.bold))]),
        ),
      );

  Widget _agingTile(String title, int value) => ListTile(
        title: Text(title),
        trailing: Text(Formatter.rupiah(value), style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}
