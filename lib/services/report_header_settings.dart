import 'package:shared_preferences/shared_preferences.dart';

class ReportHeaderSettings {
  static const _companyKey = 'report_header_company';
  static const _titleKey = 'report_header_title';
  static const _logoKey = 'report_header_logo';
  static const defaultCompany = 'JNT CARGO MLG053B';
  static const defaultTitle = 'LAPORAN TRANSAKSI PELANGGAN';

  final String companyName;
  final String reportTitle;
  final String? logoPath;
  const ReportHeaderSettings({required this.companyName, required this.reportTitle, this.logoPath});

  static Future<ReportHeaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReportHeaderSettings(companyName: prefs.getString(_companyKey) ?? defaultCompany, reportTitle: prefs.getString(_titleKey) ?? defaultTitle, logoPath: prefs.getString(_logoKey));
  }

  Future<void> save({String? companyName, String? reportTitle, String? logoPath, bool removeLogo = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyKey, (companyName ?? this.companyName).trim());
    await prefs.setString(_titleKey, (reportTitle ?? this.reportTitle).trim());
    if (removeLogo) {
      await prefs.remove(_logoKey);
    } else if (logoPath != null) {
      await prefs.setString(_logoKey, logoPath);
    }
  }

  static Future<void> clearLogo() async { final prefs = await SharedPreferences.getInstance(); await prefs.remove(_logoKey); }
  static Future<void> reset() async { final prefs = await SharedPreferences.getInstance(); await prefs.remove(_companyKey); await prefs.remove(_titleKey); await prefs.remove(_logoKey); }
}
