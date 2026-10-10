import '../../core/utils/text_utils.dart';

/// Data master satu santri — sumber "siapa saja yang ada", dipakai untuk
/// autocomplete di form laporan & untuk hitung "santri yang diampu" di
/// Profile. TIDAK menggantikan [SantriRecord] (laporan tetap berdiri
/// sendiri, identitas santri di laporan tetap teks bebas untuk backward
/// compatibility — lihat catatan di ACCESS_CONTROL.md).
class Student {
  final String id;
  final String nama;
  final String kelas;
  final String halaqoh;

  /// Opsional untuk future-proofing multi-sekolah. Data lama tanpa field
  /// ini tetap terbaca (null = sekolah default/tunggal).
  final String? schoolId;

  /// <-- BARU (skema per-guru nested, lihat firestore.rules): accountId guru pemegang
  /// [kelas]+[halaqoh] santri ini SAAT terakhir field ini ditulis (lihat
  /// ApiStudentRepository._resolveGuruAccountId) — dipakai Portal Ortu buat tahu harus baca
  /// `accounts/{accountId}/laporan|weeklyRecaps|parentNotes` yang MANA (lihat rencana
  /// "denormalisasi guruAccountId" di percakapan restrukturisasi Firestore). Null kalau
  /// belum pernah di-set (data lama sebelum field ini ada) ATAU kelas+halaqoh-nya belum
  /// dipegang guru mana pun saat itu di-set.
  final String? guruAccountId;

  /// <-- BARU: nama tampilan ([UserAccount.displayName]) guru pemegang
  /// [kelas]+[halaqoh] santri ini SAAT terakhir field ini ditulis — ditulis
  /// bebarengan dengan [guruAccountId] di ApiStudentRepository. Dipakai
  /// Portal Ortu buat nampilin "Guru Pembimbing" tanpa perlu baca dokumen
  /// `accounts/{accountId}` (yang memang tidak boleh dibaca Portal Ortu —
  /// lihat firestore.rules). Null dengan alasan yang sama seperti
  /// [guruAccountId] null.
  final String? guruNama;

  const Student({
    required this.id,
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    this.schoolId,
    this.guruAccountId,
    this.guruNama,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'kelas': kelas,
        'halaqoh': halaqoh,
        'schoolId': schoolId,
        'guruAccountId': guruAccountId,
        'guruNama': guruNama,
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        nama: json['nama'] as String,
        kelas: json['kelas'] as String,
        halaqoh: normalizeHalaqoh(json['halaqoh'] as String),
        schoolId: json['schoolId'] as String?,
        guruAccountId: json['guruAccountId'] as String?,
        guruNama: json['guruNama'] as String?,
      );
}
