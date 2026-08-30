import 'package:flutter/foundation.dart';
import '../models/pelanggan.dart';
import '../models/transaksi_kredit.dart';
import '../models/pembayaran.dart';
import '../services/db_helper.dart';
import '../services/backup_service.dart';

class PiutangProvider extends ChangeNotifier {
  final _db = DbHelper.instance;
  List<Pelanggan> _daftarPelanggan = [];
  final Map<int, int> _sisaPerPelanggan = {};
  bool _loading = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  List<Pelanggan> get daftarPelanggan => List.unmodifiable(_daftarPelanggan);
  bool get loading => _loading;
  int sisaPelanggan(int id) => _sisaPerPelanggan[id] ?? 0;
  void _safeNotify() { if (!_disposed) notifyListeners(); }
  @override void dispose() { _disposed = true; super.dispose(); }
  Future<void> muatPelanggan() async { final generation=++_loadGeneration; _loading=true; _safeNotify(); try { final rows=await _db.getPelangganDenganSisa(); if(_disposed||generation!=_loadGeneration)return; final pelanggan=<Pelanggan>[],saldo=<int,int>{}; for(final row in rows){final p=Pelanggan.fromMap(row); pelanggan.add(p);if(p.id!=null)saldo[p.id!]=(row['sisa_piutang'] as num?)?.toInt()??0;} _daftarPelanggan=pelanggan;_sisaPerPelanggan..clear()..addAll(saldo);} finally {if(!_disposed&&generation==_loadGeneration){_loading=false;_safeNotify();}} }
  Future<void> tambahPelanggan(Pelanggan p) async { await _db.insertPelanggan(p); await muatPelanggan(); }
  Future<void> updatePelanggan(Pelanggan p) async { await _db.updatePelanggan(p); await muatPelanggan(); }
  Future<void> hapusPelanggan(int id) async { await _db.deletePelanggan(id); await muatPelanggan(); }
  Future<List<TransaksiKredit>> muatTransaksi(int id) => _db.getTransaksiByPelanggan(id);
  Future<void> tambahTransaksi(TransaksiKredit t) async { await _db.insertTransaksi(t); await muatPelanggan(); }
  Future<void> hapusTransaksi(int id) async { await _db.deleteTransaksi(id); await muatPelanggan(); }
  Future<List<Pembayaran>> muatPembayaran(int id) => _db.getPembayaranByTransaksi(id);
  Future<void> tambahPembayaran(Pembayaran p) async { await _db.insertPembayaran(p); await muatPelanggan(); }
  Future<void> hapusPembayaran(int id) async { await _db.deletePembayaran(id); await muatPelanggan(); }
  Future<Map<String,int>> ringkasanTotal() => _db.getRingkasanTotal();
  Future<Map<String,int>> agingPiutang() => _db.getAgingPiutang();
  Future<Map<String,int>> dashboardBulan() => _db.getDashboardBulan();
  Future<List<Map<String,dynamic>>> topPiutangPelanggan({int limit=5}) => _db.getTopPiutangPelanggan(limit: limit);
  Future<List<Map<String,dynamic>>> rekapPeriode(DateTime dari,DateTime sampai) => _db.getRekapPeriode(dari:dari,sampai:sampai);
  Future<List<Map<String,dynamic>>> pembayaranPeriode(DateTime dari,DateTime sampai) => _db.getPembayaranPeriode(dari:dari,sampai:sampai);
  Future<void> backupDatabase() => BackupService.backup();
  Future<bool> restoreDatabase() async { final ok=await BackupService.restore();if(ok)await muatPelanggan();return ok; }
}
