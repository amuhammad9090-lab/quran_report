// <-- BARU (seluruh file)
//
// Model "Catatan dari Orang Tua" — arah kebalikan dari SantriRecord.catatan
// (yang isinya catatan GURU untuk orang tua). Ini dikirim ORANG TUA lewat
// Portal Ortu (project `quran_report_parent`) dan mendarat di koleksi
// Firestore `schools/{schoolId}/parentNotes`.
//
// App guru ini HANYA membaca koleksi ini + menandai `isRead` — tidak
// pernah menulis field lain (persis kebalikan dari SantriRecord, yang di
// app guru ini ditulis lokal dulu baru di-mirror; ParentNote ditulis
// LANGSUNG oleh Portal Ortu ke Firestore, app guru cuma dengar/baca).
// Lihat catatan arsitektur lengkap di
// `firestore_parent_note_repository.dart` (project Portal Ortu) dan
// `parent_note_service.dart` (file ini, sisi guru).
import '../../core/utils/text_utils.dart';

class ParentNote {
  final String id;
  final String studentId;
  final String namaAnak;
  final String kelas;
  final String halaqoh;

  /// uid akun guru pemilik laporan TERAKHIR santri ini saat catatan
  /// dikirim. Boleh null (santri belum pernah punya laporan) — TIDAK
  /// dipakai untuk scoping akses (app guru tetap scope by kelas+halaqoh,
  /// konsisten dengan AccessScope/SantriRecord, lihat catatan di
  /// [AccessScope]), murni informasi tambahan.
  final String? guruOwnerId;

  final String message;
  final DateTime? createdAt;

  /// True setelah salah satu guru yang berhak membaca kelas+halaqoh ini
  /// membuka notifikasinya (lihat ParentNoteService.markAsRead). Catatan
  /// ini bersifat BERSAMA per kelas+halaqoh (bukan per-guru), sama seperti
  /// SantriRecord — begitu 1 guru pembimbing kelas itu baca, dianggap
  /// "sudah dibaca" untuk guru lain yang juga mengampu kelas+halaqoh sama.
  final bool isRead;

  const ParentNote({
    required this.id,
    required this.studentId,
    required this.namaAnak,
    required this.kelas,
    required this.halaqoh,
    required this.message,
    this.guruOwnerId,
    this.createdAt,
    this.isRead = false,
  });

  /// [data] adalah hasil `doc.data()` Firestore MENTAH (Timestamp belum
  /// dikonversi) — konversi `createdAt` dilakukan di sini supaya model ini
  /// tidak perlu tahu soal Timestamp di tempat lain yang mungkin memakai
  /// model ini (mis. widget test tanpa Firestore).
  factory ParentNote.fromFirestore(String id, Map<String, dynamic> data, DateTime? createdAt) {
    return ParentNote(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      namaAnak: data['namaAnak'] as String? ?? '',
      kelas: data['kelas'] as String? ?? '',
      // Samain perlakuan sama SantriRecord.fromJson: normalisasi halaqoh
      // pas parsing (buang prefix "Halaqoh " kalau ada), biar tampilan
      // di kartu notifikasi konsisten format-nya sama kartu laporan biasa
      // yang guru udah biasa lihat (mis. "Halaqoh B" -> "B").
      halaqoh: normalizeHalaqoh(data['halaqoh'] as String? ?? ''),
      guruOwnerId: data['guruOwnerId'] as String?,
      message: data['message'] as String? ?? '',
      createdAt: createdAt,
      isRead: data['isRead'] as bool? ?? false,
    );
  }
}
