class TransaksiKredit {
  final int? id;
  final int pelangganId;
  final DateTime tanggal;
  final String nomorResi;
  final String namaPenerima;
  final String kotaTujuan;
  final int jumlah;
  final String? catatan;
  final int totalDibayar;

  TransaksiKredit({this.id, required this.pelangganId, required this.tanggal,
    required this.nomorResi, required this.namaPenerima, required this.kotaTujuan,
    required this.jumlah, this.catatan, this.totalDibayar = 0});

  int get sisa => jumlah - totalDibayar;
  bool get lunas => sisa <= 0;

  Map<String, dynamic> toMap() => {
    'id': id, 'pelanggan_id': pelangganId, 'tanggal': tanggal.toIso8601String(),
    'nomor_resi': nomorResi, 'nama_penerima': namaPenerima,
    'kota_tujuan': kotaTujuan, 'jumlah': jumlah, 'deskripsi': catatan ?? '',
  };

  factory TransaksiKredit.fromMap(Map<String, dynamic> map) => TransaksiKredit(
    id: map['id'] as int?, pelangganId: map['pelanggan_id'] as int,
    tanggal: DateTime.parse(map['tanggal'] as String),
    nomorResi: map['nomor_resi'] as String? ?? '',
    namaPenerima: map['nama_penerima'] as String? ?? '',
    kotaTujuan: map['kota_tujuan'] as String? ?? '',
    jumlah: (map['jumlah'] as num).toInt(),
    catatan: (map['deskripsi'] as String?)?.isEmpty ?? true ? null : map['deskripsi'] as String,
    totalDibayar: (map['total_dibayar'] as num?)?.toInt() ?? 0,
  );
}
