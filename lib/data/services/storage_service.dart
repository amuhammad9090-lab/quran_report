import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/access/access_scope.dart';
import '../../core/utils/app_config.dart';
import '../models/folder.dart';
import '../models/santri_record.dart';
import 'records_remote_source.dart';

/// Persistensi lokal record laporan & folder menggunakan Hive.
/// Hive tetap menjadi sumber utama data; Firestore ([RecordsRemoteSource])
/// hanya mirror / cloud backup.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const _boxName = 'santri_records';
  static const _folderBoxName = 'report_folders';

  // Box kecil penanda laporan yang BELUM terkonfirmasi ter-mirror ke Firestore, dipakai
  // syncAllToFirestore agar "Backup" cuma menulis ulang yang perlu. Key = id laporan,
  // value 'true'; [_pendingSeedKey] menandai migrasi sekali-jalan (bukan uuid, tak bentrok).
  static const _pendingBoxName = 'pending_sync_ids';
  static const _pendingSeedKey = '__seed_v1__';

  final RecordsRemoteSource _remote = const RecordsRemoteSource();

  late Box<String> _box;
  late Box<String> _folderBox;
  late Box<String> _pendingBox;

  // Penanda "pemulihan terakhir" per akun+mode (admin/guru), buat Pulihkan mode hemat. Isinya
  // jam SERVER (syncedAt terbesar yang pernah ditarik), bukan jam HP.
  static const _metaBoxName = 'restore_meta';
  late Box<String> _metaBox;

  Future<void> init() async {
    await Hive.initFlutter();

    _box = await Hive.openBox<String>(_boxName);
    _folderBox = await Hive.openBox<String>(_folderBoxName);
    _pendingBox = await Hive.openBox<String>(_pendingBoxName);
    _metaBox = await Hive.openBox<String>(_metaBoxName);

    // MIGRASI SEKALI JALAN: mirror fire-and-forget bisa gagal diam-diam di versi lama, jadi
    // sekali ini semua id lokal ditandai pending agar "Backup" pertama tetap jaring pengaman
    // PENUH; setelahnya pending-set murni incremental dan lokal (tanpa baca Firestore).
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

    // Tandai pending SEBELUM mirror — kalau mirror gagal (offline dll), id tetap
    // nyangkut dan otomatis ke-backup saat "Backup" manual dipencet.
    await _pendingBox.put(record.id, 'true');

    _mirrorRecord(record);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);

    // Sudah dihapus lokal — tidak ada lagi yang perlu di-backup untuk id ini.
    await _pendingBox.delete(id);

    _remote.mirrorRecordDelete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _folderBox.clear();
    // Data lokal kosong -> penanda pemulihan terakhir tidak berlaku lagi (pemulihan berikutnya
    // harus penuh, kalau tidak laporan lama tidak akan pernah balik).
    await _metaBox.clear();
  }

  String _cutoffKey(AccessScope? scope) =>
      'lastRestore:${scope?.user.id ?? '-'}:${(scope == null || scope.canSeeAll) ? 'admin' : 'guru'}';

  /// <-- BARU (skema per-guru nested): dipanggil di titik transisi auth yang SAMA PERSIS
  /// seperti RecordsProvider.updateScope()/ParentNotesProvider.updateScope() (lihat
  /// main.dart, login_screen.dart, profile_screen.dart, main_shell.dart) — set/kosongkan
  /// [currentGuruAccountId] (app_config.dart) supaya [RecordsRemoteSource] tahu subcollection
  /// `accounts/{accountId}/...` mana yang jadi milik sesi ini.
  void updateScope(AccessScope? scope) {
    currentGuruAccountId = scope?.user.id;
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

    _remote.mirrorFolder(folder);
  }

  Future<void> deleteFolder(
      String folderId,
      ) async {
    await _folderBox.delete(folderId);

    _remote.mirrorFolderDelete(folderId);

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

  // MIRROR LAPORAN KE FIRESTORE
  void _mirrorRecord(
      SantriRecord record,
      ) {
    _remote
        .mirrorRecord(record)
        // Sukses ke-mirror -> keluarkan dari antrian pending, biar "Backup"
        // berikutnya tidak menulis ulang laporan yang sama.
        .then((_) => _pendingBox.delete(record.id))
        .catchError((_) {});
  }

  /// Hapus rekap pekanan (Portal Ortu) milik 1 santri saat kartunya dihapus, supaya tak jadi
  /// dokumen yatim di Firestore. Dipanggil dari [RecordsProvider.deleteAllForSantri];
  /// fire-and-forget (gagal tidak menahan proses hapus lokal).
  Future<void> deleteWeeklyRecapsForSantri(String namaAnak) =>
      _remote.deleteWeeklyRecapsForSantri(namaAnak);

  /// SINKRONKAN KE FIRESTORE: hanya laporan "pending" ([_pendingBox]) yang ditulis ulang,
  /// sengaja TANPA membaca Firestore (hemat write, bukan tukar dengan read). Guru pembimbing
  /// dibatasi lewat [scope] ke kelas+halaqoh assignment-nya (mis. sisa "Mode Admin"); admin bebas.
  Future<int> syncAllToFirestore({AccessScope? scope}) async {
    // Pengawas read-only: tidak ada yang boleh dikirim ke cloud.
    if (scope != null && scope.isViewer) return 0;
    final pendingIds = _pendingBox.keys
        .cast<String>()
        .where((k) => k != _pendingSeedKey)
        .toSet();

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

      await _remote.pushRecords(chunk);

      // Sukses ke-commit -> keluarkan dari antrian pending.
      await _pendingBox.deleteAll(chunk.map((r) => r.id));

      success += chunk.length;
    }

    // Folder selalu full setiap kali — volumenya kecil, tak worth pending-set.
    // BUG FIX: dulu getAllFolders() ditulis APA ADANYA ke Firestore tanpa
    // discope, beda dari `eligible` di atas untuk records. Karena _folderBox
    // adalah SATU box lokal yang dipakai lintas akun (lihat catatan di
    // updateScope), kalau box itu pernah kecampur folder akun lain (mis. 2
    // akun guru pernah login gantian di device yang sama), "Backup" akun
    // manapun yang aktif ikut menuliskan ULANG folder akun lain itu ke
    // accounts/{accountId-nya-sendiri}/folders — itu penyebab folder guru
    // "kegabung" ke akun lain. Sekarang disaring dulu pakai scope yang
    // sama persis dengan scopeRecords di atas.
    final localFolders = getAllFolders();
    final folders = (scope != null && !scope.isAdmin)
        ? scope.scopeFolders(localFolders)
        : localFolders;

    if (folders.isNotEmpty) {
      await _remote.pushFolders(folders);
    }

    return success;
  }

  /// PULIHKAN LAPORAN DARI FIRESTORE. [incremental] = true -> mode hemat: hanya laporan yang masuk
  /// cloud SETELAH pemulihan terakhir (filter `syncedAt` di server, jadi dokumen lama tidak dibaca
  /// dan tidak ditagih). Otomatis jatuh ke pemulihan PENUH kalau belum ada penanda pemulihan
  /// terakhir atau data lokal kosong. Admin membaca per akun guru lewat [accountIds].
  Future<int> restoreFromFirestore({
    AccessScope? scope,
    List<String> accountIds = const [],
    bool incremental = false,
  }) async {
    final key = _cutoffKey(scope);
    DateTime? since;
    if (incremental && _box.isNotEmpty) {
      since = DateTime.tryParse(_metaBox.get(key) ?? '');
    }

    final docs = since == null
        ? await _remote.fetchRecords(scope: scope, accountIds: accountIds)
        // Mundur 5 menit sebagai pengaman selisih jam/penulisan hampir bersamaan; dokumen yang
        // terbaca dobel aman (dilewati oleh pengecekan versi di bawah).
        : await _remote.fetchRecordsSince(
            since.subtract(const Duration(minutes: 5)),
            scope: scope,
            accountIds: accountIds,
          );

    var restored = 0;
    DateTime? maxSyncedAt;

    for (final data in docs) {
      final syncedAt = RecordsRemoteSource.syncedAtOf(data);
      if (syncedAt != null && (maxSyncedAt == null || syncedAt.isAfter(maxSyncedAt))) {
        maxSyncedAt = syncedAt;
      }

      try {
        final cloudRecord =
        SantriRecord.fromJson(data);

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

    // Simpan penanda HANYA setelah semuanya sukses (kalau melempar di atas, penanda lama utuh).
    // Pemulihan penuh yang tidak menemukan satu pun `syncedAt` (semua data dari versi lama) memakai
    // "sekarang - 1 hari" sebagai titik awal, supaya pemulihan hemat berikutnya tidak mentok penuh.
    final newCutoff = maxSyncedAt ??
        (since == null ? DateTime.now().subtract(const Duration(days: 1)) : null);
    if (newCutoff != null) {
      final old = DateTime.tryParse(_metaBox.get(key) ?? '');
      if (old == null || newCutoff.isAfter(old)) {
        await _metaBox.put(key, newCutoff.toIso8601String());
      }
    }

    return restored;
  }

  // PULIHKAN FOLDER DARI FIRESTORE
  Future<int> restoreFoldersFromFirestore({AccessScope? scope, List<String> accountIds = const []}) async {
    final docs = await _remote.fetchFolders(scope: scope, accountIds: accountIds);

    var restored = 0;

    for (final doc in docs) {
      try {
        if (_folderBox.containsKey(doc.id)) {
          continue;
        }

        final cloudFolder =
        ReportFolder.fromJson(
          doc.data,
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