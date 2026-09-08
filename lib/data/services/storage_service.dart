import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/access/access_scope.dart';
import '../../core/utils/app_config.dart';
import '../models/folder.dart';
import '../models/kelas_halaqoh.dart';
import '../models/santri_record.dart';

/// Persistensi lokal record laporan & folder menggunakan Hive.
/// Hive tetap menjadi sumber utama data.
/// Firestore digunakan sebagai mirror / cloud backup.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const _boxName = 'santri_records';
  static const _folderBoxName = 'report_folders';

  // <-- BARU: box lokal kecil buat nandain laporan mana yang BELUM
  // kekonfirmasi ke-mirror ke Firestore (dipakai syncAllToFirestore biar
  // "Backup" cuma nulis ulang yang beneran perlu, bukan semua laporan
  // tiap kali dipencet -- lihat catatan lengkap di syncAllToFirestore).
  // Key = id laporan, value cuma penanda 'true' (pola sama seperti
  // AppPrefsService yang juga pakai Box<String> buat flag sederhana).
  // Satu key khusus [_pendingSeedKey] dipakai buat nandain migrasi
  // sekali-jalan sudah dijalankan, formatnya sengaja beda dari id
  // laporan asli (yang berupa uuid) biar gak pernah tabrakan.
  static const _pendingBoxName = 'pending_sync_ids';
  static const _pendingSeedKey = '__seed_v1__';

  late Box<String> _box;
  late Box<String> _folderBox;
  late Box<String> _pendingBox;

  Future<void> init() async {
    await Hive.initFlutter();

    _box = await Hive.openBox<String>(_boxName);
    _folderBox = await Hive.openBox<String>(_folderBoxName);
    _pendingBox = await Hive.openBox<String>(_pendingBoxName);

    // MIGRASI SEKALI JALAN: device yang upgrade dari versi lama (sebelum
    // ada pending-set ini) belum tentu semua laporannya beneran sukses
    // ke-mirror ke Firestore -- mirror lama (& yang sekarang) fire-and-
    // forget, kalau gagal (mis. lagi offline pas nyimpen) gagalnya diam-
    // diam, tanpa retry/tracking. Supaya klik "Backup" PERTAMA KALI abis
    // update tetap jadi jaring pengaman PENUH (persis perilaku lama),
    // sekali ini doang semua id laporan lokal ditandai pending. Setelah
    // itu (`_pendingSeedKey` sudah ke-set), pending-set murni incremental
    // seperti biasa -- pure lokal, tidak butuh baca Firestore sama sekali.
    if (_pendingBox.get(_pendingSeedKey) == null) {
      final ids = getAll().map((r) => r.id);
      await _pendingBox.putAll({for (final id in ids) id: 'true'});
      await _pendingBox.put(_pendingSeedKey, 'true');
    }
  }

  // LAPORAN
  List<SantriRecord> getAll() {
    return _box.values
        .map(
          (raw) => SantriRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      ),
    )
        .toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  Future<void> upsert(SantriRecord record) async {
    await _box.put(
      record.id,
      jsonEncode(record.toJson()),
    );

    // Tandai pending SEBELUM nyoba mirror -- kalau mirror-nya gagal
    // (offline dll), id ini tetap nyangkut di sini dan otomatis jadi
    // antrian yang bakal ke-backup pas "Backup" manual dipencet.
    await _pendingBox.put(record.id, 'true');

    _mirrorToFirestore(record);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);

    // Laporan udah dihapus lokal -- gak ada lagi yang perlu di-backup
    // buat id ini, keluarin dari antrian pending kalau sempat masuk.
    await _pendingBox.delete(id);

    _mirrorDeleteToFirestore(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _folderBox.clear();
  }

  // FOLDER
  List<ReportFolder> getAllFolders() {
    return _folderBox.values
        .map(
          (raw) => ReportFolder.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      ),
    )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> upsertFolder(
      ReportFolder folder,
      ) async {
    await _folderBox.put(
      folder.id,
      jsonEncode(folder.toJson()),
    );

    _mirrorFolderToFirestore(folder);
  }

  Future<void> deleteFolder(
      String folderId,
      ) async {
    await _folderBox.delete(folderId);

    _mirrorFolderDeleteToFirestore(folderId);

    for (final r in getAll().where(
          (r) => r.folderId == folderId,
    )) {
      await upsert(
        r.copyWith(
          clearFolder: true,
        ),
      );
    }
  }

  // FIRESTORE MIRROR FOLDER
  void _mirrorFolderToFirestore(
      ReportFolder folder,
      ) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('reportFolders')
        .doc(folder.id)
        .set(folder.toJson())
        .catchError((_) {});
  }

  void _mirrorFolderDeleteToFirestore(
      String folderId,
      ) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('reportFolders')
        .doc(folderId)
        .delete()
        .catchError((_) {});
  }

  // FIRESTORE MIRROR LAPORAN
  void _mirrorToFirestore(
      SantriRecord record,
      ) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('santriRecords')
        .doc(record.id)
        .set(record.toJson())
        // Sukses ke-mirror -> keluarin dari antrian pending, biar
        // "Backup" berikutnya gak nulis ulang laporan yang sama lagi.
        .then((_) => _pendingBox.delete(record.id))
        .catchError((_) {});
  }

  void _mirrorDeleteToFirestore(
      String id,
      ) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('santriRecords')
        .doc(id)
        .delete()
        .catchError((_) {});
  }

  // FIRESTORE: HAPUS REKAP PEKANAN (PORTAL ORTU) MILIK 1 SANTRI
  // <-- BARU: sebelumnya dokumen `weeklyRecaps` (hasil tombol "Deploy" di
  // generate_rekap_pekanan_screen.dart, lihat WeeklyRecapDeployService)
  // tidak pernah dihapus sama sekali -- kartu santri di tab Laporan
  // dihapus (plus semua `santriRecords`-nya), tapi rekap pekanan yang
  // sudah kadung di-deploy ke Portal Ortu tetap nongkrong di Firestore
  // jadi dokumen "yatim" yang tidak sinkron lagi dengan sumbernya.
  // Dipanggil dari [RecordsProvider.deleteAllForSantri] biar ikut bersih.
  //
  // Query pakai `namaAnakLower` (bukan `namaAnak`) karena field ini yang
  // didenormalisasi lowercase khusus buat exact-match case-insensitive
  // (lihat komentar di WeeklyRecapDeployService) -- match seluruh pekan
  // milik santri itu sekaligus, bukan cuma 1 dokumen, karena 1 santri
  // bisa punya banyak dokumen `weeklyRecaps` (1 dokumen per pekan).
  //
  // Fire-and-forget (try/catch, bukan lempar exception) sama seperti
  // mirror lain di atas -- kalau ini gagal (mis. lagi offline), jangan
  // sampai bikin proses hapus kartu (Hive + santriRecords) yang sudah
  // jalan duluan jadi ketahan/gagal di UI.
  Future<void> deleteWeeklyRecapsForSantri(String namaAnak) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('schools')
          .doc(kSchoolId)
          .collection('weeklyRecaps')
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

  // SINKRONKAN SEMUA KE FIRESTORE
  // <-- BERUBAH: sebelumnya method ini nulis ULANG SEMUA laporan lokal
  // ke Firestore setiap kali dipencet, walau isinya sama persis kayak
  // yang sudah ada di cloud (mis. sudah ke-mirror otomatis lewat
  // upsert() satu-satu sebelumnya) -- boros writes tanpa alasan.
  // Sekarang cuma laporan yang statusnya masih "pending" (belum
  // kekonfirmasi ke-mirror -- lihat [_pendingBox], diisi upsert() &
  // dikosongin _mirrorToFirestore kalau sukses) yang ditulis ulang di
  // sini. Sengaja TIDAK membandingkan dengan cara nge-fetch isi Firestore
  // dulu (itu malah nuker penghematan writes dengan biaya reads) --
  // pending-set ini murni lokal.
  //
  // <-- BARU: parameter [scope]. Kalau guru pembimbing (non-admin),
  // pending di atas DIPERKETAT lagi ke laporan yang kelas+halaqoh-nya
  // masuk assignment dia -- lihat catatan lengkap di dalam fungsi.
  Future<int> syncAllToFirestore({AccessScope? scope}) async {
    final pendingIds = _pendingBox.keys
        .cast<String>()
        .where((k) => k != _pendingSeedKey)
        .toSet();

    // <-- BARU: kalau dipanggil dari device guru pembimbing (bukan
    // admin), backup dibatasi ke laporan yang kelas+halaqoh-nya cocok
    // assignment dia doang -- jaga-jaga kalau device ini KEBETULAN masih
    // nyimpen laporan di luar scope-nya secara lokal (mis. sisa dari
    // sesi "Mode Admin" yang sempat aktif terus dimatikan lagi, lihat
    // AccessScope.adminModeActive), device itu tidak ikut nge-backup
    // punya guru lain atas nama dia. Admin (atau scope null) tetap tidak
    // dibatasi, sama seperti sebelumnya.
    final localAll = getAll();
    final eligible = (scope != null && !scope.isAdmin)
        ? scope.scopeRecords(localAll)
        : localAll;

    final pending = pendingIds.isEmpty
        ? const <SantriRecord>[]
        : eligible.where((r) => pendingIds.contains(r.id)).toList();

    var success = 0;

    const batchSize = 400;

    for (
    var i = 0;
    i < pending.length;
    i += batchSize
    ) {
      final end = (i + batchSize > pending.length)
          ? pending.length
          : i + batchSize;

      final chunk = pending.sublist(
        i,
        end,
      );

      final batch = FirebaseFirestore.instance.batch();

      for (final record in chunk) {
        final ref = FirebaseFirestore.instance
            .collection('schools')
            .doc(kSchoolId)
            .collection('santriRecords')
            .doc(record.id);

        batch.set(
          ref,
          record.toJson(),
        );
      }

      await batch.commit().timeout(
        const Duration(seconds: 20),
      );

      // Sukses ke-commit -> keluarin dari antrian pending, biar "Backup"
      // berikutnya gak nulis ulang laporan yang sama lagi kalau memang
      // gak ada perubahan baru.
      await _pendingBox.deleteAll(chunk.map((r) => r.id));

      success += chunk.length;
    }

    // SINKRONKAN FOLDER (tetap full setiap kali -- volumenya kecil,
    // jumlah folder jauh lebih sedikit dari jumlah laporan, jadi gak
    // worth dioptimasi pending-set-nya juga -- lihat catatan audit)
    final folders = getAllFolders();

    if (folders.isNotEmpty) {
      final folderBatch =
      FirebaseFirestore.instance.batch();

      for (final folder in folders) {
        final ref = FirebaseFirestore.instance
            .collection('schools')
            .doc(kSchoolId)
            .collection('reportFolders')
            .doc(folder.id);

        folderBatch.set(
          ref,
          folder.toJson(),
        );
      }

      await folderBatch.commit().timeout(
        const Duration(seconds: 20),
      );
    }

    return success;
  }

  // PULIHKAN LAPORAN DARI FIRESTORE
  // <-- BERUBAH: sebelumnya fungsi ini narik SEMUA santriRecords satu
  // sekolah tanpa filter, baru difilter scope di client (device guru
  // pembimbing X ikut BACA -- dan bayar READ -- punya guru Y/Z juga,
  // cuma disembunyiin di level tampilan lewat AccessScope.scopeRecords()
  // pas render list). Sekarang guru pembimbing (non-admin) query LANGSUNG
  // discope di server pakai field turunan `kelasHalaqoh` (lihat
  // [SantriRecord.kelasHalaqohKey]) lewat `whereIn` per pasangan
  // kelas+halaqoh assignment-nya -- assignment TETAP diperlakukan sebagai
  // PASANGAN (bukan cross-product), sama persis semantiknya dengan
  // [AccessScope.canAccessRecord]. Admin (atau scope null) tetap full-get
  // seperti sebelumnya karena memang butuh akses global.
  //
  // Catatan kompatibilitas: dokumen lama yang ke-backup SEBELUM field
  // `kelasHalaqoh` ada tidak akan ke-match query whereIn di atas (field-
  // nya belum ada). Ini beres sendiri lewat flow existing "admin Pulihkan
  // (full, scope=null/admin) lalu Backup" -- yang otomatis nulis ulang
  // semua dokumen dengan field baru ikut ke-include begitu ada laporan
  // yang tersentuh (lihat catatan audit lengkap: gak butuh migrasi/script
  // terpisah).
  Future<int> restoreFromFirestore({AccessScope? scope}) async {
    final baseQuery = FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('santriRecords');

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    final scopedQuery = scope != null && !scope.isAdmin;

    if (scopedQuery) {
      final pairKeys = scope.user.assignments
          .map((a) => buildKelasHalaqohKey(a.kelas, a.halaqoh))
          .toSet()
          .toList();

      // Guru belum punya assignment sama sekali -> memang gak ada
      // laporan yang bisa/boleh direstore, jangan query (whereIn kosong
      // bakal dilempar Firestore sebagai error).
      if (pairKeys.isEmpty) return 0;

      // Firestore batasin maksimal 30 nilai per klausa `whereIn` -- di-
      // chunk biar tetap aman walau suatu saat 1 guru punya assignment
      // >30 pasang (kondisi sekolah sekarang jauh dari itu, ini jaga-jaga
      // doang, bukan over-engineering karena tetap query per-guru biasa).
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

    var restored = 0;

    for (final doc in docs) {
      try {
        final cloudRecord =
        SantriRecord.fromJson(doc.data());

        if (scope != null && !scope.canAccessRecord(cloudRecord)) {
          continue;
        }

        final localRaw =
        _box.get(cloudRecord.id);

        if (localRaw != null) {
          final localRecord =
          SantriRecord.fromJson(
            jsonDecode(localRaw)
            as Map<String, dynamic>,
          );

          final localTime =
              localRecord.editedAt ??
                  localRecord.createdAt ??
                  localRecord.tanggal;

          final cloudTime =
              cloudRecord.editedAt ??
                  cloudRecord.createdAt ??
                  cloudRecord.tanggal;

          if (!cloudTime.isAfter(localTime)) {
            continue;
          }
        }

        await _box.put(
          cloudRecord.id,
          jsonEncode(
            cloudRecord.toJson(),
          ),
        );

        restored++;
      } catch (_) {
        continue;
      }
    }

    return restored;
  }

  // PULIHKAN FOLDER DARI FIRESTORE
  Future<int> restoreFoldersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('reportFolders')
        .get()
        .timeout(
      const Duration(seconds: 20),
    );

    var restored = 0;

    for (final doc in snapshot.docs) {
      try {
        if (_folderBox.containsKey(doc.id)) {
          continue;
        }

        final cloudFolder =
        ReportFolder.fromJson(
          doc.data(),
        );

        await _folderBox.put(
          cloudFolder.id,
          jsonEncode(
            cloudFolder.toJson(),
          ),
        );

        restored++;
      } catch (_) {
        continue;
      }
    }

    return restored;
  }
}