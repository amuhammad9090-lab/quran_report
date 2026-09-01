import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- BARU
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/utils/app_config.dart'; // <-- BARU
import '../models/santri_record.dart';
import '../models/folder.dart';

/// Persistensi lokal record laporan & folder menggunakan Hive (Box<String>,
/// setiap value adalah JSON-encoded object). Sengaja tidak pakai
/// TypeAdapter/codegen supaya tidak butuh build_runner.
///
/// <-- BARU: Hive TETAP sumber utama — app tetap 100% jalan offline sama
/// seperti sebelumnya. Firestore murni mirror tambahan, dibungkus
/// try/catch (lewat .catchError) supaya kalau gagal (device offline,
/// Firestore belum di-setup, dll) upsert/delete yang dipakai UI TIDAK
/// PERNAH gagal gara-gara Firestore.
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
    await _box.put(record.id, jsonEncode(record.toJson())); // <-- TIDAK BERUBAH, tetap paling depan
    _mirrorToFirestore(record); // <-- BARU — fire-and-forget
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    _mirrorDeleteToFirestore(id); // <-- BARU
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _folderBox.clear();
  }

  // --- Folder --- (TIDAK diubah — murni struktur organisasi guru, tidak
  // relevan buat Portal Orang Tua, jadi tidak di-mirror)
  List<ReportFolder> getAllFolders() {
    return _folderBox.values
        .map((raw) => ReportFolder.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> upsertFolder(ReportFolder folder) async {
    await _folderBox.put(folder.id, jsonEncode(folder.toJson()));
  }

  Future<void> deleteFolder(String folderId) async {
    await _folderBox.delete(folderId);
    for (final r in getAll().where((r) => r.folderId == folderId)) {
      await upsert(r.copyWith(clearFolder: true));
    }
  }

  // <-- BARU: 2 method di bawah semuanya baru. Sengaja "fire-and-forget"
  // (tidak di-await pemanggilnya, tidak melempar exception) supaya guru
  // simpan laporan TETAP INSTAN walau device offline/Firestore lagi
  // bermasalah — laporan tetap aman di Hive, sync ke Firestore nyusul
  // kapan saja koneksi ada.
  void _mirrorToFirestore(SantriRecord record) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('santriRecords')
        .doc(record.id)
        .set(record.toJson())
        .catchError((_) {}); // diam-diam gagal, Hive tetap sumber kebenaran
  }

  void _mirrorDeleteToFirestore(String id) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('santriRecords')
        .doc(id)
        .delete()
        .catchError((_) {});
  }

  // <-- BARU: seluruh method ini. Dorong SEMUA laporan yang ada di Hive
  // ke Firestore sekaligus — dipakai tombol "Sinkronkan ke Cloud" di
  // Pengaturan. Dibutuhkan khusus buat laporan LAMA yang dibuat SEBELUM
  // mirror otomatis ([_mirrorToFirestore]) aktif, karena mirror itu
  // cuma nempel di aksi upsert/delete BARU, bukan otomatis jalan buat
  // data lama yang udah ada duluan di Hive.
  //
  // Pakai batched write (max 400 per batch, di bawah limit Firestore
  // 500) biar aman buat ratusan/ribuan laporan sekaligus tanpa bikin
  // ratusan network request terpisah. Beda dari mirror biasa, di sini
  // SENGAJA di-throw kalau gagal (bukan fire-and-forget) — ini aksi
  // manual yang guru tekan sendiri, jadi guru perlu tau kalau gagal,
  // bukan diam-diam kayak upsert/delete harian.
  Future<int> syncAllToFirestore() async {
    final all = getAll();
    var success = 0;
    const batchSize = 400;

    for (var i = 0; i < all.length; i += batchSize) {
      final end = (i + batchSize > all.length) ? all.length : i + batchSize;
      final chunk = all.sublist(i, end);
      final batch = FirebaseFirestore.instance.batch();
      for (final record in chunk) {
        final ref = FirebaseFirestore.instance
            .collection('schools')
            .doc(kSchoolId)
            .collection('santriRecords')
            .doc(record.id);
        batch.set(ref, record.toJson());
      }
      await batch.commit(); // <-- kalau ini throw, caller yang nangkep
      success += chunk.length;
    }
    return success;
  }
}
