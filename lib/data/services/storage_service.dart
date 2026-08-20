import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/santri_record.dart';

/// Persistensi lokal record laporan menggunakan Hive (Box<String>,
/// setiap value adalah JSON-encoded SantriRecord). Sengaja tidak pakai
/// TypeAdapter/codegen supaya tidak butuh build_runner.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _boxName = 'santri_records';
  late Box<String> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

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
  }
}
