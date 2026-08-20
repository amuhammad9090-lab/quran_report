import 'package:flutter/material.dart';
import '../data/models/enums.dart';
import '../data/models/santri_record.dart';
import '../data/services/storage_service.dart';

class RecordsProvider extends ChangeNotifier {
  List<SantriRecord> _all = [];

  // Filter state
  String _searchQuery = '';
  String? _filterKelas;
  String? _filterHalaqoh;
  HafalanStatus? _filterStatus;
  Keterangan? _filterKeterangan;

  List<SantriRecord> get all => _all;
  String get searchQuery => _searchQuery;
  String? get filterKelas => _filterKelas;
  String? get filterHalaqoh => _filterHalaqoh;
  HafalanStatus? get filterStatus => _filterStatus;
  Keterangan? get filterKeterangan => _filterKeterangan;

  Future<void> load() async {
    _all = StorageService.instance.getAll();
    notifyListeners();
  }

  List<SantriRecord> get filtered {
    return _all.where((r) {
      if (_searchQuery.isNotEmpty &&
          !r.namaAnak.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_filterKelas != null && r.kelas != _filterKelas) return false;
      if (_filterHalaqoh != null && r.halaqoh != _filterHalaqoh) return false;
      if (_filterStatus != null && r.status != _filterStatus) return false;
      if (_filterKeterangan != null && r.keterangan != _filterKeterangan) return false;
      return true;
    }).toList();
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setFilterKelas(String? v) {
    _filterKelas = v;
    notifyListeners();
  }

  void setFilterHalaqoh(String? v) {
    _filterHalaqoh = v;
    notifyListeners();
  }

  void setFilterStatus(HafalanStatus? v) {
    _filterStatus = v;
    notifyListeners();
  }

  void setFilterKeterangan(Keterangan? v) {
    _filterKeterangan = v;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterKelas = null;
    _filterHalaqoh = null;
    _filterStatus = null;
    _filterKeterangan = null;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _filterKelas != null ||
      _filterHalaqoh != null ||
      _filterStatus != null ||
      _filterKeterangan != null;

  Future<void> upsert(SantriRecord record) async {
    await StorageService.instance.upsert(record);
    await load();
  }

  Future<void> delete(String id) async {
    await StorageService.instance.delete(id);
    await load();
  }

  Future<void> clearAllData() async {
    await StorageService.instance.clearAll();
    clearFilters();
    await load();
  }

  // --- Statistik ringkas untuk header ---
  int get totalSantri => _all.map((r) => r.namaAnak).toSet().length;
  int get totalTahfizh => _all.where((r) => r.status == HafalanStatus.tahfizh).length;
  int get totalTahsin => _all.where((r) => r.status == HafalanStatus.tahsin).length;
  int get totalHadir => _all.where((r) => r.keterangan == Keterangan.hadir).length;
  int get totalIzinAlpa => _all.where((r) => r.keterangan != Keterangan.hadir).length;
  int get totalBarisSetoran =>
      _all.fold(0, (sum, r) => sum + (r.totalBaris ?? 0));

  // --- Ringkasan "Hari Ini" untuk Home ---
  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  List<SantriRecord> get _todayRecords => _all.where((r) => _isToday(r.tanggal)).toList();

  int get laporanBaruHariIni => _todayRecords.length;
  int get totalBarisHariIni =>
      _todayRecords.fold(0, (sum, r) => sum + (r.totalBaris ?? 0));
  int get santriAktifHariIni =>
      _todayRecords.map((r) => r.namaAnak).toSet().length;

  // --- Dataset untuk dropdown+ketik di form (Kelas/Halaqoh/Nama Santri) ---
  // Diturunin dari data yang udah pernah diinput. Kalau nanti ada dataset
  // resmi (excel), tinggal ganti sumbernya di sini.
  List<String> get distinctKelas => _all
      .map((r) => r.kelas)
      .where((v) => v.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> get distinctHalaqoh => _all
      .map((r) => r.halaqoh)
      .where((v) => v.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> get distinctNamaSantri => _all
      .map((r) => r.namaAnak)
      .where((v) => v.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();


  /// Kumpulan `lineId` yang sudah pernah dihitung di laporan tahfizh
  /// sebelumnya untuk santri [namaAnak] (match nama, case-insensitive,
  /// trimmed). [excludeRecordId] dipakai saat edit record supaya baris
  /// milik record yang sedang diedit tidak ikut mengecualikan dirinya sendiri.
  Set<String> lineHistoryFor(String namaAnak, {String? excludeRecordId}) {
    final key = namaAnak.trim().toLowerCase();
    if (key.isEmpty) return {};

    final ids = <String>{};
    for (final r in _all) {
      if (r.id == excludeRecordId) continue;
      if (r.namaAnak.trim().toLowerCase() != key) continue;
      if (r.lineIds == null) continue;
      ids.addAll(r.lineIds!);
    }
    return ids;
  }
}
