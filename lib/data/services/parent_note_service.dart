import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/app_config.dart';
import '../models/parent_note.dart';

/// Baca (live) + tandai-dibaca catatan orang tua — tempat Portal Ortu
/// (project `quran_report_parent`) menaruh "Catatan untuk Guru" yang
/// dikirim orang tua. Lihat `firestore_parent_note_repository.dart` di
/// project Portal Ortu untuk skema dokumen & aturan keamanannya.
///
/// Berbeda dari [StorageService] (yang Hive-lokal-dulu-baru-mirror), di
/// sini Firestore adalah SATU-SATUNYA sumber data — tidak ada salinan
/// lokal permanen, karena catatan ini murni milik Portal Ortu, app guru
/// cuma menumpang baca. Makanya dipakai `snapshots()` (live stream), bukan
/// `get()` sekali jalan, supaya notifikasi baru muncul TANPA guru perlu
/// pull-to-refresh atau buka ulang app.
///
/// <-- BERUBAH (skema per-guru nested, lihat firestore.rules): dulu semua
/// catatan flat di `schools/{id}/parentNotes`, guru pembimbing dipersempit
/// lewat query Firestore-side per pasangan kelas+halaqoh ([watchForPair]),
/// TAPI itu murni optimasi baca -- rules lama (`isGuruApp()`) tetap
/// mengizinkan SIAPA PUN guru ke-whitelist membaca/menulis SELURUH
/// koleksi kalau mau (lihat catatan lama yang sudah tidak berlaku, dulu
/// ada di sini). Sekarang catatan nested fisik di bawah
/// `schools/{id}/accounts/{accountId}/parentNotes` -- isolasinya
/// STRUKTURAL (per path), bukan cuma "query yang dipersempit tapi rules
/// tetap longgar". [watchForPair] tetap query per kelas+halaqoh (guru bisa
/// punya lebih dari satu assignment), cuma sekarang di DALAM subcollection
/// miliknya sendiri, bukan lagi jaminan keamanan semu.
class ParentNoteService {
  ParentNoteService._();
  static final ParentNoteService instance = ParentNoteService._();

  CollectionReference<Map<String, dynamic>> _colFor(String accountId) => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('accounts')
      .doc(accountId)
      .collection('parentNotes');

  ParentNote _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['createdAt'];
    // Path: schools/{schoolId}/accounts/{accountId}/parentNotes/{noteId} --
    // .parent = collection `parentNotes`, .parent.parent = dokumen `accounts/{accountId}`.
    final accountId = doc.reference.parent.parent!.id;
    return ParentNote.fromFirestore(
      doc.id,
      data,
      ts is Timestamp ? ts.toDate() : null,
      accountId: accountId,
    );
  }

  /// Stream SEMUA catatan lintas-guru, HANYA untuk admin (akses global,
  /// lihat [AccessScope.isAdmin]) -- lewat `collectionGroup` karena
  /// datanya sekarang tersebar di banyak subcollection `accounts/*/parentNotes`.
  /// Diurutkan terbaru dulu. Kalau Firestore belum ke-setup / device
  /// offline, stream ini mengeluarkan error lewat `handleError` di
  /// provider — TIDAK boleh bikin app guru crash cuma gara-gara fitur
  /// notifikasi ini gagal.
  Stream<List<ParentNote>> watchAll() {
    return FirebaseFirestore.instance
        .collectionGroup('parentNotes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  /// Stream catatan untuk SATU pasangan kelas+halaqoh EXACT, di dalam
  /// subcollection milik [accountId] (guru pembimbing yang sedang login —
  /// lihat [ParentNotesProvider._resubscribe], satu listener per
  /// assignment yang dipunyainya).
  ///
  /// Sengaja TIDAK pakai `.orderBy('createdAt')` di sini (supaya tidak
  /// wajib composite index kelas+halaqoh+createdAt) -- penggabungan &
  /// pengurutan akhir lintas-pasangan dilakukan di
  /// [ParentNotesProvider] setelah semua listener pasangan digabung.
  Stream<List<ParentNote>> watchForPair(String accountId, String kelas, String halaqoh) {
    return _colFor(accountId)
        .where('kelas', isEqualTo: kelas)
        .where('halaqoh', isEqualTo: halaqoh)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  /// Tandai satu catatan sudah dibaca. Fire-and-forget (pola sama seperti
  /// `_mirrorToFirestore` di StorageService) — kalau gagal (offline dll),
  /// badge/notifikasi cukup tetap muncul lagi lain kali, tidak fatal.
  Future<void> markAsRead(String accountId, String noteId) {
    return _colFor(accountId).doc(noteId).update({'isRead': true}).catchError((_) {});
  }

  /// Sembunyikan (swipe/"Hapus Semua") atau kembalikan (Undo) satu
  /// catatan dari daftar Notifikasi -- update field `dismissed` doang,
  /// TIDAK pernah delete dokumennya. Sama fire-and-forget seperti
  /// [markAsRead] -- kalau gagal, catatan cukup nongol lagi nanti,
  /// bukan error fatal.
  Future<void> setDismissed(String accountId, String noteId, bool value) {
    return _colFor(accountId).doc(noteId).update({'dismissed': value}).catchError((_) {});
  }
}
