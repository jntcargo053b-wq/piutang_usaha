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
    final result = await provider.ringkasanTotal();
    if (!mounted) return;
    setState(() => summary = result);
  }

  Future<void> _backup() async {
    try {
      await context.read<PiutangProvider>().backupDatabase();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    await _load();
    await context.read<PiutangProvider>().muatPelanggan();
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piutang Usaha'),
        actions: [
          IconButton(onPressed: _backup, icon: const Icon(Icons.backup)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _card('Total Kredit', s?['total_kredit'] ?? 0),
            _card('Total Dibayar', s?['total_dibayar'] ?? 0),
            _card('Sisa Piutang', s?['sisa_piutang'] ?? 0),
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

  Widget _card(String title, int value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          Formatter.rupiah(value),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }
}
