import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/data/indonesia_cities.dart';
import 'package:piutang_usaha/services/backup_service.dart';
import 'package:piutang_usaha/services/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
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
    
    test('restore end-to-end replaces live data and preserves it after validation', () async {
      final dbHelper = DbHelper.instance;
      final dbPath = await dbHelper.getDbPath();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final baseline = File('${Directory.systemTemp.path}/piutang_baseline_$suffix.db');
      final fixture = File('${Directory.systemTemp.path}/piutang_restore_fixture_${suffix}.db');

      var baselineCreated = false;
      try {
        await dbHelper.database;
        await dbHelper.flushForBackup();
        await dbHelper.tutupKoneksi();
        final live = File(dbPath);
        if (await live.exists()) {
          await live.copy(baseline.path);
          baselineCreated = true;
        }

        final db = await dbHelper.database;
        await db.transaction((txn) async {
          await txn.delete('pembayaran');
          await txn.delete('transaksi_kredit');
          await txn.delete('pelanggan');
          await txn.delete('app_settings');
          final pelangganId = await txn.insert('pelanggan', {
            'nama': 'Restore Test Customer',
            'alamat': 'Alamat Uji',
            'no_hp': '081234567890',
            'created_at': '2026-09-26T10:00:00.000',
          });
          final transaksiId = await txn.insert('transaksi_kredit', {
            'pelanggan_id': pelangganId,
            'tanggal': '2026-09-26T10:01:00.000',
            'nomor_resi': 'RESTORE-E2E-001',
            'nama_penerima': 'Penerima Uji',
            'kota_tujuan': 'Malang',
            'deskripsi': 'Transaksi untuk uji restore',
            'jumlah': 150000,
            'berat': 2.5,
            'quantity': 2,
          });
          await txn.insert('pembayaran', {
            'transaksi_id': transaksiId,
            'tanggal': '2026-09-26T10:02:00.000',
            'jumlah': 50000,
            'metode': 'transfer',
            'keterangan': 'Pembayaran uji restore',
          });
          await txn.insert('app_settings', {
            'key': 'restore_test',
            'value': 'fixture-ok',
            'blob': null,
          });
        });
        await dbHelper.flushForBackup();
        await dbHelper.tutupKoneksi();

        await File(dbPath).copy(fixture.path);
        await BackupService.validateBackupFile(fixture.path);

        final mutated = await dbHelper.database;
        await mutated.update(
          'pelanggan',
          {'nama': 'DATA SETELAH MUTASI'},
          where: 'nama = ?',
          whereArgs: ['Restore Test Customer'],
        );
        await mutated.delete(
          'pembayaran',
          where: 'keterangan = ?',
          whereArgs: ['Pembayaran uji restore'],
        );
        await dbHelper.flushForBackup();
        await dbHelper.tutupKoneksi();

        expect(await BackupService.restoreFromFile(fixture.path), isTrue);

        final restored = await dbHelper.database;
        final customerRows = await restored.query(
          'pelanggan',
          where: 'nama = ?',
          whereArgs: ['Restore Test Customer'],
        );
        final paymentRows = await restored.query(
          'pembayaran',
          where: 'keterangan = ?',
          whereArgs: ['Pembayaran uji restore'],
        );
        final settingRows = await restored.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['restore_test'],
        );

        expect(customerRows, hasLength(1));
        expect(paymentRows, hasLength(1));
        expect(paymentRows.single['jumlah'], 50000);
        expect(settingRows, hasLength(1));
        expect(settingRows.single['value'], 'fixture-ok');

        await dbHelper.validateSchema(restored);
        final integrity = await restored.rawQuery('PRAGMA integrity_check');
        expect(integrity.single.values.single.toString().toLowerCase(), 'ok');
      } finally {
        await dbHelper.tutupKoneksi();
        if (baselineCreated && await baseline.exists()) {
          await BackupService.restoreFromFile(baseline.path);
        }
        if (await baseline.exists()) await baseline.delete();
        if (await fixture.exists()) await fixture.delete();
        final fixtureWal = File('${fixture.path}-wal');
        final fixtureShm = File('${fixture.path}-shm');
        if (await fixtureWal.exists()) await fixtureWal.delete();
        if (await fixtureShm.exists()) await fixtureShm.delete();
      }
    });
  });
}
