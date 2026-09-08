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
// <-- BARU: helper key gabungan kelas+halaqoh, dipakai buat query
// Firestore ter-scope (whereIn) di StorageService.restoreFromFirestore
// & ParentNoteService — BUKAN dasar keputusan akses (itu tetap exact
// match kelas+halaqoh lewat AccessScope/KelasHalaqoh.==, sama seperti
// sebelumnya). Satu tempat doang biar format key-nya konsisten di semua
// pemakai (model laporan, model catatan ortu, assignment guru).
String buildKelasHalaqohKey(String kelas, String halaqoh) => '$kelas|$halaqoh';

class KelasHalaqoh {
  final String kelas;
  final String halaqoh;
  const KelasHalaqoh({required this.kelas, required this.halaqoh});

  String get label => '$kelas • $halaqoh';

  /// Key gabungan buat query Firestore (lihat [buildKelasHalaqohKey] di atas).
  String get key => buildKelasHalaqohKey(kelas, halaqoh);

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
