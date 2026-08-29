import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piutang_usaha/main.dart';
import 'package:piutang_usaha/services/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DbHelper.instance.tutupKoneksi();
  });

  testWidgets('Piutang Usaha app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const PiutangUsahaApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Piutang Usaha'), findsOneWidget);
  });
}
