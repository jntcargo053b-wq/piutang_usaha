import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/data/indonesia_cities.dart';
import 'package:piutang_usaha/services/backup_service.dart';

void main() {
  group('data integrity regression', () {
    test('Indonesia city/regency list contains exactly 514 unique entries', () {
      expect(indonesiaCities.length, 514);
      expect(indonesiaCities.toSet().length, 514);
      expect(indonesiaCities.every((value) => value.trim().isNotEmpty), isTrue);
    });

    test('backup validator rejects a non-SQLite file', () async {
      final file = File(
        '${Directory.systemTemp.path}/piutang_invalid_backup_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      await file.writeAsString('this is not sqlite');

      try {
        await expectLater(
          BackupService.validateBackupFile(file.path),
          throwsA(isA<Exception>()),
        );
      } finally {
        if (await file.exists()) await file.delete();
      }
    });

    test('backup validator rejects a future database version', () async {
      final file = File(
        '${Directory.systemTemp.path}/piutang_future_backup_${DateTime.now().microsecondsSinceEpoch}.db',
      );

      final database = await databaseFactory.openDatabase(
        file.path,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE pelanggan (id INTEGER PRIMARY KEY AUTOINCREMENT, nama TEXT NOT NULL, alamat TEXT, no_hp TEXT, created_at TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE transaksi_kredit (id INTEGER PRIMARY KEY AUTOINCREMENT, pelanggan_id INTEGER NOT NULL, tanggal TEXT NOT NULL, nomor_resi TEXT NOT NULL, nama_penerima TEXT NOT NULL, kota_tujuan TEXT NOT NULL, deskripsi TEXT NOT NULL DEFAULT "", jumlah INTEGER NOT NULL, berat REAL NOT NULL DEFAULT 0, quantity INTEGER NOT NULL DEFAULT 1)',
            );
            await db.execute(
              'CREATE TABLE pembayaran (id INTEGER PRIMARY KEY AUTOINCREMENT, transaksi_id INTEGER NOT NULL, tanggal TEXT NOT NULL, jumlah INTEGER NOT NULL, keterangan TEXT, metode TEXT)',
            );
            await db.execute(
              'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, blob BLOB)',
            );
          },
        ),
      );
      await database.rawQuery('PRAGMA user_version = 8');
      await database.close();

      try {
        await expectLater(
          BackupService.validateBackupFile(file.path),
          throwsA(isA<Exception>()),
        );
      } finally {
        if (await file.exists()) await file.delete();
        final wal = File('${file.path}-wal');
        final shm = File('${file.path}-shm');
        if (await wal.exists()) await wal.delete();
        if (await shm.exists()) await shm.delete();
      }
    });

    test('backup filename has millisecond precision for sub-minute uniqueness', () {
      final base = DateTime(2026, 9, 24, 17, 49, 12, 100);
      final next = base.add(const Duration(milliseconds: 1));
      final later = base.add(const Duration(milliseconds: 899));

      final a = BackupService.backupFilename(base);
      final b = BackupService.backupFilename(next);
      final c = BackupService.backupFilename(later);

      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
      expect(a, endsWith('12100.db'));
      expect(b, endsWith('12101.db'));
      expect(c, endsWith('12999.db'));
    });

    test('backup filename remains unique across consecutive seconds', () {
      final a = BackupService.backupFilename(
        DateTime(2026, 9, 24, 17, 49, 12, 999),
      );
      final b = BackupService.backupFilename(
        DateTime(2026, 9, 24, 17, 49, 13, 0),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
