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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PiutangProvider>().muatPelanggan();
    });
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    old == null ? 'Tambah Pelanggan' : 'Edit Pelanggan',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nama *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'No. HP'),
                  ),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Alamat'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
                                      noHp: phone.text.trim().isEmpty ? null : phone.text.trim(),
                                      alamat: address.text.trim().isEmpty ? null : address.text.trim(),
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
                                    SnackBar(content: Text('$e')),
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
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
          'Semua transaksi dan pembayaran ${pelanggan.nama} akan ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      floatingActionButton: FloatingActionButton(
        onPressed: _form,
        child: const Icon(Icons.add),
      ),
      body: Consumer<PiutangProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.daftarPelanggan.isEmpty) {
            return const Center(child: Text('Belum ada pelanggan.'));
          }
          return ListView.builder(
            itemCount: provider.daftarPelanggan.length,
            itemBuilder: (context, index) {
              final pelanggan = provider.daftarPelanggan[index];
              final sisa = provider.sisaPelanggan(pelanggan.id!);
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    pelanggan.nama.isEmpty ? '?' : pelanggan.nama[0].toUpperCase(),
                  ),
                ),
                title: Text(pelanggan.nama),
                subtitle: Text(pelanggan.noHp ?? '-'),
                trailing: Text(
                  Formatter.rupiah(sisa),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sisa > 0 ? Colors.red : Colors.green,
                  ),
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailPelangganScreen(pelanggan: pelanggan),
                    ),
                  );
                  if (!mounted) return;
                  await context.read<PiutangProvider>().muatPelanggan();
                },
                onLongPress: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (sheetContext) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Edit'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _form(old: pelanggan);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete),
                          title: const Text('Hapus'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _delete(pelanggan);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
