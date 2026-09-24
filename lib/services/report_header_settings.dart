import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_helper.dart';

class ReportHeaderSettings {
  static const _companyKey = 'report_header_company';
  static const _titleKey = 'report_header_title';
  static const _logoKey = 'report_header_logo';
  static const _companyDbKey = 'report_header_company';
  static const _titleDbKey = 'report_header_title';
  static const _logoDbKey = 'report_header_logo_blob';

  static const defaultCompany = 'JNT CARGO MLG053B';
  static const defaultTitle = 'LAPORAN TRANSAKSI PELANGGAN';

  final String companyName;
  final String reportTitle;
  final String? logoPath;

  const ReportHeaderSettings({
    required this.companyName,
    required this.reportTitle,
    this.logoPath,
  });

  static Future<ReportHeaderSettings> load() async {
    final db = DbHelper.instance;
    final companyRow = await db.getAppSetting(_companyDbKey);
    final titleRow = await db.getAppSetting(_titleDbKey);
    final logoRow = await db.getAppSetting(_logoDbKey);

    final prefs = await SharedPreferences.getInstance();
    final company = (companyRow?['value'] as String?)?.trim();
    final title = (titleRow?['value'] as String?)?.trim();
    final legacyLogoPath = prefs.getString(_logoKey);

    var logoBytes = logoRow?['blob'] as List<int>?;
    if (logoBytes == null && legacyLogoPath != null) {
      final legacyFile = File(legacyLogoPath);
      if (await legacyFile.exists()) {
        logoBytes = await legacyFile.readAsBytes();
        await db.setAppSetting(_logoDbKey, blob: logoBytes);
      }
    }

    String? materializedLogo;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      materializedLogo = await _materializeLogo(logoBytes);
    }

    final result = ReportHeaderSettings(
      companyName: company?.isNotEmpty == true
          ? company!
          : (prefs.getString(_companyKey) ?? defaultCompany),
      reportTitle: title?.isNotEmpty == true
          ? title!
          : (prefs.getString(_titleKey) ?? defaultTitle),
      logoPath: materializedLogo,
    );

    if (company == null || title == null) {
      await db.setAppSetting(_companyDbKey, value: result.companyName);
      await db.setAppSetting(_titleDbKey, value: result.reportTitle);
      await prefs.remove(_companyKey);
      await prefs.remove(_titleKey);
    }
    if (result.logoPath != null) {
      await prefs.remove(_logoKey);
    }
    return result;
  }

  Future<void> save({
    String? companyName,
    String? reportTitle,
    String? logoPath,
    bool removeLogo = false,
  }) async {
    final db = DbHelper.instance;
    final nextCompany = (companyName ?? this.companyName).trim();
    final nextTitle = (reportTitle ?? this.reportTitle).trim();

    await db.setAppSetting(_companyDbKey, value: nextCompany);
    await db.setAppSetting(_titleDbKey, value: nextTitle);

    if (removeLogo) {
      await db.setAppSetting(_logoDbKey, blob: null);
      final file = await _logoFile();
      if (await file.exists()) await file.delete();
    } else if (logoPath != null) {
      final source = File(logoPath);
      if (!await source.exists()) {
        throw StateError('File logo tidak ditemukan.');
      }
      final bytes = await source.readAsBytes();
      await db.setAppSetting(_logoDbKey, blob: bytes);
      await _writeLogoFile(bytes);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_companyKey);
    await prefs.remove(_titleKey);
    await prefs.remove(_logoKey);
  }

  static Future<void> clearLogo() async {
    final current = await load();
    await current.save(removeLogo: true);
  }

  static Future<void> reset() async {
    final db = DbHelper.instance;
    await db.setAppSetting(_companyDbKey, value: defaultCompany);
    await db.setAppSetting(_titleDbKey, value: defaultTitle);
    await db.setAppSetting(_logoDbKey, blob: null);
    final file = await _logoFile();
    if (await file.exists()) await file.delete();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_companyKey);
    await prefs.remove(_titleKey);
    await prefs.remove(_logoKey);
  }

  static Future<File> _logoFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'report_header_logo'));
  }

  static Future<void> _writeLogoFile(List<int> bytes) async {
    final file = await _logoFile();
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<String> _materializeLogo(List<int> bytes) async {
    final file = await _logoFile();
    if (!await file.exists() || await file.length() != bytes.length) {
      await _writeLogoFile(bytes);
    }
    return file.path;
  }
}
