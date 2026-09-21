import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/piutang_provider.dart';
import '../utils/formatter.dart';
import 'pelanggan_screen.dart';
import 'laporan_screen.dart';
import 'backup_restore_screen.dart';
import 'import_transaksi_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int> summary = {}, aging = {}, monthly = {};
  List<Map<String, dynamic>> topCustomers = [];
  bool loading = true;
  int _navIndex = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final provider = context.read<PiutangProvider>();
    try {
      final results = await Future.wait<dynamic>([
        provider.ringkasanTotal(),
        provider.agingPiutang(),
        provider.dashboardBulan(),
        provider.topPiutangPelanggan(),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        summary = Map<String, int>.from(results[0] as Map);
        aging = Map<String, int>.from(results[1] as Map);
        monthly = Map<String, int>.from(results[2] as Map);
        topCustomers = List<Map<String, dynamic>>.from(results[3] as List);
        loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<void> _backup() async {
    await _open(const BackupRestoreScreen());
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Piutang Usaha', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Backup & Restore',
            onPressed: loading ? null : _backup,
            icon: const Icon(Icons.backup_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 280), Center(child: CircularProgressIndicator())],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  const Text('Halo, selamat datang! 👋', style: TextStyle(fontSize: 14, color: Color(0xFF667085))),
                  const SizedBox(height: 5),
                  const Text('Pantau piutang bisnis Anda', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  _totalCard(context),
                  const SizedBox(height: 24),
                  _sectionTitle('Akses Cepat'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.65,
                    children: [
                      _quickAction(context, Icons.people_alt_outlined, 'Pelanggan', 'Kelola pelanggan', () => _open(const PelangganScreen())),
                      _quickAction(context, Icons.receipt_long_outlined, 'Transaksi', 'Lihat transaksi', () => _open(const PelangganScreen())),
                      _quickAction(context, Icons.bar_chart_outlined, 'Laporan', 'Ringkasan bisnis', () => _open(const LaporanScreen())),
                      _quickAction(context, Icons.backup_outlined, 'Backup & Restore', 'Amankan / pulihkan data', _backup),
                      _quickAction(context, Icons.upload_file_outlined, 'Import Data', 'Excel / CSV transaksi', () => _open(const ImportTransaksiScreen())),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _sectionTitle('Ringkasan Bulan Ini'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _metric(context, Icons.add_chart_rounded, 'Kredit', monthly['kredit'] ?? 0)),
                    const SizedBox(width: 12),
                    Expanded(child: _metric(context, Icons.payments_outlined, 'Pembayaran', monthly['pembayaran'] ?? 0)),
                  ]),
                  const SizedBox(height: 26),
                  _sectionTitle('Umur Piutang'),
                  const SizedBox(height: 12),
                  Card(child: Column(children: [
                    _agingRow('0–30 hari', aging['0_30'] ?? 0),
                    _agingRow('31–60 hari', aging['31_60'] ?? 0),
                    _agingRow('61–90 hari', aging['61_90'] ?? 0),
                    _agingRow('>90 hari', aging['91_plus'] ?? 0),
                  ])),
                  const SizedBox(height: 26),
                  _sectionTitle('Piutang Terbesar'),
                  const SizedBox(height: 12),
                  Card(
                    child: topCustomers.isEmpty
                        ? const Padding(padding: EdgeInsets.all(18), child: Text('Belum ada piutang.'))
                        : Column(children: topCustomers.take(5).map((r) {
                            final name = '${r['nama'] ?? ''}';
                            final value = (r['sisa_piutang'] as num?)?.toInt() ?? 0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase()),
                              ),
                              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: const Text('Sisa piutang'),
                              trailing: Text(Formatter.rupiah(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.error)),
                            );
                          }).toList()),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) {
          setState(() => _navIndex = index);
          if (index == 1) _open(const PelangganScreen());
          if (index == 2) _open(const LaporanScreen());
          if (index == 0) _load();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Pelanggan'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Laporan'),
        ],
      ),
    );
  }

  Widget _totalCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, Color.lerp(scheme.primary, const Color(0xFF42A5F5), .55)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TOTAL PIUTANG', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(Formatter.rupiah(summary['sisa_piutang'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: _heroValue('Total Kredit', summary['total_kredit'] ?? 0)), const SizedBox(width: 16), Expanded(child: _heroValue('Total Dibayar', summary['total_dibayar'] ?? 0))]),
      ]),
    );
  }

  Widget _heroValue(String label, int value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 11)),
    const SizedBox(height: 3),
    Text(Formatter.rupiah(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
  ]);

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));

  Widget _quickAction(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Card(child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: scheme.primary)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
          ])),
        ]),
      ),
    ));
  }

  Widget _metric(BuildContext context, IconData icon, String label, int value) {
    final scheme = Theme.of(context).colorScheme;
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 20, color: scheme.primary)),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
      const SizedBox(height: 3),
      Text(Formatter.rupiah(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    ])));
  }

  Widget _agingRow(String label, int value) => ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1), title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: Text(Formatter.rupiah(value), style: const TextStyle(fontWeight: FontWeight.w800)));
}
