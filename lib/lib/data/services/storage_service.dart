import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/santri_record.dart';
import '../models/folder.dart';

/// Persistensi lokal record laporan & folder menggunakan Hive (Box<String>,
/// setiap value adalah JSON-encoded object). Sengaja tidak pakai
/// TypeAdapter/codegen supaya tidak butuh build_runner.
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

  // --- Laporan ---
  List<SantriRecord> getAll() {
    return _box.values
        .map((raw) => SantriRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  Future<void> upsert(SantriRecord record) async {
    await _box.put(record.id, jsonEncode(record.toJson()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _folderBox.clear();
  }

  // --- Folder ---
  List<ReportFolder> getAllFolders() {
    return _folderBox.values
        .map((raw) => ReportFolder.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> upsertFolder(ReportFolder folder) async {
    await _folderBox.put(folder.id, jsonEncode(folder.toJson()));
  }

  /// Hapus folder. Laporan yang tadinya ada di dalamnya TIDAK ikut terhapus
  /// — hanya dikeluarkan dari folder (folderId di-null-kan) supaya tetap
  /// muncul lagi di section "Laporan".
  Future<void> deleteFolder(String folderId) async {
    await _folderBox.delete(folderId);
    for (final r in getAll().where((r) => r.folderId == folderId)) {
      await upsert(r.copyWith(clearFolder: true));
    }
  }
}
