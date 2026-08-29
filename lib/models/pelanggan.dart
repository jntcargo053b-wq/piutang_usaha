class Pelanggan {
  final int? id;
  final String nama;
  final String? alamat;
  final String? noHp;
  final DateTime createdAt;

  Pelanggan({this.id, required this.nama, this.alamat, this.noHp, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'nama': nama, 'alamat': alamat, 'no_hp': noHp,
    'created_at': createdAt.toIso8601String(),
  };

  factory Pelanggan.fromMap(Map<String, dynamic> map) => Pelanggan(
    id: map['id'] as int?, nama: map['nama'] as String,
    alamat: map['alamat'] as String?, noHp: map['no_hp'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  Pelanggan copyWith({String? nama, String? alamat, String? noHp}) => Pelanggan(
    id: id, nama: nama ?? this.nama, alamat: alamat ?? this.alamat,
    noHp: noHp ?? this.noHp, createdAt: createdAt,
  );
}
