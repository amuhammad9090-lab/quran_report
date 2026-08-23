/// Data master sekolah. Sengaja disiapkan sebagai list (bukan singleton)
/// supaya arsitektur langsung siap multi-sekolah di masa depan walau saat
/// ini baru 1 entri (SMPIT Al Madinah Tanjungpinang).
class School {
  final String id;
  final String name;
  final String city;

  /// Path asset logo. Owner akan mengganti asset ini sendiri — jangan
  /// dianggap logo permanen, ini cuma placeholder yang gampang di-swap.
  final String? logo;

  const School({
    required this.id,
    required this.name,
    required this.city,
    this.logo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'logo': logo,
      };

  factory School.fromJson(Map<String, dynamic> json) => School(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        logo: json['logo'] as String?,
      );
}
