import 'package:flutter_test/flutter_test.dart';
import 'package:piutang_usaha/data/indonesia_cities.dart';
import 'package:piutang_usaha/services/backup_service.dart';

void main() {
  group('data integrity regression', () {
    test('Indonesia city/regency list contains exactly 514 unique entries', () {
      expect(indonesiaCities.length, 514);
      expect(indonesiaCities.toSet().length, 514);
      expect(indonesiaCities.every((value) => value.trim().isNotEmpty), isTrue);
    });

    test('backup filename has millisecond precision for sub-minute uniqueness', () {
      final base = DateTime(2026, 9, 24, 17, 49, 12, 100);
      final next = base.add(const Duration(milliseconds: 1));
      final later = base.add(const Duration(milliseconds: 999));

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
