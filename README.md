# Piutang Usaha

Aplikasi Flutter untuk mengelola pelanggan, transaksi kredit, pembayaran, laporan, export PDF/Excel, serta backup dan restore database SQLite.

## Fitur
- Manajemen pelanggan
- Transaksi kredit dengan nomor resi
- Pembayaran bertahap dan validasi agar tidak melebihi sisa piutang
- Perhitungan saldo/piutang
- Filter laporan berdasarkan periode
- Laporan aktivitas kredit dan pembayaran periode
- Export PDF dan Excel
- Backup dan restore SQLite dengan validasi integritas
- Automated database tests
- GitHub Actions untuk analyze, test, dan build APK

## Struktur
- `lib/models` model data
- `lib/services` database, backup, export
- `lib/providers` state management
- `lib/screens` UI
- `test` automated tests
- `.github/workflows` CI/build APK

## Build
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Catatan
Backup database aktif menggunakan checkpoint WAL sebelum file backup dibuat. Restore memvalidasi schema dan `integrity_check` sebelum mengganti database aktif.
