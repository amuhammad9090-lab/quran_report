import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/folder.dart';
import '../data/services/storage_service.dart';

/// State management daftar folder laporan.
class FoldersProvider extends ChangeNotifier {
  List<ReportFolder> _all = [];

  List<ReportFolder> get all => _all;

  Future<void> load() async {
    _all = StorageService.instance.getAllFolders();
    notifyListeners();
  }

  ReportFolder? byId(String id) {
    for (final f in _all) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<ReportFolder> create(String nama) async {
    final folder = ReportFolder(
      id: const Uuid().v4(),
      nama: nama.trim(),
      createdAt: DateTime.now(),
    );
    await StorageService.instance.upsertFolder(folder);
    await load();
    return folder;
  }

  Future<void> rename(String id, String namaBaru) async {
    final existing = byId(id);
    if (existing == null) return;
    await StorageService.instance.upsertFolder(existing.copyWith(nama: namaBaru.trim()));
    await load();
  }

  Future<void> delete(String id) async {
    await StorageService.instance.deleteFolder(id);
    await load();
  }
}
