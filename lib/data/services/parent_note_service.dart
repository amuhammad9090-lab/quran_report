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
///
/// <-- BERUBAH (audit optimasi Firestore read): dulu HANYA ada [watchAll]
/// (baca SELURUH koleksi parentNotes, lalu di-filter per kelas+halaqoh di
/// [ParentNotesProvider] secara in-memory) — dipakai juga untuk guru,
/// yang berarti tiap guru diam-diam berlangganan (dan membaca) catatan
/// SEMUA kelas+halaqoh di sekolah, bukan cuma miliknya. Sekarang guru
/// pakai [watchForPair] (Firestore-side filtering, exact kelas+halaqoh,
/// satu listener per assignment — lihat [ParentNotesProvider._resubscribe]
/// untuk cara gabung beberapa assignment). [watchAll] TETAP dipakai HANYA
/// untuk admin (akses global memang seharusnya begitu).
class ParentNoteService {
  ParentNoteService._();
  static final ParentNoteService instance = ParentNoteService._();

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('parentNotes');

  ParentNote _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['createdAt'];
    return ParentNote.fromFirestore(
      doc.id,
      data,
      ts is Timestamp ? ts.toDate() : null,
    );
  }

  /// Stream SEMUA catatan, TIDAK di-scope — HANYA untuk admin (akses
  /// global, lihat [AccessScope.isAdmin]). Guru TIDAK BOLEH lagi memakai
  /// ini, lihat [watchForPair]. Diurutkan terbaru dulu. Kalau Firestore
  /// belum ke-setup / device offline, stream ini mengeluarkan error lewat
  /// `handleError` di provider — TIDAK boleh bikin app guru crash cuma
  /// gara-gara fitur notifikasi ini gagal.
  Stream<List<ParentNote>> watchAll() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(_fromDoc).toList(),
        );
  }

  /// <-- BARU: Stream catatan untuk SATU pasangan kelas+halaqoh EXACT —
  /// dipakai guru pembimbing (satu listener per assignment yang
  /// dipunyainya, lihat [ParentNotesProvider._resubscribe]). Filtering
  /// dilakukan di sisi Firestore (bukan diambil semua lalu difilter di
  /// Flutter), jadi guru yang hanya mengampu 1-3 kelas+halaqoh HANYA
  /// membaca dokumen yang memang miliknya.
  ///
  /// Sengaja TIDAK pakai `.orderBy('createdAt')` di sini (supaya tidak
  /// wajib composite index kelas+halaqoh+createdAt) -- penggabungan &
  /// pengurutan akhir lintas-pasangan dilakukan di
  /// [ParentNotesProvider] setelah semua listener pasangan digabung.
  Stream<List<ParentNote>> watchForPair(String kelas, String halaqoh) {
    return _col
        .where('kelas', isEqualTo: kelas)
        .where('halaqoh', isEqualTo: halaqoh)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  /// Tandai satu catatan sudah dibaca. Fire-and-forget (pola sama seperti
  /// `_mirrorToFirestore` di StorageService) — kalau gagal (offline dll),
  /// badge/notifikasi cukup tetap muncul lagi lain kali, tidak fatal.
  Future<void> markAsRead(String noteId) {
    return _col.doc(noteId).update({'isRead': true}).catchError((_) {});
  }

  /// Sembunyikan (swipe/"Hapus Semua") atau kembalikan (Undo) satu
  /// catatan dari daftar Notifikasi -- update field `dismissed` doang,
  /// TIDAK pernah delete dokumennya. Sama fire-and-forget seperti
  /// [markAsRead] -- kalau gagal, catatan cukup nongol lagi nanti,
  /// bukan error fatal.
  Future<void> setDismissed(String noteId, bool value) {
    return _col.doc(noteId).update({'dismissed': value}).catchError((_) {});
  }
}
