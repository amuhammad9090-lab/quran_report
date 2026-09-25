import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/access/access_scope.dart';
import '../../core/utils/app_config.dart';
import '../models/folder.dart';
import '../models/santri_record.dart';

/// Akses Firestore untuk laporan & folder (mirror/backup/restore). Hanya bicara ke
/// cloud: tidak menyentuh Hive dan tidak tahu antrian pending — itu urusan
/// [StorageService].
///
/// <-- BERUBAH (skema per-guru nested, lihat firestore.rules): dulu semua
/// data ini flat di `schools/{id}/santriRecords` & `schools/{id}/reportFolders`,
/// guru pembimbing di-scope lewat `whereIn` per pasangan kelas+halaqoh
/// assignment-nya (di-chunk 30 per query). Sekarang data itu nested fisik
/// di bawah `schools/{id}/accounts/{accountId}/laporan` & `.../folders` —
/// [currentGuruAccountId] (lihat app_config.dart, diisi titik transisi
/// auth yang sama seperti RecordsProvider.updateScope()) sudah CUKUP jadi
/// path guru yang sedang login, TANPA whereIn/chunking sama sekali,
/// karena satu guru cuma pernah punya SATU subcollection: miliknya
/// sendiri. Admin (scope null / scope.isAdmin) baca lintas-guru lewat
/// `collectionGroup` alih-alih baca 1 koleksi flat.
class RecordsRemoteSource {
  const RecordsRemoteSource();

  DocumentReference<Map<String, dynamic>>? _myAccountDoc() {
    final id = currentGuruAccountId;
    if (id == null) return null;
    return FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('accounts')
        .doc(id);
  }

  // --- Mirror satu-satu (fire-and-forget) ---

  /// Future mentah: pemanggil yang mengurus sukses/gagalnya (mis. menghapus id dari antrian pending).
  /// Kalau [currentGuruAccountId] belum ke-set (mis. dipanggil di celah sebelum login benar-benar
  /// selesai), sengaja gagal dengan StateError alih-alih diam-diam salah tempat — pemanggil
  /// ([StorageService._mirrorRecord]) sudah fire-and-forget + catchError, jadi aman.
  Future<void> mirrorRecord(SantriRecord record) {
    final doc = _myAccountDoc();
    if (doc == null) return Future.error(StateError('currentGuruAccountId belum di-set'));
    return doc.collection('laporan').doc(record.id).set(record.toJson());
  }

  void mirrorRecordDelete(String id) {
    _myAccountDoc()?.collection('laporan').doc(id).delete().catchError((_) {});
  }

  void mirrorFolder(ReportFolder folder) {
    _myAccountDoc()?.collection('folders').doc(folder.id).set(folder.toJson()).catchError((_) {});
  }

  void mirrorFolderDelete(String folderId) {
    _myAccountDoc()?.collection('folders').doc(folderId).delete().catchError((_) {});
  }

  /// Hapus semua dokumen `weeklyRecaps` (rekap yang di-"Deploy" ke Portal Ortu) milik santri
  /// [namaAnak], lewat field `namaAnakLower` (exact-match case-insensitive, lihat
  /// WeeklyRecapDeployService). Fire-and-forget: gagal (mis. offline) tidak boleh menahan UI.
  Future<void> deleteWeeklyRecapsForSantri(String namaAnak) async {
    final doc = _myAccountDoc();
    if (doc == null) return;
    try {
      final query = await doc
          .collection('weeklyRecaps')
          .where(
            'namaAnakLower',
            isEqualTo: namaAnak.trim().toLowerCase(),
          )
          .get()
          .timeout(const Duration(seconds: 20));

      if (query.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();

      for (final d in query.docs) {
        batch.delete(d.reference);
      }

      await batch.commit().timeout(const Duration(seconds: 20));
    } catch (_) {

    }
  }

  // --- Backup (tulis massal) ---

  /// Tulis [records] dalam SATU batch (pemanggil membatasi ukuran chunk-nya), ke subcollection
  /// `laporan` milik [currentGuruAccountId].
  Future<void> pushRecords(List<SantriRecord> records) async {
    final doc = _myAccountDoc();
    if (doc == null) throw StateError('currentGuruAccountId belum di-set');
    final batch = FirebaseFirestore.instance.batch();
    final col = doc.collection('laporan');

    for (final record in records) {
      batch.set(col.doc(record.id), record.toJson());
    }

    await batch.commit().timeout(
      const Duration(seconds: 20),
    );
  }

  Future<void> pushFolders(List<ReportFolder> folders) async {
    final doc = _myAccountDoc();
    if (doc == null) throw StateError('currentGuruAccountId belum di-set');
    final folderBatch = FirebaseFirestore.instance.batch();
    final col = doc.collection('folders');

    for (final folder in folders) {
      folderBatch.set(col.doc(folder.id), folder.toJson());
    }

    await folderBatch.commit().timeout(
      const Duration(seconds: 20),
    );
  }

  // --- Restore (baca) ---

  /// Data mentah `laporan`. Guru pembimbing (scope non-admin) baca LANGSUNG subcollection
  /// miliknya sendiri (tidak perlu query/chunking apa pun lagi -- semua isinya memang miliknya).
  /// Admin/scope null baca lintas-guru lewat `collectionGroup('laporan')`.
  Future<List<Map<String, dynamic>>> fetchRecords({AccessScope? scope}) async {
    final isAdmin = scope == null || scope.isAdmin;

    if (isAdmin) {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('laporan')
          .get()
          .timeout(const Duration(seconds: 20));
      return snapshot.docs.map((d) => d.data()).toList();
    }

    final doc = _myAccountDoc();
    if (doc == null) return const [];

    final snapshot = await doc.collection('laporan').get().timeout(
      const Duration(seconds: 20),
    );

    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// Dokumen `folders` mentah (id dokumen + datanya). Sama seperti [fetchRecords]: guru baca
  /// subcollection sendiri, admin lewat `collectionGroup`.
  Future<List<({String id, Map<String, dynamic> data})>> fetchFolders({AccessScope? scope}) async {
    final isAdmin = scope == null || scope.isAdmin;

    if (isAdmin) {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('folders')
          .get()
          .timeout(const Duration(seconds: 20));
      return snapshot.docs.map((d) => (id: d.id, data: d.data())).toList();
    }

    final doc = _myAccountDoc();
    if (doc == null) return const [];

    final snapshot = await doc.collection('folders').get().timeout(
      const Duration(seconds: 20),
    );

    return snapshot.docs.map((d) => (id: d.id, data: d.data())).toList();
  }
}
