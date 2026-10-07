import 'package:flutter/foundation.dart';

import '../core/access/access_scope.dart';
import '../core/access/scope_violation_exception.dart';
import '../core/utils/text_utils.dart';
import '../core/utils/week_utils.dart';
import '../data/models/enums.dart';
import '../data/models/records_view_models.dart';
import '../data/models/santri_monthly_recap.dart';
import '../data/models/santri_record.dart';
import '../data/services/app_prefs_service.dart';
import '../data/services/records_recap_service.dart';
import '../data/services/storage_service.dart';

// Tetap diekspor dari sini supaya import lama `records_provider.dart` tidak perlu diubah.
export '../core/access/scope_violation_exception.dart';
export '../data/models/records_view_models.dart';

/// State laporan: data ter-scope, filter, identitas aktif, dan operasi tulis ke
/// [StorageService]. Perhitungan baca-saja (rekap, ringkasan, grouping) ada di
/// [RecordsRecapService].
class RecordsProvider extends ChangeNotifier {
  List<SantriRecord> _all = [];

  // Naik tiap `load()`/`updateScope()` (satu-satunya jalan mutasi `_all`/`_scope`), jadi
  // cache turunan cukup dibandingkan ke versi ini dan tidak dihitung ulang tiap
  // notifyListeners() yang tak menyentuh data (mis. ganti filter/search).
  int _dataVersion = 0;
  List<SantriRecord>? _scopedCache;
  int _scopedCacheVersion = -1;
  RecordsRecapService? _recapCache;
  int _recapCacheVersion = -1;

  // Access scope user yang login — null = belum ada user (mis. saat testing).
  // Di-set dari luar lewat updateScope tiap status login berubah
  // (restore session, login, logout), lihat main.dart & flow Login/Profile.
  AccessScope? _scope;

  // Filter state
  String _searchQuery = '';
  String? _filterKelas;
  String? _filterHalaqoh;
  HafalanStatus? _filterStatus;
  Keterangan? _filterKeterangan;
  DateTime? _filterDate;

  /// Data MENTAH tanpa scope — HATI-HATI, hanya untuk kebutuhan internal
  /// (mis. admin tooling). UI biasa harus lewat getter lain di bawah yang
  /// semuanya sudah discope.
  List<SantriRecord> get all => _scoped;

  String get searchQuery => _searchQuery;
  String? get filterKelas => _filterKelas;
  String? get filterHalaqoh => _filterHalaqoh;
  HafalanStatus? get filterStatus => _filterStatus;
  Keterangan? get filterKeterangan => _filterKeterangan;
  DateTime? get filterDate => _filterDate;

  AccessScope? get scope => _scope;

  /// Dipanggil setiap status login berubah (restore session, login, logout).
  /// Sengaja tanpa ProxyProvider supaya RecordsProvider tetap independen dan
  /// gampang di-test — cukup dipanggil eksplisit dari flow auth.
  void updateScope(AccessScope? scope) {
    _scope = scope;
    _dataVersion++;
    notifyListeners();
  }

  /// Data laporan yang sudah difilter access scope — dipakai SEMUA getter/query
  /// supaya guru pembimbing tak pernah melihat data kelas/halaqoh lain.
  /// Di-cache per [_dataVersion].
  List<SantriRecord> get _scoped {
    if (_scopedCacheVersion != _dataVersion) {
      _scopedCache = _scope == null ? _all : _scope!.scopeRecords(_all);
      _scopedCacheVersion = _dataVersion;
    }
    return _scopedCache!;
  }

  /// Kalkulasi baca-saja atas [_scoped]; instance baru dibuat tiap [_dataVersion]
  /// berubah, jadi memo di dalamnya otomatis ikut kosong.
  RecordsRecapService get _recap {
    if (_recapCacheVersion != _dataVersion || _recapCache == null) {
      _recapCache = RecordsRecapService(_scoped);
      _recapCacheVersion = _dataVersion;
    }
    return _recapCache!;
  }

  // Kunci identitas ("kelas|halaqoh|nama") santri yang sudah "diaktifkan"
  // lewat "Buat Laporan" tapi belum tentu punya SantriRecord sama sekali —
  // lihat AppPrefsService.activatedIdentityKeys & [laporanCards].
  Set<String> _activatedKeys = {};

  // Mapping identitas KOSONG (belum ada SantriRecord) -> folder tujuan —
  // lihat AppPrefsService.activatedIdentityFolders & [SantriCardInfo.emptyCardFolderId].
  Map<String, String> _activatedFolders = {};

  Future<void> load() async {
    _all = StorageService.instance.getAll();
    _activatedKeys = AppPrefsService.instance.activatedIdentityKeys.toSet();
    _activatedFolders = AppPrefsService.instance.activatedIdentityFolders;
    // BUG FIX: kapitalisasi asli identitas kosong di-restore dari storage
    // persisten, bukan cuma cache in-memory sesi ini (lihat
    // AppPrefsService.activatedIdentityDisplay).
    for (final entry in AppPrefsService.instance.activatedIdentityDisplay.entries) {
      final parts = entry.value.split('|');
      if (parts.length != 3) continue;
      _lastActivatedDisplay[entry.key] = (kelas: parts[0], halaqoh: parts[1], nama: parts[2]);
    }
    await _cleanupStaleActivatedFolders();
    _dataVersion++;
    notifyListeners();
  }

  /// Bersihkan mapping folder sementara identitas kosong yang sudah punya laporan asli
  /// (folder-nya kini mengikuti `record.folderId`). [_lastActivatedDisplay] sengaja
  /// dibiarkan: kartu bisa kosong lagi bila laporan terakhirnya dihapus (lihat [deleteAllForSantri]).
  Future<void> _cleanupStaleActivatedFolders() async {
    if (_activatedFolders.isEmpty) return;
    final withRecords = _all
        .map((r) => reportIdentityKey(r.kelas, r.halaqoh, r.namaAnak))
        .toSet();
    final staleFolders = _activatedFolders.keys.where(withRecords.contains).toList();
    for (final key in staleFolders) {
      _activatedFolders.remove(key);
      await AppPrefsService.instance.removeActivatedIdentityFolder(key);
    }
  }

  /// Aktifkan kartu Laporan untuk santri TANPA membuat SantriRecord (flow "Buat Laporan").
  /// Ditolak bila di luar scope akses user; [folderId] opsional langsung "memarkir"
  /// kartu di folder itu (lihat [SantriCardInfo.emptyCardFolderId]).
  Future<void> activateIdentity({
    required String kelas,
    required String halaqoh,
    required String nama,
    String? folderId,
  }) async {
    if (_scope?.isViewer ?? false) throw ScopeViolationException('Akun Pengawas hanya bisa melihat data.');
    if (_scope != null && !_scope!.canAccessKelasHalaqoh(kelas, halaqoh)) {
      throw ScopeViolationException(
        'Anda tidak punya akses untuk kelas $kelas / $halaqoh.',
      );
    }
    final key = reportIdentityKey(kelas, halaqoh, nama);
    _rememberActivatedDisplay(kelas, halaqoh, nama);
    // BUG FIX: kapitalisasi asli juga dipersist ke disk, bukan hanya RAM — kalau app
    // di-kill sebelum laporan pertama dibuat, nama kartu balik lowercase (fallback identityKey).
    await AppPrefsService.instance.setActivatedIdentityDisplay(key, '$kelas|$halaqoh|$nama');
    await AppPrefsService.instance.addActivatedIdentity(key);
    _activatedKeys.add(key);
    if (folderId != null) {
      _activatedFolders[key] = folderId;
      await AppPrefsService.instance.setActivatedIdentityFolder(key, folderId);
    }
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
      if (_filterDate != null &&
          !(r.tanggal.year == _filterDate!.year &&
              r.tanggal.month == _filterDate!.month &&
              r.tanggal.day == _filterDate!.day)) {
        return false;
      }
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

  void setFilterDate(DateTime? v) {
    _filterDate = v;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterKelas = null;
    _filterHalaqoh = null;
    _filterStatus = null;
    _filterKeterangan = null;
    _filterDate = null;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _filterKelas != null ||
      _filterHalaqoh != null ||
      _filterStatus != null ||
      _filterKeterangan != null ||
      _filterDate != null;

  /// Simpan laporan baru/edit. Guru pembimbing yang menyimpan di luar assignment-nya
  /// ditolak di sini — enforcement access-control yang sesungguhnya, bukan
  /// sekadar UI yang membatasi pilihan.
  Future<void> upsert(SantriRecord record) async {
    if (_scope?.isViewer ?? false) throw ScopeViolationException('Akun Pengawas hanya bisa melihat data.');
    if (_scope != null && !_scope!.canAccessRecord(record)) {
      throw ScopeViolationException(
        'Anda tidak punya akses untuk kelas ${record.kelas} / ${record.halaqoh}.',
      );
    }
    await StorageService.instance.upsert(record);
    await load();
  }

  Future<void> delete(String id) async {
    if (_scope?.isViewer ?? false) return; // pengawas read-only: aksi ini diabaikan
    // Cari lewat data TER-SCOPE — guru pembimbing nggak bisa hapus record di luar
    // assignment-nya walau tahu id-nya (mis. dari deep link/cache lama).
    final record = _findById(id);
    if (record == null) return;
    await StorageService.instance.delete(id);
    await load();
  }

  // --- Folder ---

  int countInFolder(String folderId) {
    String key(SantriRecord r) =>
        '${r.namaAnak.trim().toLowerCase()}|${r.kelas}|${r.halaqoh}';
    return _scoped.where((r) => r.folderId == folderId).map(key).toSet().length;
  }

  /// Hapus PERMANEN semua laporan di folder [folderId] — dipakai saat folder
  /// dihapus (ikut menghapus isinya, bukan cuma mengeluarkan dari folder).
  Future<void> deleteAllInFolder(String folderId) async {
    if (_scope?.isViewer ?? false) return; // pengawas read-only: aksi ini diabaikan
    final ids = _scoped.where((r) => r.folderId == folderId).map((r) => r.id).toList();
    for (final id in ids) {
      await StorageService.instance.delete(id);
    }
    await load();
  }

  SantriRecord? _findById(String id) {
    for (final r in _scoped) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> moveManyToFolder(Iterable<String> recordIds, String? folderId) async {
    if (_scope?.isViewer ?? false) return; // pengawas read-only: aksi ini diabaikan
    for (final id in recordIds) {
      final record = _findById(id);
      if (record == null) continue;
      await StorageService.instance.upsert(
        folderId == null ? record.copyWith(clearFolder: true) : record.copyWith(folderId: folderId),
      );
    }
    await load();
  }

  /// Pindahkan SEMUA laporan (semua pekan) santri [namaAnak] ke [folderId]
  /// (null = keluarkan) — dipakai [SantriReportCard]; beda dari [moveManyToFolder]
  /// yang per-id laporan.
  Future<void> moveAllForSantriToFolder(String namaAnak, String? folderId) async {
    if (_scope?.isViewer ?? false) return; // pengawas read-only: aksi ini diabaikan
    final ids = recordsForSantri(namaAnak).map((r) => r.id).toList();
    await moveManyToFolder(ids, folderId);
  }

  /// Hapus SEMUA laporan santri [namaAnak] + lepas [identityKey]-nya dari identitas aktif.
  /// Ikut menghapus dokumen `weeklyRecaps` (rekap yang di-"Deploy" ke Portal Ortu)
  /// supaya tak jadi dokumen yatim di Firestore.
  Future<void> deleteAllForSantri(String namaAnak, String identityKey) async {
    if (_scope?.isViewer ?? false) return; // pengawas read-only: aksi ini diabaikan
    final ids = recordsForSantri(namaAnak).map((r) => r.id).toList();
    for (final id in ids) {
      await StorageService.instance.delete(id);
    }
    await StorageService.instance.deleteWeeklyRecapsForSantri(namaAnak);
    await AppPrefsService.instance.removeActivatedIdentity(identityKey);
    await AppPrefsService.instance.removeActivatedIdentityDisplay(identityKey);
    _activatedKeys.remove(identityKey);
    _activatedFolders.remove(identityKey);
    _lastActivatedDisplay.remove(identityKey);
    await load();
  }

  /// Pindahkan kartu [card] ke [folderId] (null = keluarkan). Kartu ber-laporan: semua
  /// laporannya dipindah; kartu KOSONG: disimpan sebagai mapping identitas sementara
  /// (lihat [SantriCardInfo.emptyCardFolderId]) yang basi begitu laporan pertama dibuat.
  Future<void> moveIdentityToFolder(SantriCardInfo card, String? folderId) async {
    if (_scope?.isViewer ?? false) return; // pengawas read-only: aksi ini diabaikan
    if (card.hasAnyReport) {
      await moveAllForSantriToFolder(card.nama, folderId);
      return;
    }
    if (folderId == null) {
      _activatedFolders.remove(card.identityKey);
      await AppPrefsService.instance.removeActivatedIdentityFolder(card.identityKey);
    } else {
      _activatedFolders[card.identityKey] = folderId;
      await AppPrefsService.instance.setActivatedIdentityFolder(card.identityKey, folderId);
    }
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await StorageService.instance.clearAll();
    clearFilters();
    await load();
  }

  // --- Query baca-saja: didelegasikan ke RecordsRecapService ---

  int get totalSantri => _recap.totalSantri;
  int get totalHadir => _recap.totalHadir;
  int get totalBarisSetoran => _recap.totalBarisSetoran;

  List<WeeklyAyatPoint> weeklyAyatSummary({int weekCount = 6}) =>
      _recap.weeklyAyatSummary(weekCount: weekCount);

  int get laporanBaruHariIni => _recap.laporanBaruHariIni;
  int get totalBarisHariIni => _recap.totalBarisHariIni;
  int get santriAktifHariIni => _recap.santriAktifHariIni;

  List<String> get distinctKelas => _recap.distinctKelas;
  List<String> get distinctHalaqoh => _recap.distinctHalaqoh;

  Set<String> lineHistoryFor(String namaAnak, {String? excludeRecordId}) =>
      _recap.lineHistoryFor(namaAnak, excludeRecordId: excludeRecordId);

  List<SantriSummary> get santriList => _recap.santriList;
  List<SantriRecord> recordsForSantri(String namaAnak) => _recap.recordsForSantri(namaAnak);
  List<SantriRecord> get allSortedByDateDesc => _recap.allSortedByDateDesc;

  Map<DateTime, List<SantriRecord>> groupByDate(List<SantriRecord> records) =>
      RecordsRecapService.groupByDate(records);

  List<KelasHalaqohGroup> groupByKelasHalaqoh(List<SantriRecord> records) =>
      RecordsRecapService.groupByKelasHalaqoh(records);

  // Rekap bulan/pekan/hari
  List<SantriRecord> recordsInMonth(DateTime month) => _recap.recordsInMonth(month);
  int totalTahfizhInMonth(DateTime month) => _recap.totalTahfizhInMonth(month);
  int totalTahsinInMonth(DateTime month) => _recap.totalTahsinInMonth(month);
  int totalBarisInMonth(DateTime month) => _recap.totalBarisInMonth(month);
  List<SantriRecord> recordsInMonthWeek(DateTime month, int weekIndex) =>
      _recap.recordsInMonthWeek(month, weekIndex);
  List<SantriRecord> recordsOnDate(DateTime date) => _recap.recordsOnDate(date);
  List<MonthWeekSummary> monthWeekSummaries(DateTime month) => _recap.monthWeekSummaries(month);
  Set<int> weeksWithReportForSantriInMonth(String namaAnak, DateTime month) =>
      _recap.weeksWithReportForSantriInMonth(namaAnak, month);
  List<SantriMonthlyRecap> monthlySantriRecaps(DateTime month) =>
      _recap.monthlySantriRecaps(month);

  SantriRecord? recordForSantriOnDate(String namaAnak, DateTime date) =>
      _recap.recordForSantriOnDate(namaAnak, date);
  List<SantriRecord> recordsForSantriInRange(String namaAnak, DateTime start, DateTime end) =>
      _recap.recordsForSantriInRange(namaAnak, start, end);

  // --- Kartu santri tab Laporan (butuh state identitas aktif, jadi tetap di provider) ---

  /// Kartu santri tab Laporan — SATU kartu per santri: gabungan santri yang punya
  /// laporan ([santriList]) dan identitas "diaktifkan" tanpa laporan ([_activatedKeys]).
  /// Terurut nama.
  List<SantriCardInfo> get laporanCards {
    final now = DateTime.now();
    // Bulan PEMILIK pekan hari ini (bisa beda dari now.month di ujung bulan),
    // konsisten dengan _buildCard di santri_report_card.dart.
    final thisMonth = WeekUtils.ownerMonth(now);
    final totalWeeksThisMonth = WeekUtils.weeksInMonth(thisMonth);

    final byKey = <String, SantriCardInfo>{};

    for (final s in santriList) {
      final key = reportIdentityKey(s.kelas, s.halaqoh, s.nama);
      final santriRecords = recordsForSantri(s.nama);
      final latest = santriRecords.isEmpty ? null : santriRecords.first;
      byKey[key] = SantriCardInfo(
        identityKey: key,
        nama: s.nama,
        kelas: s.kelas,
        halaqoh: s.halaqoh,
        weeksWithReportThisMonth: weeksWithReportForSantriInMonth(s.nama, thisMonth),
        totalWeeksThisMonth: totalWeeksThisMonth,
        latestRecord: latest,
      );
    }

    // Identitas yang diaktifkan tapi BELUM punya laporan apapun -> tambah
    // sebagai kartu kosong. Kalau ternyata sudah punya laporan (sudah
    // masuk lewat santriList di atas), tidak perlu ditimpa.
    for (final key in _activatedKeys) {
      if (byKey.containsKey(key)) continue;
      final parts = key.split('|');
      if (parts.length != 3) continue;
      // Key disimpan lowercase; kapitalisasi asli hanya ada di [_lastActivatedDisplay]
      // (diisi saat aktivasi). BUG FIX: kalau tak ketemu (data lokal hilang, belum
      // "Pulihkan dari Cloud"), fallback di-title-case ([toTitleCase]) — bukan lowercase.
      final display = _lastActivatedDisplay[key];
      byKey[key] = SantriCardInfo(
        identityKey: key,
        nama: display?.nama ?? toTitleCase(parts[2]),
        kelas: display?.kelas ?? parts[0],
        halaqoh: display?.halaqoh ?? parts[1],
        weeksWithReportThisMonth: const {},
        totalWeeksThisMonth: totalWeeksThisMonth,
        latestRecord: null,
        emptyCardFolderId: _activatedFolders[key],
      );
    }

    final list = byKey.values.toList()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    // Guru pembimbing (bukan admin) hanya boleh lihat kartu di
    // kelas+halaqoh assignment-nya sendiri — termasuk kartu identitas
    // kosong (belum ada SantriRecord yang bisa discope lewat _scoped).
    if (_scope == null || _scope!.canSeeAll) return list;
    return list.where((c) => _scope!.canAccessKelasHalaqoh(c.kelas, c.halaqoh)).toList();
  }

  /// Kartu [SantriCardInfo] yang identityKey-nya [key] — dipakai buat
  /// nemu kartu lengkap dari payload drag (yang cuma bawa identityKey,
  /// lihat [SantriReportCard]).
  SantriCardInfo? cardByIdentityKey(String key) {
    for (final c in laporanCards) {
      if (c.identityKey == key) return c;
    }
    return null;
  }

  /// Semua kartu santri yang "rumahnya" folder [folderId] saat ini — lihat
  /// [SantriCardInfo.currentFolderId]. Dipakai [FolderDetailScreen] (isi
  /// satu folder, sekarang per-santri bukan per-laporan lagi).
  List<SantriCardInfo> cardsInFolder(String folderId) =>
      laporanCards.where((c) => c.currentFolderId == folderId).toList();

  /// Kartu yang folder-nya (currentFolderId) sudah TIDAK ADA di [FoldersProvider]
  /// ([validFolderIds] = id folder yang masih ada), mis. laporan menunjuk folder yang belum
  /// ter-backup lalu "Pulihkan dari Cloud". Dipakai [OrphanedRecordsScreen] untuk menyelamatkannya.
  List<SantriCardInfo> orphanedFolderCards(Set<String> validFolderIds) {
    return laporanCards
        .where((c) => c.currentFolderId != null && !validFolderIds.contains(c.currentFolderId))
        .toList();
  }

  // Kapitalisasi asli identitas yang diaktifkan (diisi saat aktivasi dan di-restore dari
  // AppPrefsService di load()) agar kartu kosong tampil benar tanpa reload. Setelah punya
  // laporan asli, tampilan berpindah ke SantriRecord.namaAnak/kelas/halaqoh.
  final Map<String, ({String nama, String kelas, String halaqoh})> _lastActivatedDisplay = {};

  void _rememberActivatedDisplay(String kelas, String halaqoh, String nama) {
    final key = reportIdentityKey(kelas, halaqoh, nama);
    _lastActivatedDisplay[key] = (nama: nama, kelas: kelas, halaqoh: halaqoh);
  }
}
