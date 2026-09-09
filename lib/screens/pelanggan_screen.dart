import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pelanggan.dart';
import '../providers/piutang_provider.dart';
import '../utils/formatter.dart';
import 'detail_pelanggan_screen.dart';

class PelangganScreen extends StatefulWidget {
  const PelangganScreen({super.key});
  @override
  State<PelangganScreen> createState() => _PelangganScreenState();
}

class _PelangganScreenState extends State<PelangganScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'semua';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _query = _searchController.text.trim().toLowerCase());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PiutangProvider>().muatPelanggan();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _form({Pelanggan? old}) async {
    final name = TextEditingController(text: old?.nama ?? '');
    final phone = TextEditingController(text: old?.noHp ?? '');
    final address = TextEditingController(text: old?.alamat ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    old == null ? 'Tambah Pelanggan' : 'Edit Pelanggan',
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pelanggan *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'No. HP',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Alamat',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => saving = true);
                              try {
                                final provider = ctx.read<PiutangProvider>();
                                if (old == null) {
                                  await provider.tambahPelanggan(
                                    Pelanggan(
                                      nama: name.text.trim(),
                                      noHp: phone.text.trim().isEmpty
                                          ? null
                                          : phone.text.trim(),
                                      alamat: address.text.trim().isEmpty
                                          ? null
                                          : address.text.trim(),
                                    ),
                                  );
                                } else {
                                  await provider.updatePelanggan(
                                    old.copyWith(
                                      nama: name.text.trim(),
                                      noHp: phone.text.trim(),
                                      alamat: address.text.trim(),
                                    ),
                                  );
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) {
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text(_friendlyError(e))),
                                  );
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan Pelanggan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    address.dispose();
  }

  Future<void> _delete(Pelanggan pelanggan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus pelanggan?'),
        content: Text(
          'Semua transaksi dan pembayaran ${pelanggan.nama} akan ikut terhapus. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<PiutangProvider>().hapusPelanggan(pelanggan.id!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    }
  }

  Future<void> _openDetail(Pelanggan pelanggan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailPelangganScreen(pelanggan: pelanggan),
      ),
    );
    if (!mounted) return;
    await context.read<PiutangProvider>().muatPelanggan();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pelanggan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah pelanggan',
            onPressed: _form,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _form,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Consumer<PiutangProvider>(
        builder: (context, provider, _) {
          if (provider.loading) return const Center(child: CircularProgressIndicator());

          final customers = provider.daftarPelanggan.where((pelanggan) {
            final matchesSearch = _query.isEmpty ||
                pelanggan.nama.toLowerCase().contains(_query) ||
                (pelanggan.noHp ?? '').toLowerCase().contains(_query) ||
                (pelanggan.alamat ?? '').toLowerCase().contains(_query);
            if (!matchesSearch) return false;

            final sisa = provider.sisaPelanggan(pelanggan.id!);
            if (_statusFilter == 'piutang') return sisa > 0;
            if (_statusFilter == 'lunas') return sisa <= 0;
            return true;
          }).toList();

          final totalCustomers = provider.daftarPelanggan.length;
          final debtCustomers = provider.daftarPelanggan
              .where((p) => provider.sisaPelanggan(p.id!) > 0)
              .length;
          final paidCustomers = totalCustomers - debtCustomers;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama, telepon, atau alamat...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip(
                      label: 'Semua ($totalCustomers)',
                      value: 'semua',
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Piutang ($debtCustomers)',
                      value: 'piutang',
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Lunas ($paidCustomers)',
                      value: 'lunas',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: provider.daftarPelanggan.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 58, color: scheme.primary),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum ada pelanggan.',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tambahkan pelanggan untuk mulai mencatat transaksi.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : customers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.filter_alt_off_outlined, size: 46, color: scheme.primary),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Tidak ada pelanggan yang sesuai.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Coba ubah kata pencarian atau filter status.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                            itemCount: customers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 9),
                            itemBuilder: (context, index) {
                              final pelanggan = customers[index];
                              final sisa = provider.sisaPelanggan(pelanggan.id!);
                              final hasDebt = sisa > 0;
                              final statusColor = hasDebt ? scheme.error : scheme.primary;
                              return Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _openDetail(pelanggan),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 23,
                                          backgroundColor: scheme.primaryContainer,
                                          foregroundColor: scheme.primary,
                                          child: Text(
                                            pelanggan.nama.isEmpty ? '?' : pelanggan.nama[0].toUpperCase(),
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                pelanggan.nama,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w800),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                pelanggan.noHp ?? 'No. HP belum diisi',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              Formatter.rupiah(sisa),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontWeight: FontWeight.w800, color: statusColor),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              hasDebt ? 'Piutang' : 'Lunas',
                                              style: TextStyle(fontSize: 11, color: statusColor),
                                            ),
                                          ],
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Menu pelanggan',
                                          onSelected: (value) {
                                            if (value == 'edit') _form(old: pelanggan);
                                            if (value == 'delete') _delete(pelanggan);
                                          },
                                          itemBuilder: (menuContext) => [
                                            const PopupMenuItem<String>(
                                              value: 'edit',
                                              child: ListTile(
                                                leading: Icon(Icons.edit_outlined),
                                                title: Text('Edit'),
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'delete',
                                              child: ListTile(
                                                leading: const Icon(Icons.delete_outline),
                                                title: const Text('Hapus'),
                                                contentPadding: EdgeInsets.zero,
                                                textColor: Theme.of(menuContext).colorScheme.error,
                                                iconColor: Theme.of(menuContext).colorScheme.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip({required String label, required String value}) {
    return ChoiceChip(
      label: Text(label),
      selected: _statusFilter == value,
      onSelected: (_) => setState(() => _statusFilter = value),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: _statusFilter == value
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
