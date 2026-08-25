import '../../core/utils/text_utils.dart';

/// Satu unit assignment: kelas TERTENTU + halaqoh TERTENTU, sebagai
/// PASANGAN yang tidak boleh dipisah.
///
/// PENTING (temuan dari data Excel asli): satu guru bisa punya beberapa
/// assignment, tapi tiap assignment adalah pasangan kelas+halaqoh
/// spesifik — BUKAN "kelas manapun dari daftar A" × "halaqoh manapun
/// dari daftar B". Contoh nyata: guru "adir" mengampu
/// (VII Jeddah, Halaqoh B), (VIII Baghdad, Halaqoh C), dst — dia TIDAK
/// mengampu (VII Jeddah, Halaqoh C) walau "VII Jeddah" dan "Halaqoh C"
/// sama-sama ada di daftar kelas/halaqoh-nya kalau disimpan sebagai dua
/// list terpisah. Makanya di model ini kelas+halaqoh SELALU digandeng
/// satu unit, biar AccessScope gak salah kasih akses ke kombinasi yang
/// gak pernah di-assign.
class KelasHalaqoh {
  final String kelas;
  final String halaqoh;
  const KelasHalaqoh({required this.kelas, required this.halaqoh});

  String get label => '$kelas • $halaqoh';

  Map<String, dynamic> toJson() => {'kelas': kelas, 'halaqoh': halaqoh};

  factory KelasHalaqoh.fromJson(Map<String, dynamic> json) => KelasHalaqoh(
        kelas: json['kelas'] as String,
        halaqoh: normalizeHalaqoh(json['halaqoh'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is KelasHalaqoh && other.kelas == kelas && other.halaqoh == halaqoh;

  @override
  int get hashCode => Object.hash(kelas, halaqoh);

  @override
  String toString() => label;
}
