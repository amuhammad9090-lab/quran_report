import 'package:flutter/material.dart';
import '../core/access/access_scope.dart';
import '../core/utils/text_utils.dart';
import '../core/utils/week_utils.dart';
import '../data/models/enums.dart';
import '../data/models/santri_monthly_recap.dart';
import '../data/models/santri_record.dart';
import '../data/services/app_prefs_service.dart';
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

/// Ringkasan satu pekan DALAM BULAN (Pekan 1..6) — dipakai di Rekap
/// Bulanan → daftar Pekan, lihat [RecordsProvider.monthWeekSummaries].
class MonthWeekSummary {
  final int weekIndex;
  final MonthWeekRange range;
  final int santriCount;
  final int laporanCount;
  final int totalBaris;
  const MonthWeekSummary({
    required this.weekIndex,
    required this.range,
    required this.santriCount,
    required this.laporanCount,
    required this.totalBaris,
  });
}

/// Data 1 kartu santri di tab Laporan — mewakili SATU santri (bukan satu
/// laporan/pekan), lihat [RecordsProvider.laporanCards]. Identitas dikunci
/// oleh [identityKey] = "kelas|halaqoh|nama" (lowercase, trimmed).
class SantriCardInfo {
  final String identityKey;
  final String nama;
  final String kelas;
  final String halaqoh;

  /// Nomor pekan (dalam BULAN BERJALAN) yang sudah punya laporan — dipakai
  /// buat indikator "✓1 ✓2 3 4 5" di kartu.
  final Set<int> weeksWithReportThisMonth;
  final int totalWeeksThisMonth;

  /// Laporan terbaru santri ini (semua waktu, null kalau kartu ini baru
  /// diaktifkan & belum pernah diisi laporan sama sekali).
  final SantriRecord? latestRecord;

  /// HANYA berarti kalau [latestRecord] null (kartu masih kosong) — folder
  /// tujuan yang dipilih user waktu kartu kosong ini di-"Pindahkan ke
  /// Folder" (drag atau lewat sheet aksi). Null = kartu kosong ini belum
  /// dipindah ke folder mana pun. Lihat [RecordsProvider.moveIdentityToFolder].
  final String? emptyCardFolderId;

  const SantriCardInfo({
    required this.identityKey,
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    required this.weeksWithReportThisMonth,
    required this.totalWeeksThisMonth,
    required this.latestRecord,
    this.emptyCardFolderId,
  });

  bool get hasAnyReport => latestRecord != null;

  /// Folder "rumah" kartu ini SAAT INI — dari laporan terbaru kalau sudah
  /// ada laporan, atau dari [emptyCardFolderId] kalau masih kosong. Null =
  /// tidak di folder mana pun ("Tanpa Folder"). Dipakai buat pengelompokan
  /// per-folder di Hasil Pencarian & buat menentukan folder isi Folder
  /// Detail (lihat [RecordsProvider.cardsInFolder]).
  String? get currentFolderId => hasAnyReport ? latestRecord!.folderId : emptyCardFolderId;
}

/// Kunci identitas "kelas|halaqoh|nama" yang konsisten dipakai di seluruh
/// [RecordsProvider] (kartu Laporan & aktivasi identitas) — normalisasi
/// (trim + lowercase) supaya tidak ganda cuma gara-gara beda kapital/spasi.
String reportIdentityKey(String kelas, String halaqoh, String nama) =>
    '${kelas.trim().toLowerCase()}|${halaqoh.trim().toLowerCase()}|${nama.trim().toLowerCase()}';

class RecordsProvider extends ChangeNotifier {
  List<SantriRecord> _all = [];

  // --- Cache buat getter agregat (santriList, dst) ---
  // Semua mutasi `_all`/`_scope` SELALU lewat `load()` atau `updateScope()`
  // (lihat upsert/delete/dst — semuanya diakhiri `await load()`), jadi
  // versi ini cukup dibump di 2 tempat itu saja buat tahu kapan cache
  // agregat harus dihitung ulang. Tujuannya: `build()` yang manggil getter
  // ini berkali-kali (tiap kali ada notifyListeners APAPUN, termasuk yang
  // cuma ganti filter/search) tidak ikut nge-loop ulang seluruh data kalau
  // datanya sendiri belum berubah — lihat juga [santriList].
  int _dataVersion = 0;
  List<SantriRecord>? _scopedCache;
  int _scopedCacheVersion = -1;
  List<SantriSummary>? _santriListCache;
  int _santriListCacheVersion = -1;

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

  AccessScope? get scope => _scope;

  /// Dipanggil setiap kali status login berubah (restore session saat
  /// startup, login, logout). Bukan pakai ProxyProvider supaya
  /// RecordsProvider tetap independen/gampang di-test — cukup dipanggil
  /// eksplisit dari flow auth.
  void updateScope(AccessScope? scope) {
    _scope = scope;
    _dataVersion++;
    notifyListeners();
  }

  /// Data laporan yang sudah difilter access scope — ini yang dipakai
  /// SEMUA getter/query di bawah, supaya guru pembimbing tidak pernah kebocoran
  /// data kelas/halaqoh lain walau lewat jalur statistik/search/export.
  /// Di-cache per [_dataVersion] (lihat komentar di atas field cache-nya).
  List<SantriRecord> get _scoped {
    if (_scopedCacheVersion != _dataVersion) {
      _scopedCache = _scope == null ? _all : _scope!.scopeRecords(_all);
      _scopedCacheVersion = _dataVersion;
    }
    return _scopedCache!;
  }

  // Kunci identitas ("kelas|halaqoh|nama") santri yang sudah "diaktifkan"
  // lewat "Buat Laporan" tapi belum tentu punya SantriRecord sama sekali —
  // lihat AppPrefsService.activatedIdentityKeys & [laporanCards].
  Set<String> _activatedKeys = {};

  // Mapping identitas KOSONG (belum ada SantriRecord) -> folder tujuan —
  // lihat dokumentasi lengkap di AppPrefsService.activatedIdentityFolders
  // & [SantriCardInfo.emptyCardFolderId].
  Map<String, String> _activatedFolders = {};

  Future<void> load() async {
    _all = StorageService.instance.getAll();
    _activatedKeys = AppPrefsService.instance.activatedIdentityKeys.toSet();
    _activatedFolders = AppPrefsService.instance.activatedIdentityFolders;
    // BUG FIX: kapitalisasi asli identitas kosong sekarang di-restore
    // dari storage persisten (bukan cuma ngandelin cache in-memory sesi
    // ini) — lihat detail penyebab bug-nya di komentar
    // AppPrefsService.activatedIdentityDisplay.
    for (final entry in AppPrefsService.instance.activatedIdentityDisplay.entries) {
      final parts = entry.value.split('|');
      if (parts.length != 3) continue;
      _lastActivatedDisplay[entry.key] = (kelas: parts[0], halaqoh: parts[1], nama: parts[2]);
    }
    await _cleanupStaleActivatedFolders();
    _dataVersion++;
    notifyListeners();
  }

  /// Begitu identitas yang tadinya kosong dapat laporan asli (SantriRecord
  /// pertamanya tersimpan, entah lewat [initialFolderId] otomatis atau
  /// dibuat manual), mapping folder sementaranya jadi basi (folder
  /// "beneran"-nya sekarang mengikuti `record.folderId`) — bersihkan biar
  /// tidak nyangkut jadi sampah di storage.
  ///
  /// CATATAN: [_lastActivatedDisplay] SENGAJA TIDAK ikut dibersihkan di
  /// sini (beda dari _activatedFolders) — BUG FIX: sebelumnya sempat ikut
  /// dihapus di sini begitu ada laporan, tapi itu keliru: kartu bisa
  /// balik "kosong" lagi kalau laporan SATU-SATUNYA yang dipunya
  /// dihapus, dan saat itu kapitalisasi asli ini dibutuhkan LAGI. Jadi
  /// dibiarkan hidup selama identitasnya masih ada di [_activatedKeys] —
  /// baru ikut dihapus di [deleteAllForSantri] (identitasnya sendiri
  /// dihapus total).
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

  /// Aktifkan kartu Laporan untuk santri [kelas]/[halaqoh]/[nama] TANPA
  /// membuat SantriRecord apapun — dipakai flow "Buat Laporan" (identitas
  /// saja, capaian diisi belakangan per-pekan lewat kartu). Ditolak kalau
  /// di luar scope akses user yang login (guru pembimbing hanya boleh
  /// mengaktifkan identitas di kelas+halaqoh assignment-nya sendiri).
  /// [folderId] opsional -> kartu identitas yang baru diaktifkan langsung
  /// "diparkir" ke folder itu (dipakai alur "Buat Laporan" yang dipicu dari
  /// dalam [FolderDetailScreen], lihat [SantriCardInfo.emptyCardFolderId]) —
  /// sama seperti kartu kosong yang di-drag/dipindah manual ke folder.
  Future<void> activateIdentity({
    required String kelas,
    required String halaqoh,
    required String nama,
    String? folderId,
  }) async {
    if (_scope != null && !_scope!.canAccessKelasHalaqoh(kelas, halaqoh)) {
      throw ScopeViolationException(
        'Anda tidak punya akses untuk kelas $kelas / $halaqoh.',
      );
    }
    final key = reportIdentityKey(kelas, halaqoh, nama);
    _rememberActivatedDisplay(kelas, halaqoh, nama);
    // BUG FIX: dulu kapitalisasi asli cuma disimpan di RAM
    // (_rememberActivatedDisplay), gak di-persist — begitu app di-kill
    // sebelum identitas ini sempat dibuatkan laporan pertamanya, nama
    // santri di kartunya balik jadi huruf kecil semua (fallback ke
    // identityKey yang emang sengaja lowercase). Sekarang ikut disimpan
    // ke disk juga.
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

  int countInFolder(String folderId) {
    String key(SantriRecord r) =>
        '${r.namaAnak.trim().toLowerCase()}|${r.kelas}|${r.halaqoh}';
    return _scoped.where((r) => r.folderId == folderId).map(key).toSet().length;
  }

  /// Hapus PERMANEN semua laporan yang ada di dalam folder [folderId] —
  /// dipakai waktu folder itu sendiri dihapus (hapus folder = ikut hapus
  /// semua laporan di dalamnya, bukan cuma dikeluarkan dari folder).
  Future<void> deleteAllInFolder(String folderId) async {
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
    for (final id in recordIds) {
      final record = _findById(id);
      if (record == null) continue;
      await StorageService.instance.upsert(
        folderId == null ? record.copyWith(clearFolder: true) : record.copyWith(folderId: folderId),
      );
    }
    await load();
  }

  /// Pindahkan SEMUA laporan (semua pekan) milik santri [namaAnak] sekaligus
  /// ke folder [folderId] (null = keluarkan dari folder) — dipakai kartu
  /// santri di tab Laporan ([SantriReportCard]) waktu user pilih "Pindahkan
  /// ke Folder" buat kartu itu (beda dari [moveManyToFolder] biasa yang
  /// per-laporan/id).
  Future<void> moveAllForSantriToFolder(String namaAnak, String? folderId) async {
    final ids = recordsForSantri(namaAnak).map((r) => r.id).toList();
    await moveManyToFolder(ids, folderId);
  }

  /// Hapus SEMUA laporan (semua pekan) milik santri [namaAnak] sekaligus,
  /// plus lepas [identityKey]-nya dari daftar identitas aktif kalau ada
  /// (jaga-jaga kartu itu juga "diaktifkan" lewat Buat Laporan) — dipakai
  /// kartu santri di tab Laporan waktu user pilih "Hapus" buat kartu itu.
  Future<void> deleteAllForSantri(String namaAnak, String identityKey) async {
    final ids = recordsForSantri(namaAnak).map((r) => r.id).toList();
    for (final id in ids) {
      await StorageService.instance.delete(id);
    }
    await AppPrefsService.instance.removeActivatedIdentity(identityKey);
    await AppPrefsService.instance.removeActivatedIdentityDisplay(identityKey);
    _activatedKeys.remove(identityKey);
    _activatedFolders.remove(identityKey);
    _lastActivatedDisplay.remove(identityKey);
    await load();
  }

  /// Pindahkan kartu [card] ke folder [folderId] (null = keluarkan dari
  /// folder) — dipakai [SantriReportCard] (drag atau sheet aksi "Pindahkan
  /// ke Folder"/"Keluarkan dari Folder"), berlaku buat kartu yang SUDAH
  /// punya laporan (pindah semua laporannya lewat [moveAllForSantriToFolder])
  /// MAUPUN kartu yang MASIH KOSONG — kartu kosong tidak punya SantriRecord
  /// yang bisa dikasih folderId, jadi disimpan sebagai mapping identitas
  /// sementara (lihat [SantriCardInfo.emptyCardFolderId]) yang otomatis
  /// basi begitu laporan pertamanya dibuat.
  Future<void> moveIdentityToFolder(SantriCardInfo card, String? folderId) async {
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

  // --- Statistik ringkas untuk header ---
  int? _totalSantriCache;
  int? _totalHadirCache;
  int? _totalBarisSetoranCache;
  int _summaryCacheVersion = -1;

  void _refreshSummaryCacheIfStale() {
    if (_summaryCacheVersion == _dataVersion) return;
    _totalSantriCache = _scoped.map((r) => r.namaAnak).toSet().length;
    _totalHadirCache = _scoped
        .where((r) => r.keterangan == Keterangan.hadir || r.keterangan.isSanksiTanpaSetoran)
        .length;
    _totalBarisSetoranCache = _scoped.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));
    _summaryCacheVersion = _dataVersion;
  }

  /// Di-cache per [_dataVersion] — dulu di-scan ulang tiap `build()`
  /// (dipanggil bareng di dashboard Statistik & Home).
  int get totalSantri {
    _refreshSummaryCacheIfStale();
    return _totalSantriCache!;
  }
  // Tahsin+Tahfizh dihitung masuk KEDUA total ini juga (punya kedua
  // komponennya sekaligus) — biar "Tahfizh"/"Tahsin" di kartu ringkasan
  // tetap mencerminkan seluruh laporan yang punya komponen itu, bukan
  // cuma yang statusnya persis satu itu saja.
  bool _hasTahfizhComponent(SantriRecord r) =>
      r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh;
  bool _hasTahsinComponent(SantriRecord r) =>
      r.status == HafalanStatus.tahsin || r.status == HafalanStatus.tahsinTahfizh;

  // "Hadir" di sini artinya fisiknya hadir — termasuk 3 keterangan
  // sanksi (Tidak Setoran/Tahsin/Murojaah), karena itu santrinya HADIR
  // tapi nggak setor/tahsin/murojaah (males/ketiduran/dll), BUKAN nggak
  // masuk. Beda dari Izin Sakit/Izin/Izin Lomba/Izin Pelatihan/Alpa yang
  // memang nggak hadir secara fisik.
  int get totalHadir {
    _refreshSummaryCacheIfStale();
    return _totalHadirCache!;
  }
  int get totalBarisSetoran {
    _refreshSummaryCacheIfStale();
    return _totalBarisSetoranCache!;
  }

  /// Total ayat tersetor per pekan untuk [weekCount] pekan terakhir
  /// (termasuk pekan berjalan), dipakai chart "Ayat Tersetor/Minggu" di
  /// tab Statistik. Pekan dihitung Senin–Minggu — definisi yang SAMA
  /// dengan [WeekUtils.startOfWeek] (bukan sistem "pekan dalam bulan"
  /// punya Rekap Bulanan, karena rentang 6 pekan di sini bisa lintas
  /// bulan dan nggak butuh ikut aturan "pekan milik bulan mana").
  /// Hasil array terurut dari pekan TERLAMA -> TERBARU (index terakhir =
  /// pekan ini), jadi tinggal langsung dipetakan ke chart kiri-ke-kanan.
  List<WeeklyAyatPoint> weeklyAyatSummary({int weekCount = 6}) {
    final thisWeekStart = WeekUtils.startOfWeek(DateTime.now());
    final totals = List<int>.filled(weekCount, 0);

    for (final r in _scoped) {
      final recordWeekStart = WeekUtils.startOfWeek(r.tanggal);
      final diffWeeks = thisWeekStart.difference(recordWeekStart).inDays ~/ 7;
      final index = weekCount - 1 - diffWeeks; // 0 = pekan terlama
      if (index >= 0 && index < weekCount) {
        totals[index] += r.jumlahAyat;
      }
    }

    return List.generate(weekCount, (i) {
      final weekStart = thisWeekStart.subtract(Duration(days: (weekCount - 1 - i) * 7));
      return WeeklyAyatPoint(weekStart: weekStart, total: totals[i]);
    });
  }

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
  // Di-trim dulu sebelum di-dedupe (Set) — biar data lama yang kepeleset
  // spasi (mis. "VII Istanbul " vs "VII Istanbul") gak nongol jadi 2 chip
  // filter yang keliatan identik.
  List<String> get distinctKelas => _scoped
      .map((r) => r.kelas.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> get distinctHalaqoh => _scoped
      .map((r) => r.halaqoh.trim())
      .where((v) => v.isNotEmpty)
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
  /// Di-cache per [_dataVersion] — dulu getter ini (loop O(n) + sort) jalan
  /// ulang SETIAP kali `build()` dipanggil (termasuk saat user cuma ngetik
  /// di kolom search, yang notifyListeners()-nya sebenarnya tidak
  /// menyentuh data laporan sama sekali). Sekarang cuma dihitung ulang
  /// kalau `_all`/`_scope` beneran berubah (lewat load()/updateScope()).
  List<SantriSummary> get santriList {
    if (_santriListCacheVersion == _dataVersion && _santriListCache != null) {
      return _santriListCache!;
    }
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
    _santriListCache = list;
    _santriListCacheVersion = _dataVersion;
    return list;
  }

  /// Semua laporan milik satu santri (match nama, case-insensitive),
  /// terbaru duluan. Di-cache per (nama, [_dataVersion]) — dipanggil
  /// berulang dari halaman Detail Santri & tab Laporan.
  final Map<String, List<SantriRecord>> _recordsForSantriCache = {};
  int _recordsForSantriCacheVersion = -1;
  List<SantriRecord> recordsForSantri(String namaAnak) {
    if (_recordsForSantriCacheVersion != _dataVersion) {
      _recordsForSantriCache.clear();
      _recordsForSantriCacheVersion = _dataVersion;
    }
    final key = namaAnak.trim().toLowerCase();
    return _recordsForSantriCache.putIfAbsent(key, () {
      final list = _scoped.where((r) => r.namaAnak.trim().toLowerCase() == key).toList()
        ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return list;
    });
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

  /// Semua laporan, terbaru duluan — dipakai halaman Kehadiran. Di-cache
  /// per [_dataVersion] (sort O(n log n) tiap build kalau tidak di-cache).
  List<SantriRecord>? _allSortedByDateDescCache;
  int _allSortedCacheVersion = -1;
  List<SantriRecord> get allSortedByDateDesc {
    if (_allSortedCacheVersion != _dataVersion) {
      _allSortedByDateDescCache = List<SantriRecord>.from(_scoped)
        ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
      _allSortedCacheVersion = _dataVersion;
    }
    return _allSortedByDateDescCache!;
  }

  // --- Rekap bulanan (EXISTING — dipertahankan apa adanya) ---
  // Semua method rekap di bawah (per bulan/pekan/hari) sekarang di-cache
  // per [_dataVersion] pakai Map biasa (key = string tanggal), soalnya
  // dipanggil BERULANG dari widget yang sama tiap build (Rekap Bulanan,
  // Rekap Pekan, Rekap Harian, Generate Rekap Bulanan/Pekanan) — dulu
  // masing-masing scan+sort ulang `_scoped` tiap kali dipanggil, padahal
  // datanya belum tentu berubah antar-build (mis. cuma ganti tab bulan
  // lain lalu balik lagi, atau parent widget rebuild karena alasan lain).
  final Map<String, List<SantriRecord>> _recordsInMonthCache = {};
  final Map<String, List<SantriRecord>> _recordsInMonthWeekCache = {};
  final Map<String, List<SantriRecord>> _recordsOnDateCache = {};
  final Map<String, List<MonthWeekSummary>> _monthWeekSummariesCache = {};
  final Map<String, List<SantriMonthlyRecap>> _monthlySantriRecapsCache = {};
  int _rekapCacheVersion = -1;

  void _clearRekapCacheIfStale() {
    if (_rekapCacheVersion == _dataVersion) return;
    _recordsInMonthCache.clear();
    _recordsInMonthWeekCache.clear();
    _recordsOnDateCache.clear();
    _monthWeekSummariesCache.clear();
    _monthlySantriRecapsCache.clear();
    _rekapCacheVersion = _dataVersion;
  }

  String _monthKey(DateTime month) => '${month.year}-${month.month}';
  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  List<SantriRecord> recordsInMonth(DateTime month) {
    _clearRekapCacheIfStale();
    return _recordsInMonthCache.putIfAbsent(_monthKey(month), () {
      // BUG FIX: dulu di sini cek kalender murni
      // (`r.tanggal.year == month.year && r.tanggal.month == month.month`),
      // sedangkan breakdown per-Pekan di bawah ([recordsInMonthWeek] /
      // [monthWeekSummaries]) pakai "kepemilikan pekan" (WeekUtils) —
      // yang bikin tanggal 1-2 hari di ujung bulan (mis. 31 Agustus, yang
      // milik Pekan 1 September) KEHITUNG di total atas sebagai "Agustus"
      // tapi TIDAK NONGOL di Pekan manapun (baik di Agustus maupun
      // September), keliatan kayak laporannya "hilang". Sekarang total di
      // sini dibangun dari GABUNGAN semua Pekan milik bulan ini (definisi
      // yang SAMA persis dengan breakdown per-Pekan), jadi total atas =
      // persis penjumlahan semua Pekan, dan tanggal 31 Agustus konsisten
      // "pindah rumah" ke Pekan 1 September di SEMUA tempat, bukan cuma
      // di breakdown pekan doang.
      final totalWeeks = WeekUtils.weeksInMonth(month);
      final seenIds = <String>{};
      final list = <SantriRecord>[];
      for (var weekIndex = 1; weekIndex <= totalWeeks; weekIndex++) {
        for (final r in recordsInMonthWeek(month, weekIndex)) {
          if (seenIds.add(r.id)) list.add(r);
        }
      }
      list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return list;
    });
  }

  int totalTahfizhInMonth(DateTime month) =>
      recordsInMonth(month).where(_hasTahfizhComponent).length;

  int totalTahsinInMonth(DateTime month) =>
      recordsInMonth(month).where(_hasTahsinComponent).length;

  int totalBarisInMonth(DateTime month) =>
      recordsInMonth(month).fold(0, (sum, r) => sum + (r.totalBaris ?? 0));

  // --- Pekan DALAM BULAN (BARU) — dipakai alur Statistik → Rekap Bulanan
  // → Pekan 1..6, dan indikator pekan di kartu santri tab Laporan. Lihat
  // catatan desain di WeekUtils. (Rekap Pekanan ISO Senin-Minggu yang dulu
  // ada di sini SUDAH DIHAPUS — diganti total oleh Rekap Bulanan → Pekan.)

  List<SantriRecord> recordsInMonthWeek(DateTime month, int weekIndex) {
    _clearRekapCacheIfStale();
    return _recordsInMonthWeekCache.putIfAbsent('${_monthKey(month)}-$weekIndex', () {
      // Dipakai langsung dari rentang tanggal pekan (BUKAN dari
      // recordsInMonth(month) + WeekUtils.weekOfMonth lagi) — soalnya pekan
      // sekarang boleh lintas bulan (lihat WeekUtils), jadi laporan di 1-2
      // hari ujung bulan yang "dimiliki" pekan bulan tetangga (mis. laporan
      // tanggal 1 Agustus yang masuk Pekan 5 Juli) tetap ketemu di sini,
      // walau tanggalnya sendiri bukan bulan [month].
      final range = WeekUtils.monthWeekRange(month, weekIndex);
      return _scoped.where((r) {
        final d = DateTime(r.tanggal.year, r.tanggal.month, r.tanggal.day);
        return !d.isBefore(range.start) && !d.isAfter(range.end);
      }).toList()
        // BUG FIX: dulu descending (terbaru duluan) — efeknya kolom
        // "Capaian" gabungan (mis. Pekan N di Rekap Bulanan, lihat
        // SantriMonthlyRecap.capaianForWeek) urutan hari setorannya
        // kebalik, kelihatan "dari bawah ke atas". Sekarang ascending
        // (tanggal lama -> baru) supaya semua tempat yang makan data ini
        // (Rekap Bulanan, Rekap Pekanan, tabel harian di
        // _PekanExpandedBody/RekapPekanBulanScreen) selalu urut kronologis
        // dari atas ke bawah.
        ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    });
  }

  /// Semua laporan tepat pada tanggal [date] (jam diabaikan) — dipakai
  /// [RekapHarianDetailScreen] buat nampilin laporan SATU HARI tertentu
  /// (dibuka dari tap baris hari di "Rekap Harian" pada Rekap Pekan).
  /// Terurut nama (case-insensitive).
  List<SantriRecord> recordsOnDate(DateTime date) {
    _clearRekapCacheIfStale();
    return _recordsOnDateCache.putIfAbsent(_dateKey(date), () {
      return _scoped.where((r) => DateUtils.isSameDay(r.tanggal, date)).toList()
        ..sort((a, b) => a.namaAnak.toLowerCase().compareTo(b.namaAnak.toLowerCase()));
    });
  }

  /// Ringkasan tiap Pekan (1..N sesuai jumlah hari bulan itu) dalam
  /// [month] — dipakai daftar "Pekan 1 / Pekan 2 / ..." di Rekap Bulanan.
  List<MonthWeekSummary> monthWeekSummaries(DateTime month) {
    _clearRekapCacheIfStale();
    return _monthWeekSummariesCache.putIfAbsent(_monthKey(month), () {
      final total = WeekUtils.weeksInMonth(month);
      return List.generate(total, (i) {
        final weekIndex = i + 1;
        final recs = recordsInMonthWeek(month, weekIndex);
        return MonthWeekSummary(
          weekIndex: weekIndex,
          range: WeekUtils.monthWeekRange(month, weekIndex),
          santriCount: recs.map((r) => r.namaAnak.trim().toLowerCase()).toSet().length,
          laporanCount: recs.length,
          totalBaris: recs.fold(0, (sum, r) => sum + (r.totalBaris ?? 0)),
        );
      });
    });
  }

  /// Nomor-nomor pekan dalam [month] yang sudah punya laporan untuk
  /// santri [namaAnak] (match nama, case-insensitive) — dipakai indikator
  /// "✓1 ✓2 3 4 5" di kartu santri.
  Set<int> weeksWithReportForSantriInMonth(String namaAnak, DateTime month) {
    final key = namaAnak.trim().toLowerCase();
    final total = WeekUtils.weeksInMonth(month);
    final result = <int>{};
    for (var weekIndex = 1; weekIndex <= total; weekIndex++) {
      final hasReport = recordsInMonthWeek(month, weekIndex)
          .any((r) => r.namaAnak.trim().toLowerCase() == key);
      if (hasReport) result.add(weekIndex);
    }
    return result;
  }

  /// Rekap gabungan PER SANTRI untuk satu bulan penuh (Pekan 1 s/d Pekan
  /// terakhir) — dipakai fitur "Generate Rekap Bulanan". Dibangun dari
  /// [recordsInMonthWeek] tiap pekan (bukan [recordsInMonth]) supaya
  /// konsisten dengan Rekap Bulanan → Pekan yang sudah ada, termasuk
  /// laporan di 1-2 hari ujung bulan yang "dimiliki" pekan bulan itu
  /// walau tanggalnya sendiri beda bulan (lihat catatan di
  /// [recordsInMonthWeek]). Hasil terurut nama (case-insensitive).
  List<SantriMonthlyRecap> monthlySantriRecaps(DateTime month) {
    _clearRekapCacheIfStale();
    final cached = _monthlySantriRecapsCache[_monthKey(month)];
    if (cached != null) return cached;

    final totalWeeks = WeekUtils.weeksInMonth(month);

    final recordsByKeyWeek = <String, Map<int, List<SantriRecord>>>{};
    final namaByKey = <String, String>{};
    final kelasByKey = <String, String>{};
    final halaqohByKey = <String, String>{};

    for (var weekIndex = 1; weekIndex <= totalWeeks; weekIndex++) {
      for (final r in recordsInMonthWeek(month, weekIndex)) {
        final key = r.namaAnak.trim().toLowerCase();
        recordsByKeyWeek.putIfAbsent(key, () => {}).putIfAbsent(weekIndex, () => []).add(r);
        // Dipakai buat tampilan nama/kelas/halaqoh — ambil dari laporan
        // TERBARU per santri (bukan pekan pertama) biar ikut kalau
        // santri pindah kelas/halaqoh di tengah bulan.
        if (!namaByKey.containsKey(key) || r.tanggal.isAfter(_latestSeen[key] ?? DateTime(0))) {
          namaByKey[key] = r.namaAnak.trim();
          kelasByKey[key] = r.kelas;
          halaqohByKey[key] = r.halaqoh;
          _latestSeen[key] = r.tanggal;
        }
      }
    }
    _latestSeen.clear();

    final result = <SantriMonthlyRecap>[];
    for (final key in recordsByKeyWeek.keys) {
      final byWeek = recordsByKeyWeek[key]!;
      final allRecords = byWeek.values.expand((l) => l).toList();
      final keteranganCounts = <Keterangan, int>{};
      // <-- BARU: hitung juga berapa kali status-nya "memang 0 baris"
      // (Tahsin murni / Muroja'ah-Tasmi') — dipakai SantriMonthlyRecap
      // .keteranganSummaryText supaya kolom Keterangan Rekap Bulanan tidak
      // cuma nampilin sanksi (Tdk Setoran/Tahsin/Murojaah), tapi juga
      // status ITU KENAPA baris-nya 0 (bukan berarti bolong laporan).
      final zeroBarisStatusCounts = <HafalanStatus, int>{};
      for (final r in allRecords) {
        if (r.keterangan != Keterangan.hadir) {
          keteranganCounts[r.keterangan] = (keteranganCounts[r.keterangan] ?? 0) + 1;
        }
        if (r.status.isZeroBarisByDesign) {
          zeroBarisStatusCounts[r.status] = (zeroBarisStatusCounts[r.status] ?? 0) + 1;
        }
      }
      result.add(SantriMonthlyRecap(
        nama: namaByKey[key] ?? key,
        kelas: kelasByKey[key] ?? '-',
        halaqoh: halaqohByKey[key] ?? '-',
        recordsByWeek: byWeek,
        totalBaris: allRecords.fold(0, (sum, r) => sum + (r.totalBaris ?? 0)),
        keteranganCounts: keteranganCounts,
        zeroBarisStatusCounts: zeroBarisStatusCounts,
      ));
    }
    result.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    _monthlySantriRecapsCache[_monthKey(month)] = result;
    return result;
  }

  // Dipakai sementara di dalam [monthlySantriRecaps] buat lacak laporan
  // terbaru per santri (kelas/halaqoh ditampilkan dari yang terbaru) —
  // di-clear lagi begitu selesai supaya tidak nyangkut antar pemanggilan.
  final Map<String, DateTime> _latestSeen = {};

  /// Laporan (kalau ada) milik santri [namaAnak] pada tanggal PERSIS [date]
  /// — dipakai buat cek "sudah ada laporan hari ini belum" waktu user tap
  /// kartu pekan buat isi laporan baru.
  ///
  /// BUG FIX: sebelumnya dicek per-PEKAN (niatnya cegah laporan duplikat
  /// — spek bagian 7), tapi efeknya laporan Senin ikut kebuka mode EDIT
  /// waktu user coba isi laporan hari Selasa di pekan yang sama, dan
  /// begitu tanggalnya diubah ke Selasa, laporan Senin yang asli JADI
  /// HILANG (record yang sama cuma dipindah tanggalnya, bukan dibuatkan
  /// record baru). Sekarang dicek per-HARI: laporan Senin & Selasa tetap
  /// dua record terpisah, cuma laporan di TANGGAL YANG SAMA PERSIS yang
  /// dianggap "sudah ada" dan dibuka sebagai edit (itu baru beneran
  /// duplikat). Berlaku juga untuk pekan yang sudah lewat (dulu masih
  /// pakai cek per-pekan, sekarang disamakan — lihat laporan_tab.dart
  /// _openWeek, search_results_screen.dart, dan folder_detail_screen.dart).
  SantriRecord? recordForSantriOnDate(String namaAnak, DateTime date) {
    final key = namaAnak.trim().toLowerCase();
    for (final r in _scoped) {
      if (r.namaAnak.trim().toLowerCase() == key && DateUtils.isSameDay(r.tanggal, date)) {
        return r;
      }
    }
    return null;
  }

  // <-- BARU: seluruh method ini. Semua laporan santri [namaAnak] dalam
  // rentang tanggal [start]..[end] (inklusif, kalender biasa bukan
  // "kepemilikan pekan"), terurut tanggal lama -> baru. Dipakai
  // openWeekForSantri buat deteksi "santri ini sudah punya laporan di
  // hari LAIN pekan berjalan yang belum ada follow-up hari ini" — lihat
  // catatan lengkap soal bug "laporan nambah 1" di
  // open_week_action.dart.
  List<SantriRecord> recordsForSantriInRange(String namaAnak, DateTime start, DateTime end) {
    if (end.isBefore(start)) return const [];
    final key = namaAnak.trim().toLowerCase();
    return _scoped.where((r) {
      if (r.namaAnak.trim().toLowerCase() != key) return false;
      final d = DateTime(r.tanggal.year, r.tanggal.month, r.tanggal.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
  }

  /// Kartu santri untuk tab Laporan — SATU kartu per santri (bukan per
  /// laporan/pekan), gabungan dari (a) santri yang sudah punya minimal 1
  /// laporan ([santriList], data asli) dan (b) identitas yang baru
  /// "diaktifkan" lewat "Buat Laporan" tapi belum ada laporannya sama
  /// sekali ([_activatedKeys]). Terurut nama.
  List<SantriCardInfo> get laporanCards {
    final now = DateTime.now();
    // Bulan PEMILIK pekan hari ini (bisa beda dari now.month di 1-2 hari
    // ujung bulan) — lihat WeekUtils.ownerMonth — biar konsisten sama
    // _buildCard di santri_report_card.dart yang makan data ini.
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
      // _activatedKeys disimpan lowercase+trim (lihat reportIdentityKey) —
      // tampilan kartu masih butuh kapitalisasi asli, tapi karena identitas
      // ini memang belum pernah diisi form manapun, tidak ada sumber lain
      // untuk kapitalisasi aslinya selain apa yang dipilih user saat
      // aktivasi (disimpan apa adanya lewat [activateIdentity] via
      // [_lastActivatedDisplay]).
      //
      // BUG FIX: kalau [display] BENERAN tidak ketemu (mis. data lokal
      // sempat hilang & belum sempat "Pulihkan dari Cloud", lihat
      // SettingsScreen & AppPrefsService.restoreActivatedMetaFromFirestore)
      // fallback-nya DULU langsung pakai [parts] apa adanya (identityKey,
      // yang emang sengaja lowercase buat perbandingan) — nama santri jadi
      // kelihatan huruf kecil semua. Sekarang minimal di-title-case dulu
      // ([toTitleCase]) biar SETIDAKNYA rapi, bukan jaminan 100% sama
      // persis kapitalisasi asli (lihat catatan di [toTitleCase]).
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
    if (_scope == null || _scope!.isAdmin) return list;
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

  /// Kartu yang "rumahnya" (currentFolderId) menunjuk ke folderId yang
  /// SUDAH TIDAK ADA lagi di [FoldersProvider] (folder yatim/hilang) —
  /// [validFolderIds] adalah kumpulan id folder yang MASIH ADA sekarang
  /// (diambil dari FoldersProvider.all di layar pemanggil).
  ///
  /// Skenario penyebab: laporan ini punya `folderId` yang tersimpan di
  /// Hive, tapi koleksi `reportFolders` sendiri baru ada belakangan di
  /// Firestore — kalau "Pulihkan dari Cloud" sempat dijalankan SEBELUM
  /// folder-nya pernah di-backup, folder-nya nggak ikut balik padahal
  /// laporan yang menunjuk ke folder itu tetap ada. Kartu begini otomatis
  /// KETUTUPAN dari tab Laporan biasa (currentFolderId != null -> tidak
  /// masuk daftar "Tanpa Folder") DAN dari section Folder (folder
  /// tujuannya sendiri sudah tidak ada buat ditampilkan) -- makanya
  /// kelihatan macam "hilang" padahal datanya masih utuh. Dipakai
  /// [OrphanedRecordsScreen] buat nampilin & "menyelamatkan" kartu-kartu
  /// ini (pindahkan ke folder yang masih ada, atau keluarkan dari folder).
  List<SantriCardInfo> orphanedFolderCards(Set<String> validFolderIds) {
    return laporanCards
        .where((c) => c.currentFolderId != null && !validFolderIds.contains(c.currentFolderId))
        .toList();
  }

  // Simpan kapitalisasi asli identitas yang baru diaktifkan pada sesi ini
  // (in-memory saja) — supaya kartu kosong yang baru dibuat langsung
  // tampil dengan huruf besar/kecil yang benar tanpa perlu reload app.
  // Begitu identitas itu punya laporan asli, sumber tampilan otomatis
  // pindah ke SantriRecord.namaAnak/kelas/halaqoh (lihat loop di atas),
  // jadi map ini tidak perlu dipersist.
  final Map<String, ({String nama, String kelas, String halaqoh})> _lastActivatedDisplay = {};

  void _rememberActivatedDisplay(String kelas, String halaqoh, String nama) {
    final key = reportIdentityKey(kelas, halaqoh, nama);
    _lastActivatedDisplay[key] = (nama: nama, kelas: kelas, halaqoh: halaqoh);
  }

  // --- Rekap PEKANAN (ISO) — DIHAPUS ---
  // Section ini dulu berisi availableWeeks/recordsInWeek/totalTahfizhInWeek/
  // santriAktifInWeek/weekDailyBreakdown/dkk, cuma dipakai satu-satunya
  // oleh Rekap Pekanan yang sekarang sudah dihapus total (diganti Rekap
  // Bulanan → Pekan, lihat monthWeekSummaries di atas). Dihapus semua
  // biar nggak jadi kode mati.

  /// Kelompokkan [records] per pasangan Kelas+Halaqoh — dipakai di Rekap
  /// Bulanan buat section "per Kelas & Halaqoh" (biar guru pembimbing bisa
  /// lihat/ekspor rekap kelompoknya sendiri). Terurut berdasarkan Kelas
  /// lalu Halaqoh; di dalam tiap grup, record terurut tanggal terlama dulu
  /// (kronologis, enak dibaca) lalu nama.
  List<KelasHalaqohGroup> groupByKelasHalaqoh(List<SantriRecord> records) {
    // Key dibikin dari kelas+halaqoh yang di-trim & disamakan huruf besar-
    // kecilnya buat PERBANDINGAN saja (bukan buat ditampilkan) — nutup
    // celah data lama/typo (mis. ada spasi nyempil "Halaqoh A ", atau beda
    // kapital "halaqoh a") yang dulu bikin 1 kelas+halaqoh yang SEBENARNYA
    // SAMA malah kepecah jadi 2 card rekap terpisah, padahal labelnya
    // keliatan identik di layar — itu penyebab bug "duplicate Halaqoh"
    // (dua card "Kelas X — Halaqoh A" nongol berturut-turut). Label yang
    // ditampilkan tetap dari data ASLI (sudah di-trim), bukan versi
    // lowercase-nya.
    final map = <String, List<SantriRecord>>{};
    final displayKelas = <String, String>{};
    final displayHalaqoh = <String, String>{};
    for (final r in records) {
      final kelasTrim = r.kelas.trim();
      final halaqohTrim = r.halaqoh.trim();
      final key = '${kelasTrim.toLowerCase()}|${halaqohTrim.toLowerCase()}';
      map.putIfAbsent(key, () => []).add(r);
      displayKelas.putIfAbsent(key, () => kelasTrim);
      displayHalaqoh.putIfAbsent(key, () => halaqohTrim);
    }
    final groups = map.entries.map((e) {
      final list = List<SantriRecord>.from(e.value)
        ..sort((a, b) {
          final byDate = a.tanggal.compareTo(b.tanggal);
          if (byDate != 0) return byDate;
          return a.namaAnak.toLowerCase().compareTo(b.namaAnak.toLowerCase());
        });
      return KelasHalaqohGroup(
        kelas: displayKelas[e.key]!,
        halaqoh: displayHalaqoh[e.key]!,
        records: list,
      );
    }).toList()
      ..sort((a, b) {
        final byKelas = a.kelas.toLowerCase().compareTo(b.kelas.toLowerCase());
        if (byKelas != 0) return byKelas;
        return a.halaqoh.toLowerCase().compareTo(b.halaqoh.toLowerCase());
      });
    return groups;
  }
}

/// Satu kelompok laporan milik 1 pasangan Kelas+Halaqoh dalam suatu
/// periode (dipakai Rekap Bulanan) — lihat [RecordsProvider.groupByKelasHalaqoh].
class KelasHalaqohGroup {
  final String kelas;
  final String halaqoh;
  final List<SantriRecord> records;
  const KelasHalaqohGroup({
    required this.kelas,
    required this.halaqoh,
    required this.records,
  });

  int get totalBaris => records.fold(0, (sum, r) => sum + (r.totalBaris ?? 0));
}

/// Satu titik data pekanan buat chart "Ayat Tersetor/Minggu" di tab
/// Statistik — lihat [RecordsProvider.weeklyAyatSummary]. [weekStart]
/// adalah tanggal Senin pekan itu (definisi [WeekUtils.startOfWeek]),
/// dipakai buat generate label rentang tanggal via [WeekUtils.rangeLabel]
/// biar labelnya konsisten sama sistem penanggalan pekanan yang dipakai
/// di seluruh app (bukan sekadar "W1"/"W2" generik).
class WeeklyAyatPoint {
  final DateTime weekStart;
  final int total;
  const WeeklyAyatPoint({required this.weekStart, required this.total});
}
