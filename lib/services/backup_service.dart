import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class BackupService {
  static Future<void> backup() async {
    await DbHelper.instance.database;
    try {
      await DbHelper.instance.flushForBackup();
    } finally {
      await DbHelper.instance.tutupKoneksi();
    }
    final dbPath = await DbHelper.instance.getDbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('Database belum ada / belum pernah diisi data.');
    }
    final walFile = File('$dbPath-wal');
    if (await walFile.exists() && await walFile.length() > 0) {
      throw Exception('Backup dibatalkan: WAL database belum sepenuhnya tersinkron.');
    }
    final now = DateTime.now();
    final name = 'backup_piutang_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.db';
    final tujuan = File(p.join((await getTemporaryDirectory()).path, name));
    await dbFile.copy(tujuan.path);
    await _validateBackupFile(tujuan.path);
    await DbHelper.instance.database;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(tujuan.path)],
        text: 'Backup database Piutang Usaha ($name)',
      ),
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static Future<bool> restore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
    if (result == null || result.files.single.path == null) return false;
    final selected = File(result.files.single.path!);
    if (!await selected.exists()) throw Exception('File backup tidak ditemukan.');
    await _validateBackupFile(selected.path);
    final dbPath = await DbHelper.instance.getDbPath();
    final current = File(dbPath);
    final tmp = File('$dbPath.restore_tmp');
    final rollback = File('$dbPath.before_restore');
    await DbHelper.instance.flushForBackup();
    await DbHelper.instance.tutupKoneksi();
    try {
      if (await current.exists()) {
        if (await rollback.exists()) await rollback.delete();
        await current.copy(rollback.path);
      }
      if (await tmp.exists()) await tmp.delete();
      await selected.copy(tmp.path);
      if (await current.exists()) await current.delete();
      await tmp.rename(current.path);
      final db = await DbHelper.instance.database;
      await DbHelper.instance.validateSchema(db);
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      final status = integrity.first.values.first?.toString().toLowerCase();
      if (status != 'ok') throw Exception('Database hasil restore gagal integrity check: $status');
      if (await rollback.exists()) await rollback.delete();
      return true;
    } catch (e) {
      await DbHelper.instance.tutupKoneksi();
      if (await tmp.exists()) await tmp.delete();
      if (await current.exists()) await current.delete();
      if (await rollback.exists()) await rollback.rename(current.path);
      await DbHelper.instance.database;
      rethrow;
    } finally {
      if (await tmp.exists()) await tmp.delete();
      if (await rollback.exists() && await current.exists()) await rollback.delete();
    }
  }

  static Future<void> _validateBackupFile(String path) async {
    final file = File(path);
    final bytes = await file.openRead(0, 16).first;
    const magic = 'SQLite format 3\u0000';
    if (String.fromCharCodes(bytes) != magic) {
      throw Exception('File yang dipilih bukan file backup database SQLite yang valid.');
    }
    final validationPath = '$path.validation_tmp';
    final vf = File(validationPath);
    if (await vf.exists()) await vf.delete();
    await file.copy(validationPath);
    Database? testDb;
    try {
      testDb = await openDatabase(validationPath, readOnly: true);
      await DbHelper.instance.validateSchema(testDb);
      final integrity = await testDb.rawQuery('PRAGMA integrity_check');
      final status = integrity.first.values.first?.toString().toLowerCase();
      if (status != 'ok') throw Exception('Database backup gagal integrity check: $status');
    } catch (e) {
      throw Exception('Backup tidak kompatibel atau rusak: $e');
    } finally {
      await testDb?.close();
      if (await vf.exists()) await vf.delete();
    }
  }
}
