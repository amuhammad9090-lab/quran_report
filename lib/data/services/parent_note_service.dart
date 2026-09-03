// <-- BARU (seluruh file)
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/app_config.dart';
import '../models/parent_note.dart';

/// Baca (live) + tandai-dibaca koleksi `schools/{schoolId}/parentNotes` —
/// tempat Portal Ortu (project `quran_report_parent`) menaruh "Catatan
/// untuk Guru" yang dikirim orang tua. Lihat
/// `firestore_parent_note_repository.dart` di project Portal Ortu untuk
/// skema dokumen & aturan keamanannya.
///
/// Berbeda dari [StorageService] (yang Hive-lokal-dulu-baru-mirror), di
/// sini Firestore adalah SATU-SATUNYA sumber data — tidak ada salinan
/// lokal permanen, karena catatan ini murni milik Portal Ortu, app guru
/// cuma menumpang baca. Makanya dipakai `snapshots()` (live stream), bukan
/// `get()` sekali jalan, supaya notifikasi baru muncul TANPA guru perlu
/// pull-to-refresh atau buka ulang app.
class ParentNoteService {
  ParentNoteService._();
  static final ParentNoteService instance = ParentNoteService._();

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('parentNotes');

  /// Stream SEMUA catatan (belum di-scope kelas/halaqoh — itu tugas
  /// [ParentNotesProvider], sama seperti [AccessScope.scopeRecords] yang
  /// men-scope SantriRecord di memori, bukan di query). Diurutkan terbaru
  /// dulu. Kalau Firestore belum ke-setup / device offline, stream ini
  /// mengeluarkan error lewat `handleError` di provider — TIDAK boleh
  /// bikin app guru crash cuma gara-gara fitur notifikasi ini gagal.
  Stream<List<ParentNote>> watchAll() {
    return _col.orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final ts = data['createdAt'];
        return ParentNote.fromFirestore(
          doc.id,
          data,
          ts is Timestamp ? ts.toDate() : null,
        );
      }).toList();
    });
  }

  /// Tandai satu catatan sudah dibaca. Fire-and-forget (pola sama seperti
  /// `_mirrorToFirestore` di StorageService) — kalau gagal (offline dll),
  /// badge/notifikasi cukup tetap muncul lagi lain kali, tidak fatal.
  Future<void> markAsRead(String noteId) {
    return _col.doc(noteId).update({'isRead': true}).catchError((_) {});
  }
}
