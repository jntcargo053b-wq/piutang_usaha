class Pembayaran {
  final int? id;
  final int transaksiId;
  final DateTime tanggal;
  final int jumlah;
  final String? metode;
  final String? keterangan;

  Pembayaran({this.id, required this.transaksiId, required this.tanggal, required this.jumlah, this.metode, this.keterangan});

  Map<String, dynamic> toMap() => {
    'id': id,
    'transaksi_id': transaksiId,
    'tanggal': tanggal.toIso8601String(),
    'jumlah': jumlah,
    'metode': metode,
    'keterangan': keterangan,
  };

  factory Pembayaran.fromMap(Map<String, dynamic> map) => Pembayaran(
    id: map['id'] as int?,
    transaksiId: map['transaksi_id'] as int,
    tanggal: DateTime.parse(map['tanggal'] as String),
    jumlah: (map['jumlah'] as num).toInt(),
    metode: map['metode'] as String?,
    keterangan: map['keterangan'] as String?,
  );
}
