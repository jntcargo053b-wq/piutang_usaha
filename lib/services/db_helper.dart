import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/pelanggan.dart';
import '../models/transaksi_kredit.dart';
import '../models/pembayaran.dart';

class ValidasiException implements Exception {
  final String message;
  ValidasiException(this.message);
  @override
  String toString() => message;
}

class DbHelper {
  static final DbHelper instance = DbHelper._internal();
  DbHelper._internal();
  static const int _dbVersion = 5;
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'piutang_usaha.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE pelanggan (id INTEGER PRIMARY KEY AUTOINCREMENT, nama TEXT NOT NULL, alamat TEXT, no_hp TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE transaksi_kredit (id INTEGER PRIMARY KEY AUTOINCREMENT, pelanggan_id INTEGER NOT NULL, tanggal TEXT NOT NULL, nomor_resi TEXT NOT NULL, nama_penerima TEXT NOT NULL, kota_tujuan TEXT NOT NULL, deskripsi TEXT NOT NULL DEFAULT '', jumlah INTEGER NOT NULL, FOREIGN KEY (pelanggan_id) REFERENCES pelanggan (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE pembayaran (id INTEGER PRIMARY KEY AUTOINCREMENT, transaksi_id INTEGER NOT NULL, tanggal TEXT NOT NULL, jumlah INTEGER NOT NULL, metode TEXT, keterangan TEXT, FOREIGN KEY (transaksi_id) REFERENCES transaksi_kredit (id) ON DELETE CASCADE)''');
    await _buatIndex(db);
  }

  Future<void> _buatIndex(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaksi_pelanggan ON transaksi_kredit (pelanggan_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pembayaran_transaksi ON pembayaran (transaksi_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaksi_tanggal ON transaksi_kredit (tanggal)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaksi_resi ON transaksi_kredit (nomor_resi)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pembayaran_tanggal ON pembayaran (tanggal)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transaksi_kredit RENAME TO _old_transaksi_kredit');
      await db.execute('ALTER TABLE pembayaran RENAME TO _old_pembayaran');
      await db.execute('''CREATE TABLE transaksi_kredit (id INTEGER PRIMARY KEY AUTOINCREMENT, pelanggan_id INTEGER NOT NULL, tanggal TEXT NOT NULL, deskripsi TEXT NOT NULL, jumlah INTEGER NOT NULL, FOREIGN KEY (pelanggan_id) REFERENCES pelanggan (id) ON DELETE CASCADE)''');
      await db.execute('''CREATE TABLE pembayaran (id INTEGER PRIMARY KEY AUTOINCREMENT, transaksi_id INTEGER NOT NULL, tanggal TEXT NOT NULL, jumlah INTEGER NOT NULL, keterangan TEXT, FOREIGN KEY (transaksi_id) REFERENCES transaksi_kredit (id) ON DELETE CASCADE)''');
      await db.execute('''INSERT INTO transaksi_kredit (id,pelanggan_id,tanggal,deskripsi,jumlah) SELECT id,pelanggan_id,tanggal,deskripsi,CAST(ROUND(jumlah) AS INTEGER) FROM _old_transaksi_kredit''');
      await db.execute('''INSERT INTO pembayaran (id,transaksi_id,tanggal,jumlah,keterangan) SELECT id,transaksi_id,tanggal,CAST(ROUND(jumlah) AS INTEGER),keterangan FROM _old_pembayaran''');
      await db.execute('DROP TABLE _old_pembayaran');
      await db.execute('DROP TABLE _old_transaksi_kredit');
      await _buatIndex(db);
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE transaksi_kredit ADD COLUMN nomor_resi TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE transaksi_kredit ADD COLUMN nama_penerima TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE transaksi_kredit ADD COLUMN kota_tujuan TEXT NOT NULL DEFAULT ''");
      await _buatIndex(db);
    }
    if (oldVersion < 4) await db.execute('CREATE INDEX IF NOT EXISTS idx_pembayaran_tanggal ON pembayaran (tanggal)');
    if (oldVersion < 5) await db.execute("ALTER TABLE pembayaran ADD COLUMN metode TEXT");
  }

  Future<int> insertPelanggan(Pelanggan p) async {
    final nama = p.nama.trim();
    if (nama.isEmpty) throw ValidasiException('Nama pelanggan wajib diisi.');
    final db = await database;
    final data = p.toMap()..remove('id');
    data['nama'] = nama;
    return db.insert('pelanggan', data);
  }

  Future<int> updatePelanggan(Pelanggan p) async {
    final nama = p.nama.trim();
    if (p.id == null) throw ValidasiException('ID pelanggan tidak valid.');
    if (nama.isEmpty) throw ValidasiException('Nama pelanggan wajib diisi.');
    final db = await database;
    final data = p.toMap()..remove('id');
    data['nama'] = nama;
    return db.update('pelanggan', data, where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deletePelanggan(int id) async => (await database).transaction((txn) => txn.delete('pelanggan', where: 'id = ?', whereArgs: [id]));

  Future<List<Pelanggan>> getAllPelanggan() async {
    final rows = await (await database).query('pelanggan', orderBy: 'nama ASC');
    return rows.map((r) => Pelanggan.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getPelangganDenganSisa() async => (await database).rawQuery('''SELECT pl.*,COALESCE((SELECT SUM(t.jumlah) FROM transaksi_kredit t WHERE t.pelanggan_id=pl.id),0)-COALESCE((SELECT SUM(p.jumlah) FROM pembayaran p JOIN transaksi_kredit t2 ON t2.id=p.transaksi_id WHERE t2.pelanggan_id=pl.id),0) AS sisa_piutang FROM pelanggan pl ORDER BY pl.nama ASC''');

  Future<int> getSisaPiutangPelanggan(int id) async {
    final r = (await (await database).rawQuery('''SELECT COALESCE((SELECT SUM(jumlah) FROM transaksi_kredit WHERE pelanggan_id=?),0)-COALESCE((SELECT SUM(p.jumlah) FROM pembayaran p JOIN transaksi_kredit t ON t.id=p.transaksi_id WHERE t.pelanggan_id=?),0) AS sisa''', [id, id])).first;
    return (r['sisa'] as num?)?.toInt() ?? 0;
  }

  void _validateTransaksi(TransaksiKredit t) {
    if (t.id == null) throw ValidasiException('ID transaksi tidak valid.');
    if (t.pelangganId <= 0) throw ValidasiException('Pelanggan transaksi tidak valid.');
    if (t.jumlah <= 0) throw ValidasiException('Jumlah transaksi harus lebih dari 0.');
    if (t.nomorResi.trim().isEmpty || t.namaPenerima.trim().isEmpty || t.kotaTujuan.trim().isEmpty) {
      throw ValidasiException('Nomor resi, nama penerima, dan kota tujuan wajib diisi.');
    }
  }

  Future<int> insertTransaksi(TransaksiKredit t) async {
    if (t.jumlah <= 0) throw ValidasiException('Jumlah transaksi harus lebih dari 0.');
    if (t.nomorResi.trim().isEmpty || t.namaPenerima.trim().isEmpty || t.kotaTujuan.trim().isEmpty) {
      throw ValidasiException('Nomor resi, nama penerima, dan kota tujuan wajib diisi.');
    }
    final data = t.toMap()..remove('id');
    return (await database).insert('transaksi_kredit', data);
  }

  Future<int> updateTransaksi(TransaksiKredit t) async {
    _validateTransaksi(t);
    final db = await database;
    final exists = await db.query('transaksi_kredit', columns: ['id'], where: 'id = ?', whereArgs: [t.id], limit: 1);
    if (exists.isEmpty) throw ValidasiException('Transaksi tidak ditemukan.');
    final customer = await db.query('pelanggan', columns: ['id'], where: 'id = ?', whereArgs: [t.pelangganId], limit: 1);
    if (customer.isEmpty) throw ValidasiException('Pelanggan transaksi tidak ditemukan.');
    final data = t.toMap()..remove('id');
    return db.update('transaksi_kredit', data, where: 'id = ?', whereArgs: [t.id]);
  }

  Future<int> deleteTransaksi(int id) async => (await database).transaction((txn) => txn.delete('transaksi_kredit', where: 'id = ?', whereArgs: [id]));

  Future<List<TransaksiKredit>> getTransaksiByPelanggan(int id) async {
    final rows = await (await database).rawQuery('''SELECT t.*,COALESCE(SUM(p.jumlah),0) AS total_dibayar FROM transaksi_kredit t LEFT JOIN pembayaran p ON p.transaksi_id=t.id WHERE t.pelanggan_id=? GROUP BY t.id ORDER BY t.tanggal ASC, t.id ASC''', [id]);
    return rows.map((r) => TransaksiKredit.fromMap(r)).toList();
  }

  Future<TransaksiKredit?> getTransaksiById(int id) async => _getTransaksiByIdDb(await database, id);

  Future<TransaksiKredit?> _getTransaksiByIdDb(DatabaseExecutor db, int id) async {
    final rows = await db.rawQuery('''SELECT t.*,COALESCE(SUM(p.jumlah),0) AS total_dibayar FROM transaksi_kredit t LEFT JOIN pembayaran p ON p.transaksi_id=t.id WHERE t.id=? GROUP BY t.id''', [id]);
    return rows.isEmpty ? null : TransaksiKredit.fromMap(rows.first);
  }

  Future<Map<String, int>> getRingkasanTotal() async {
    final r = (await (await database).rawQuery('SELECT COALESCE((SELECT SUM(jumlah) FROM transaksi_kredit),0) AS total_kredit,COALESCE((SELECT SUM(jumlah) FROM pembayaran),0) AS total_dibayar')).first;
    final k = (r['total_kredit'] as num).toInt(), d = (r['total_dibayar'] as num).toInt();
    return {'total_kredit': k, 'total_dibayar': d, 'sisa_piutang': k - d};
  }

  Future<Map<String, int>> getAgingPiutang({DateTime? asOf}) async {
    final rows = await (await database).rawQuery('''SELECT t.tanggal,t.jumlah-COALESCE((SELECT SUM(p.jumlah) FROM pembayaran p WHERE p.transaksi_id=t.id),0) AS sisa FROM transaksi_kredit t''');
    final e = asOf ?? DateTime.now(), r = <String, int>{'0_30': 0, '31_60': 0, '61_90': 0, '91_plus': 0};
    for (final x in rows) {
      final s = (x['sisa'] as num?)?.toInt() ?? 0;
      final d = DateTime.tryParse('${x['tanggal']}');
      if (s <= 0 || d == null) continue;
      final days = e.difference(d).inDays;
      final k = days <= 30 ? '0_30' : days <= 60 ? '31_60' : days <= 90 ? '61_90' : '91_plus';
      r[k] = (r[k] ?? 0) + s;
    }
    return r;
  }

  Future<Map<String, int>> getDashboardBulan({DateTime? bulan}) async {
    final d = bulan ?? DateTime.now(), a = DateTime(d.year, d.month), b = DateTime(d.year, d.month + 1), sa = a.toIso8601String(), sb = b.toIso8601String();
    final r = (await (await database).rawQuery('''SELECT COALESCE((SELECT SUM(jumlah) FROM transaksi_kredit WHERE tanggal>=? AND tanggal<?),0) AS kredit,COALESCE((SELECT SUM(jumlah) FROM pembayaran WHERE tanggal>=? AND tanggal<?),0) AS pembayaran''', [sa, sb, sa, sb])).first;
    return {'kredit': (r['kredit'] as num).toInt(), 'pembayaran': (r['pembayaran'] as num).toInt()};
  }

  Future<List<Map<String, dynamic>>> getTopPiutangPelanggan({int limit = 5}) async => (await database).rawQuery('''SELECT pl.id,pl.nama,COALESCE((SELECT SUM(t.jumlah) FROM transaksi_kredit t WHERE t.pelanggan_id=pl.id),0)-COALESCE((SELECT SUM(p.jumlah) FROM pembayaran p JOIN transaksi_kredit t2 ON t2.id=p.transaksi_id WHERE t2.pelanggan_id=pl.id),0) AS sisa_piutang FROM pelanggan pl ORDER BY sisa_piutang DESC LIMIT ?''', [limit]);

  Future<List<Map<String, dynamic>>> getRekapPeriode({required DateTime dari, required DateTime sampai}) async {
    final a = dari.toIso8601String(), b = DateTime(sampai.year, sampai.month, sampai.day + 1).toIso8601String();
    return (await database).rawQuery('''SELECT t.id,t.tanggal,t.deskripsi,t.jumlah,t.nomor_resi,t.nama_penerima,t.kota_tujuan,pl.nama AS nama_pelanggan,COALESCE((SELECT SUM(p1.jumlah) FROM pembayaran p1 WHERE p1.transaksi_id=t.id),0) AS total_dibayar,COALESCE((SELECT SUM(p2.jumlah) FROM pembayaran p2 WHERE p2.transaksi_id=t.id AND p2.tanggal>=? AND p2.tanggal<?),0) AS dibayar_periode FROM transaksi_kredit t JOIN pelanggan pl ON pl.id=t.pelanggan_id WHERE t.tanggal>=? AND t.tanggal<? ORDER BY t.tanggal ASC,t.id ASC''', [a, b, a, b]);
  }

  Future<List<Map<String, dynamic>>> getPembayaranPeriode({required DateTime dari, required DateTime sampai}) async {
    final a = dari.toIso8601String(), b = DateTime(sampai.year, sampai.month, sampai.day + 1).toIso8601String();
    return (await database).rawQuery('''SELECT p.id,p.tanggal,p.jumlah,p.metode,p.keterangan,t.deskripsi AS deskripsi_transaksi,pl.nama AS nama_pelanggan FROM pembayaran p JOIN transaksi_kredit t ON t.id=p.transaksi_id JOIN pelanggan pl ON pl.id=t.pelanggan_id WHERE p.tanggal>=? AND p.tanggal<? ORDER BY p.tanggal ASC,p.id ASC''', [a, b]);
  }

  Future<int> insertPembayaran(Pembayaran p) async {
    if (p.jumlah <= 0) throw ValidasiException('Jumlah pembayaran harus lebih dari 0.');
    return (await database).transaction((txn) => insertPembayaranInTransaction(txn, p));
  }

  Future<int> insertPembayaranInTransaction(DatabaseExecutor txn, Pembayaran p) async {
    if (p.jumlah <= 0) throw ValidasiException('Jumlah pembayaran harus lebih dari 0.');
    final metode = p.metode?.trim().toLowerCase();
    if (metode != 'cash' && metode != 'transfer') throw ValidasiException('Metode pembayaran harus Cash atau Transfer.');
    final t = await _getTransaksiByIdDb(txn, p.transaksiId);
    if (t == null) throw ValidasiException('Transaksi tidak ditemukan.');
    if (p.jumlah > t.sisa) throw ValidasiException('Jumlah pembayaran melebihi sisa piutang.');
    final data = p.toMap()..remove('id');
    data['metode'] = metode;
    return txn.insert('pembayaran', data);
  }

  Future<int> deletePembayaran(int id) async => (await database).delete('pembayaran', where: 'id = ?', whereArgs: [id]);

  Future<List<Pembayaran>> getPembayaranByTransaksi(int id) async {
    final r = await (await database).query('pembayaran', where: 'transaksi_id = ?', whereArgs: [id], orderBy: 'tanggal ASC,id ASC');
    return r.map((x) => Pembayaran.fromMap(x)).toList();
  }

  Future<void> validateSchema([DatabaseExecutor? executor]) async {
    final db = executor ?? await database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('pelanggan','transaksi_kredit','pembayaran')");
    final names = tables.map((r) => r['name'] as String).toSet();
    const required = {'pelanggan', 'transaksi_kredit', 'pembayaran'};
    if (!names.containsAll(required)) throw ValidasiException('Database tidak kompatibel.');
  }

  Future<void> flushForBackup() async { final db = _db; if (db == null) return; await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)'); }
  Future<String> getDbPath() async => join(await getDatabasesPath(), 'piutang_usaha.db');
  Future<void> tutupKoneksi() async { if (_db != null) { await _db!.close(); _db = null; } }
}
