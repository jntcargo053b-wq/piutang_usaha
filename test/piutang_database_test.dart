import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/services/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = DbHelper.instance;

  setUp(() async {
    await db.tutupKoneksi();
    final path = await db.getDbPath();
    final file = File(path);
    if (await file.exists()) await file.delete();
  });

  tearDown(() async {
    await db.tutupKoneksi();
    final path = await db.getDbPath();
    final file = File(path);
    if (await file.exists()) await file.delete();
  });
}
