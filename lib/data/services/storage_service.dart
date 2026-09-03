import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/app_config.dart';
import '../models/folder.dart';
import '../models/santri_record.dart';

/// Persistensi lokal record laporan & folder menggunakan Hive.
/// Hive tetap menjadi sumber utama data.
///
/// Firestore digunakan sebagai mirror / cloud backup.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const _boxName = 'santri_records';
  static const _folderBoxName = 'report_folders';

  late Box<String> _box;
  late Box<String> _folderBox;

  Future<void> init() async {
    await Hive.initFlutter();

    _box = await Hive.openBox<String>(_boxName);
    _folderBox = await Hive.openBox<String>(_folderBoxName);
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

    _mirrorToFirestore(record);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);

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

  // SINKRONKAN SEMUA KE FIRESTORE
  Future<int> syncAllToFirestore() async {
    final all = getAll();

    var success = 0;

    const batchSize = 400;

    for (
    var i = 0;
    i < all.length;
    i += batchSize
    ) {
      final end = (i + batchSize > all.length)
          ? all.length
          : i + batchSize;

      final chunk = all.sublist(
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

      success += chunk.length;
    }

    // SINKRONKAN FOLDER
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
  Future<int> restoreFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('santriRecords')
        .get()
        .timeout(
      const Duration(seconds: 20),
    );

    var restored = 0;

    for (final doc in snapshot.docs) {
      try {
        final cloudRecord =
        SantriRecord.fromJson(doc.data());

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