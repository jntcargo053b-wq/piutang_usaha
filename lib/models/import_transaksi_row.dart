class ImportTransaksiRow {
  final String namaPelanggan;
  final String? noHp;
  final String? alamat;
  final DateTime tanggal;
  final String nomorResi;
  final String namaPenerima;
  final String kotaTujuan;
  final int quantity;
  final double berat;
  final int jumlah;
  final String? catatan;

  const ImportTransaksiRow({
    required this.namaPelanggan,
    this.noHp,
    this.alamat,
    required this.tanggal,
    required this.nomorResi,
    required this.namaPenerima,
    required this.kotaTujuan,
    required this.quantity,
    required this.berat,
    required this.jumlah,
    this.catatan,
  });

  Map<String, dynamic> toMap() => {
    'nama_pelanggan': namaPelanggan,
    'no_hp': noHp,
    'alamat': alamat,
    'tanggal': tanggal.toIso8601String(),
    'nomor_resi': nomorResi,
    'nama_penerima': namaPenerima,
    'kota_tujuan': kotaTujuan,
    'quantity': quantity,
    'berat': berat,
    'jumlah': jumlah,
    'catatan': catatan,
  };
}
