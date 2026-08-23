import 'package:flutter/material.dart';
import '../core/access/access_scope.dart';
import '../core/utils/week_utils.dart';
import '../data/models/enums.dart';
import '../data/models/santri_record.dart';
import '../data/services/storage_service.dart';

/// Dilempar [RecordsProvider.upsert] kalau guru pembimbing mencoba menyimpan
/// laporan untuk kelas/halaqoh di luar assignment-nya. Ini enforcement
/// SUNGGUHAN di level data (bukan cuma UI) — lihat AccessScope & bagian I
/// spesifikasi access control.
class ScopeViolationException implements Exception {
  final String message;
  ScopeViolationException(this.message);
  @override
  String toString() => message;
}

/// Ringkasan satu santri unik — dipakai di daftar santri (Statistik),
/// diambil dari record TERBARU santri itu (kelas/halaqoh bisa berubah).
class SantriSummary {
  final String nama;
  final String kelas;
  final String halaqoh;
  const SantriSummary({required this.nama, required this.kelas, required this.halaqoh});
}

class RecordsProvider extends ChangeNotifier {
  List<SantriRecord> _all = [];

  // Access scope user yang sedang login — null = belum ada user (atau
  // provider ini dipakai tanpa auth sama sekali, mis. saat testing).
  // Di-set dari luar (lewat updateScope) setiap kali status login
  // berubah (restore session, login, logout) — lihat main.dart & flow
  // login/logout di layar Login/Profile.
  AccessScope? _scope;

  // Filter state
  String _searchQuery = '';
  String? _filterKelas;
  String? _filterHalaqoh;
  HafalanStatus? _filterStatus;
  Keterangan? _filterKeterangan;

  /// Data MENTAH tanpa scope — HATI-HATI, hanya untuk kebutuhan internal
  /// (mis. admin tooling). UI biasa harus lewat getter lain di bawah yang
  /// semuanya sudah discope.
  List<SantriRecord> get all => _scoped;

  String get searchQuery => _searchQuery;
  String? get filterKelas => _filterKelas;
  String? get filterHalaqoh => _filterHalaqoh;
  HafalanStatus? get filterStatus => _filterStatus;
  Keterangan? get filterKeterangan => _filterKeterangan;

  /// True kalau user yang login adalah guru pembimbing (dibatasi assignment) —
  /// dipakai UI buat, mis., mengunci pilihan kelas/halaqoh di form.
  bool get isScoped => _scope != null && !_scope!.isAdmin;
  AccessScope? get scope => _scope;

  /// Dipanggil setiap kali status login berubah (restore session saat
  /// startup, login, logout). Bukan pakai ProxyProvider supaya
  /// RecordsProvider tetap independen/gampang di-test — cukup dipanggil
  /// eksplisit dari flow auth.
  void updateScope(AccessScope? scope) {
    _scope = scope;
    notifyListeners();
  }

  /// Data laporan yang sudah difilter access scope — ini yang dipakai
  /// SEMUA getter/query di bawah, supaya guru pembimbing tidak pernah kebocoran
  /// data kelas/halaqoh lain walau lewat jalur statistik/search/export.
  List<SantriRecord> get _scoped => _scope == null ? _all : _scope!.scopeRecords(_all);

  Future<void> load() async {
    _all = StorageService.instance.getAll();
    notifyListeners();
  }

  List<SantriRecord> get filtered {
    return _scoped.where((r) {
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

  /// Simpan laporan baru/edit. Kalau user guru pembimbing (scope aktif, bukan
  /// admin) mencoba simpan untuk kelas/halaqoh di luar assignment-nya,
  /// ditolak di sini — INI enforcement access-control yang sesungguhnya,
  /// bukan sekadar UI yang membatasi pilihan.
  Future<void> upsert(SantriRecord record) async {
    if (_scope != null && !_scope!.canAccessRecord(record)) {
      throw ScopeViolationException(
        'Anda tidak punya akses untuk kelas ${record.kelas} / ${record.halaqoh}.',
      );
    }
    await StorageService.instance.upsert(record);
    await load();
  }

  Future<void> delete(String id) async {
    // Cari lewat data TER-SCOPE — guru pembimbing nggak bisa hapus record di luar
    // assignment-nya walau tahu id-nya (mis. dari deep link/cache lama).
    final record = _findById(id);
    if (record == null) return;
    await StorageService.instance.delete(id);
    await load();
  }

  // --- Folder ---

  /// Laporan yang tidak berada di folder mana pun, dengan search/filter
  /// aktif tetap diterapkan — ini yang tampil di section "Laporan".
  List<SantriRecord> get filteredRoot =>
      filtered.where((r) => r.folderId == null).toList();

  /// Semua laporan di dalam satu folder (tidak terpengaruh search/filter
  /// tab Laporan), terbaru duluan.
  List<SantriRecord> recordsInFolder(String folderId) {
    final list = _scoped.where((r) => r.folderId == folderId).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  int countInFolder(String folderId) => _scoped.where((r) => r.folderId == folderId).length;

  SantriRecord? _findById(String id) {
    for (final r in _scoped) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> moveToFolder(String recordId, String? folderId) async {
    final record = _findById(recordId);
    if (record == null) return;
    await StorageService.instance.upsert(
      folderId == null ? record.copyWith(clearFolder: true) : record.copyWith(folderId: folderId),
    );
    await load();
  }

  Future<void> moveManyToFolder(Iterable<String> recordIds, String? folderId) async {
    for (final id in recordIds) {
      final record = _findById(id);
      if (record == null) continue;
      await StorageService.instance.upsert(
        folderId == null ? record.copyWith(clearFolder: true) : record.copyWith(folderId: folderId),
      );
    }
    await load();
  }

  Future<void> clearAllData() async {
    await StorageService.instance.clearAll();
    clearFilters();
    await load();
  }

  // --- Statistik ringkas untuk header ---
  int get totalSantri => _scoped.map((r) => r.namaAnak).toSet().length;
  int get totalTahfizh => _scoped.where((r) => r.status == HafalanStatus.tahfizh).length;
  int get totalTahsin => _scoped.where((r) => r.status == HafalanStatus.tahsin).length;
  int get totalHadir => _scoped.where((r) => r.keterangan == Keterangan.hadir).length;
  int get totalIzinAlpa => _scoped.where((r) => r.keterangan != Keterangan.hadir).length;
  int get totalBarisSetoran =>
      _scoped.fold(0, (sum, r) => sum + (r.totalBaris ?? 0));

  // --- Ringkasan "Hari Ini" untuk Home & Profile ---
  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  List<SantriRecord> get _todayRecords => _scoped.where((r) => _isToday(r.tanggal)).toList();

  int get laporanBaruHariIni => _todayRecords.length;
  int get totalBarisHariIni =>
      _todayRecords.fold(0, (sum, r) => sum + (r.totalBaris ?? 0));
  int get santriAktifHariIni =>
      _todayRecords.map((r) => r.namaAnak).toSet().length;

  // --- Dataset untuk dropdown+ketik di form (Kelas/Halaqoh/Nama Santri) ---
  // Diturunin dari data yang udah pernah diinput (sudah discope) DAN
  // digabung dengan data master santri di layer UI (lihat record_form_sheet)
  // supaya guru pembimbing juga bisa pilih santri yang belum pernah dilaporkan.
  List<String> get distinctKelas => _scoped
      .map((r) => r.kelas)
      .where((v) => v.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> get distinctHalaqoh => _scoped
      .map((r) => r.halaqoh)
      .where((v) => v.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> get distinctNamaSantri => _scoped
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
    for (final r in _scoped) {
      if (r.id == excludeRecordId) continue;
      if (r.namaAnak.trim().toLowerCase() != key) continue;
      if (r.lineIds == null) continue;
      ids.addAll(r.lineIds!);
    }
    return ids;
  }

  // --- Daftar santri unik (buat halaman "Daftar Santri" di Statistik) ---
  // Kelas/halaqoh diambil dari record TERBARU santri itu (bisa berubah
  // seiring waktu), bukan dari record pertama.
  List<SantriSummary> get santriList {
    final latestBySantri = <String, SantriRecord>{};
    for (final r in _scoped) {
      final key = r.namaAnak.trim().toLowerCase();
      if (key.isEmpty) continue;
      final existing = latestBySantri[key];
      if (existing == null || r.tanggal.isAfter(existing.tanggal)) {
        latestBySantri[key] = r;
      }
    }
    final list = latestBySantri.values
        .map((r) => SantriSummary(nama: r.namaAnak, kelas: r.kelas, halaqoh: r.halaqoh))
        .toList()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    return list;
  }

  /// Semua laporan milik satu santri (match nama, case-insensitive),
  /// terbaru duluan.
  List<SantriRecord> recordsForSantri(String namaAnak) {
    final key = namaAnak.trim().toLowerCase();
    final list = _scoped.where((r) => r.namaAnak.trim().toLowerCase() == key).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  /// Kelompokkan [records] per tanggal (jam diabaikan), terbaru duluan.
  /// Dipakai bareng [DateGroupCard] di halaman Detail Santri, Kehadiran,
  /// dan Rekap Bulanan/Pekanan.
  Map<DateTime, List<SantriRecord>> groupByDate(List<SantriRecord> records) {
    final map = <DateTime, List<SantriRecord>>{};
    for (final r in records) {
      final key = DateTime(r.tanggal.year, r.tanggal.month, r.tanggal.day);
      map.putIfAbsent(key, () => []).add(r);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  /// Semua laporan, terbaru duluan — dipakai halaman Kehadiran.
  List<SantriRecord> get allSortedByDateDesc {
    final list = List<SantriRecord>.from(_scoped)
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  // --- Rekap bulanan (EXISTING — dipertahankan apa adanya) ---
  /// Daftar bulan (tanggal 1 tiap bulan) yang punya minimal 1 laporan,
  /// terbaru duluan. Dipakai buat batasi navigasi bulan di Rekap Bulanan
  /// biar user gak bisa maju/mundur ke bulan yang datanya kosong.
  List<DateTime> get availableMonths {
    final set = <DateTime>{};
    for (final r in _scoped) {
      set.add(DateTime(r.tanggal.year, r.tanggal.month));
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<SantriRecord> recordsInMonth(DateTime month) {
    final list = _scoped
        .where((r) => r.tanggal.year == month.year && r.tanggal.month == month.month)
        .toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  int totalTahfizhInMonth(DateTime month) =>
      recordsInMonth(month).where((r) => r.status == HafalanStatus.tahfizh).length;

  int totalTahsinInMonth(DateTime month) =>
      recordsInMonth(month).where((r) => r.status == HafalanStatus.tahsin).length;

  int totalBarisInMonth(DateTime month) =>
      recordsInMonth(month).fold(0, (sum, r) => sum + (r.totalBaris ?? 0));

  // --- Rekap PEKANAN (BARU) ---
  // Definisi pekan konsisten lewat WeekUtils (Senin-Minggu, ISO week
  // number) — dipakai di sini & di Profile biar "Pekan ke-N" selalu sama
  // angkanya di mana pun ditampilkan.

  /// Daftar tanggal Senin (awal pekan) yang punya minimal 1 laporan,
  /// terbaru duluan — buat batasi navigasi di Rekap Pekanan.
  List<DateTime> get availableWeeks {
    final set = <DateTime>{};
    for (final r in _scoped) {
      set.add(WeekUtils.startOfWeek(r.tanggal));
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  /// Semua laporan dalam pekan yang memuat [anyDateInWeek], terbaru duluan.
  List<SantriRecord> recordsInWeek(DateTime anyDateInWeek) {
    final start = WeekUtils.startOfWeek(anyDateInWeek);
    final end = start.add(const Duration(days: 7));
    final list = _scoped
        .where((r) => !r.tanggal.isBefore(start) && r.tanggal.isBefore(end))
        .toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  int totalTahfizhInWeek(DateTime anyDateInWeek) =>
      recordsInWeek(anyDateInWeek).where((r) => r.status == HafalanStatus.tahfizh).length;

  int totalTahsinInWeek(DateTime anyDateInWeek) =>
      recordsInWeek(anyDateInWeek).where((r) => r.status == HafalanStatus.tahsin).length;

  int totalBarisInWeek(DateTime anyDateInWeek) =>
      recordsInWeek(anyDateInWeek).fold(0, (sum, r) => sum + (r.totalBaris ?? 0));

  int totalHadirInWeek(DateTime anyDateInWeek) =>
      recordsInWeek(anyDateInWeek).where((r) => r.keterangan == Keterangan.hadir).length;

  int totalIzinAlpaInWeek(DateTime anyDateInWeek) =>
      recordsInWeek(anyDateInWeek).where((r) => r.keterangan != Keterangan.hadir).length;

  int santriAktifInWeek(DateTime anyDateInWeek) =>
      recordsInWeek(anyDateInWeek).map((r) => r.namaAnak.trim().toLowerCase()).toSet().length;

  /// Breakdown per-hari dalam satu pekan (Senin..Minggu) — dipakai di
  /// Rekap Pekanan buat baris "Senin — 12 laporan", dst.
  Map<DateTime, List<SantriRecord>> weekDailyBreakdown(DateTime anyDateInWeek) =>
      groupByDate(recordsInWeek(anyDateInWeek));
}
