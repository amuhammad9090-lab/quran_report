import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/access/access_scope.dart';
import '../../core/utils/app_config.dart';
import '../models/folder.dart';
import '../models/kelas_halaqoh.dart';
import '../models/santri_record.dart';

/// Akses Firestore untuk laporan & folder (mirror/backup/restore). Hanya bicara ke
/// cloud: tidak menyentuh Hive dan tidak tahu antrian pending — itu urusan
/// [StorageService]. Struktur koleksi dan query sama persis dengan sebelum dipisah.
class RecordsRemoteSource {
  const RecordsRemoteSource();

  CollectionReference<Map<String, dynamic>> _col(String name) => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection(name);

  // --- Mirror satu-satu (fire-and-forget) ---

  /// Future mentah: pemanggil yang mengurus sukses/gagalnya (mis. menghapus id dari antrian pending).
  Future<void> mirrorRecord(SantriRecord record) =>
      _col('santriRecords').doc(record.id).set(record.toJson());

  void mirrorRecordDelete(String id) {
    _col('santriRecords').doc(id).delete().catchError((_) {});
  }

  void mirrorFolder(ReportFolder folder) {
    _col('reportFolders').doc(folder.id).set(folder.toJson()).catchError((_) {});
  }

  void mirrorFolderDelete(String folderId) {
    _col('reportFolders').doc(folderId).delete().catchError((_) {});
  }

  /// Hapus semua dokumen `weeklyRecaps` (rekap yang di-"Deploy" ke Portal Ortu) milik santri
  /// [namaAnak], lewat field `namaAnakLower` (exact-match case-insensitive, lihat
  /// WeeklyRecapDeployService). Fire-and-forget: gagal (mis. offline) tidak boleh menahan UI.
  Future<void> deleteWeeklyRecapsForSantri(String namaAnak) async {
    try {
      final query = await _col('weeklyRecaps')
          .where(
            'namaAnakLower',
            isEqualTo: namaAnak.trim().toLowerCase(),
          )
          .get()
          .timeout(const Duration(seconds: 20));

      if (query.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit().timeout(const Duration(seconds: 20));
    } catch (_) {

    }
  }

  // --- Backup (tulis massal) ---

  /// Tulis [records] dalam SATU batch (pemanggil membatasi ukuran chunk-nya).
  Future<void> pushRecords(List<SantriRecord> records) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final record in records) {
      batch.set(
        _col('santriRecords').doc(record.id),
        record.toJson(),
      );
    }

    await batch.commit().timeout(
      const Duration(seconds: 20),
    );
  }

  Future<void> pushFolders(List<ReportFolder> folders) async {
    final folderBatch = FirebaseFirestore.instance.batch();

    for (final folder in folders) {
      folderBatch.set(
        _col('reportFolders').doc(folder.id),
        folder.toJson(),
      );
    }

    await folderBatch.commit().timeout(
      const Duration(seconds: 20),
    );
  }

  // --- Restore (baca) ---

  /// Data mentah `santriRecords`. Guru pembimbing di-query di server lewat `whereIn` `kelasHalaqoh`
  /// per PASANGAN assignment-nya (seperti [AccessScope.canAccessRecord]), admin/scope null full-get;
  /// dokumen lama tanpa field itu beres lewat alur "admin Pulihkan lalu Backup".
  Future<List<Map<String, dynamic>>> fetchRecords({AccessScope? scope}) async {
    final baseQuery = _col('santriRecords');

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    final scopedQuery = scope != null && !scope.isAdmin;

    if (scopedQuery) {
      final pairKeys = scope.user.assignments
          .map((a) => buildKelasHalaqohKey(a.kelas, a.halaqoh))
          .toSet()
          .toList();

      // Guru belum punya assignment -> tidak ada yang boleh direstore; jangan query
      // (whereIn kosong dilempar Firestore sebagai error).
      if (pairKeys.isEmpty) return const [];

      // Firestore membatasi 30 nilai per `whereIn`; di-chunk sebagai jaga-jaga
      // kalau satu guru punya assignment >30 pasang.
      const chunkSize = 30;
      for (var i = 0; i < pairKeys.length; i += chunkSize) {
        final end = (i + chunkSize > pairKeys.length) ? pairKeys.length : i + chunkSize;
        final chunkSnapshot = await baseQuery
            .where('kelasHalaqoh', whereIn: pairKeys.sublist(i, end))
            .get()
            .timeout(const Duration(seconds: 20));
        docs.addAll(chunkSnapshot.docs);
      }
    } else {
      final snapshot = await baseQuery.get().timeout(
        const Duration(seconds: 20),
      );
      docs.addAll(snapshot.docs);
    }

    return docs.map((d) => d.data()).toList();
  }

  /// Dokumen `reportFolders` mentah (id dokumen + datanya).
  Future<List<({String id, Map<String, dynamic> data})>> fetchFolders() async {
    final snapshot = await _col('reportFolders').get().timeout(
      const Duration(seconds: 20),
    );

    return snapshot.docs.map((d) => (id: d.id, data: d.data())).toList();
  }
}
