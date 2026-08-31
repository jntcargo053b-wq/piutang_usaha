import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/piutang_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const PiutangUsahaApp());
}

class PiutangUsahaApp extends StatelessWidget {
  const PiutangUsahaApp({super.key});
  @override
  Widget build(BuildContext context) {
    const seed = Colors.blue;
    final lightScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final darkScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return ChangeNotifierProvider(
      create: (_) => PiutangProvider(),
      child: MaterialApp(
        title: 'Piutang Usaha',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: lightScheme, useMaterial3: true, appBarTheme: const AppBarTheme(centerTitle: true), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
        darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true, appBarTheme: const AppBarTheme(centerTitle: true), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
