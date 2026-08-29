# Piutang Usaha

Aplikasi Flutter untuk mengelola pelanggan, transaksi kredit, pembayaran, laporan, export PDF/Excel, serta backup dan restore database SQLite.

## Status
Versi hardening dan build-ready untuk diverifikasi melalui GitHub Actions.

## Fitur
- Manajemen pelanggan
- Transaksi kredit dengan nomor resi
- Pembayaran bertahap dan validasi agar tidak melebihi sisa piutang
- Perhitungan saldo/piutang
- Filter laporan berdasarkan periode
- Laporan aktivitas kredit dan pembayaran periode
- Export PDF dan Excel
- Backup dan restore SQLite dengan validasi schema dan integrity check
- Automated database regression tests
- GitHub Actions untuk analyze, test, dan build APK release

## Struktur
- `lib/models` model data
- `lib/services` database, backup, export
- `lib/providers` state management
- `lib/screens` UI
- `test` automated tests
- `.github/workflows` CI/build APK

## Build lokal
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## GitHub Actions
Workflow `.github/workflows/build-apk.yml` berjalan pada push ke `main` dan dapat dijalankan manual melalui Actions. Workflow membuat folder Android bila belum tersedia, mengambil dependency, menjalankan analyzer dan test, kemudian membangun APK release dan mengunggah artifact `piutang-usaha-release-apk`.

## Data safety
- Foreign key SQLite aktif.
- Pembayaran divalidasi terhadap sisa piutang di dalam transaction.
- Laporan membedakan total pembayaran transaksi dan pembayaran yang benar-benar terjadi pada periode laporan.
- Backup melakukan WAL checkpoint sebelum copy.
- Restore memvalidasi schema dan integrity check serta menyediakan rollback ketika penggantian database gagal.
