import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/access/access_scope.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/app_prefs_service.dart';
import '../../../data/services/quran_engine_service.dart';
import '../../../providers/records_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Menampilkan modal bottom sheet full-height untuk tambah/edit laporan.
///
/// [presetKelas]/[presetHalaqoh]/[presetNama]/[presetTanggal]: dipakai saat
/// dibuka dari kartu santri di tab Laporan (lihat spek "1 santri = 1 card
/// laporan utama") untuk pekan yang BELUM ada laporannya — identitas
/// santri sudah pasti (dari kartunya), jadi field Kelas/Halaqoh/Nama
/// dikunci ([lockIdentity]) supaya guru nggak bisa "salah pindah" ke
/// santri lain di tengah pengisian laporan pekanan ini.
Future<void> showRecordFormSheet(
  BuildContext context, {
  SantriRecord? existing,
  String? initialFolderId,
  String? presetKelas,
  String? presetHalaqoh,
  String? presetNama,
  DateTime? presetTanggal,
  bool lockIdentity = false,
}) {
  return showModalBottomSheet(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RecordFormSheet(
      existing: existing,
      initialFolderId: initialFolderId,
      presetKelas: presetKelas,
      presetHalaqoh: presetHalaqoh,
      presetNama: presetNama,
      presetTanggal: presetTanggal,
      lockIdentity: lockIdentity,
    ),
  );
}

/// State 1 segmen Tahfizh di dalam form (surah + rentang ayat + hasil
/// generate barisnya sendiri). Form bisa punya >1 segmen kalau santri
/// setoran nyambung lintas surah dalam 1 pertemuan.
class _TahfizhSegState {
  int? surahNumber;
  final TextEditingController ayatMulaiCtrl = TextEditingController();
  final TextEditingController ayatSelesaiCtrl = TextEditingController();
  GeneratedLinesResult? generated;

  // --- Fallback manual buat juz yang belum ada di dataset baris (saat
  // ini baru Juz 1-10 & 26-30, Juz 11-25 belum). Dipakai HANYA kalau
  // generate balik `available: false` — user isi sendiri jumlah baris
  // biar laporan tetap bisa disimpan (lineIds otomatis kosong, jadi
  // tidak ikut logic exclude-baris-yang-sudah-dihitung).
  final TextEditingController manualBarisCtrl = TextEditingController();

  void dispose() {
    ayatMulaiCtrl.dispose();
    ayatSelesaiCtrl.dispose();
    manualBarisCtrl.dispose();
  }
}

/// State 1 segmen "bentuk Tilawah" (surah + rentang ayat, tanpa generate
/// baris) — dipakai Tahsin-mode-Tilawah & Muroja'ah/Tasmi'.
class _TilawahSegState {
  int? surahNumber;
  final TextEditingController ayatMulaiCtrl = TextEditingController();
  final TextEditingController ayatSelesaiCtrl = TextEditingController();

  void dispose() {
    ayatMulaiCtrl.dispose();
    ayatSelesaiCtrl.dispose();
  }
}

class RecordFormSheet extends StatefulWidget {
  final SantriRecord? existing;
  // Kalau laporan ini dibuat langsung dari dalam halaman folder, laporan
  // baru otomatis masuk ke folder tersebut.
  final String? initialFolderId;
  final String? presetKelas;
  final String? presetHalaqoh;
  final String? presetNama;
  final DateTime? presetTanggal;
  final bool lockIdentity;
  const RecordFormSheet({
    super.key,
    this.existing,
    this.initialFolderId,
    this.presetKelas,
    this.presetHalaqoh,
    this.presetNama,
    this.presetTanggal,
    this.lockIdentity = false,
  });

  @override
  State<RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<RecordFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // ScaffoldMessenger LOKAL punya sheet ini sendiri (bukan pakai punya
  // halaman di belakangnya). Kalau pakai ScaffoldMessenger.of(context)
  // biasa, snackbar-nya nembus ke Scaffold utama di BELAKANG modal
  // bottom sheet ini — jadinya kehalang/membelakangi sheet & nggak
  // kelihatan user. Dengan messenger lokal, snackbar-nya tampil DI
  // DALAM sheet ini, di depan.
  final _localMessengerKey = GlobalKey<ScaffoldMessengerState>();

  late DateTime _tanggal;

  // Kelas/Halaqoh/Nama Santri: SEKARANG murni pilihan dari daftar (nggak
  // ada lagi ketik bebas sama sekali) — makanya cukup nilai String?
  // biasa, nggak perlu TextEditingController lagi.
  String? _kelas;
  String? _halaqoh;
  String? _nama;

  late HafalanStatus _status;
  late Keterangan _keterangan;

  // Error manual buat 3 field select (di luar Form karena
  // DropdownButtonFormField dari [SelectField] nggak otomatis nyambung
  // sempurna ke error state kalau errorText di-drive manual kayak gini).
  String? _kelasError;
  String? _halaqohError;
  String? _namaError;

  // Tahfizh — list segmen (selalu >= 1 elemen). Tombol "+" di UI nambah
  // elemen baru kalau santri setoran nyambung lintas surah.
  List<_TahfizhSegState> _tahfizhSegs = [_TahfizhSegState()];
  bool _generating = false;
  String? _generateError;

  // Tahsin
  TahsinMode _tahsinMode = TahsinMode.wafa;
  WafaLevel? _wafaLevel;
  final _halamanWafaCtrl = TextEditingController();

  // Tilawah — dipakai bareng oleh: Tahsin bermode Tilawah, bagian Tahsin
  // di dalam Tahsin+Tahfizh (saat modenya Tilawah), dan Muroja'ah/Tasmi'
  // (yang bentuknya SELALU seperti Tilawah). Nggak ada generate baris di
  // sini sama sekali, sesuai spek.
  List<_TilawahSegState> _tilawahSegs = [_TilawahSegState()];

  final _catatanCtrl = TextEditingController();

  // Admin yang JUGA guru pembimbing (punya assignment sendiri): defaultnya
  // dibatasi ke kelas/halaqoh miliknya sendiri (sama seperti guru
  // pembimbing biasa) — toggle ini yang membuka opsi "lihat semua kelas"
  // kalau memang perlu input laporan di luar kelasnya sendiri sebagai
  // admin. Cuma relevan/ditampilkan kalau scope.isAdmin && punya
  // assignment sendiri.
  bool _adminBrowseAll = false;

  // Dipakai supaya warning "bukan kelas/halaqoh Anda sendiri" nggak
  // nongol berulang-ulang tiap rebuild buat kombinasi kelas+halaqoh yang
  // SAMA — cuma sekali tiap kali kombinasinya benar-benar berubah.
  String? _lastWarnedCombo;

  // --- Draft laporan baru ---
  // Cuma berlaku untuk laporan BARU (bukan edit) — lihat AppPrefsService.
  Timer? _draftDebounce;
  Map<String, dynamic>? _restorableDraft;
  bool _draftBannerVisible = false;

  bool get _isEdit => widget.existing != null;

  // Kalau bukan "Hadir", kolom status capaian nggak wajib diisi & bakal
  // dikosongin lagi pas disimpan (biar konsisten pas diekspor).
  bool get _wajibIsiStatusCapaian => _keterangan == Keterangan.hadir;

  AccessScope? get _scope => context.read<RecordsProvider>().scope;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tanggal = e?.tanggal ?? widget.presetTanggal ?? DateTime.now();
    _kelas = e?.kelas ?? widget.presetKelas;
    _halaqoh = e?.halaqoh ?? widget.presetHalaqoh;
    _nama = e?.namaAnak ?? widget.presetNama;
    _status = e?.status ?? HafalanStatus.tahfizh;
    _keterangan = e?.keterangan ?? Keterangan.hadir;
    if (e != null) {
      final tahfizhSegs = e.tahfizhSegmentsEffective;
      if (tahfizhSegs.isNotEmpty) {
        _tahfizhSegs = tahfizhSegs
            .map((s) => _TahfizhSegState()
              ..surahNumber = s.surahNumber
              ..ayatMulaiCtrl.text = s.ayatMulai.toString()
              ..ayatSelesaiCtrl.text = s.ayatSelesai.toString()
              // Kalau segmen lama ini dulu disimpan tanpa lineIds (berarti
              // dulu dipakai fallback manual), prefill lagi biar user tidak
              // perlu ngetik ulang kalau nanti generate ulang gagal lagi.
              ..manualBarisCtrl.text =
                  (s.lineIds.isEmpty && s.totalBaris > 0) ? s.totalBaris.toString() : '')
            .toList();
      }
      final tilawahSegs = e.tilawahSegmentsEffective;
      if (tilawahSegs.isNotEmpty) {
        _tilawahSegs = tilawahSegs
            .map((s) => _TilawahSegState()
              ..surahNumber = s.surahNumber
              ..ayatMulaiCtrl.text = s.ayatMulai.toString()
              ..ayatSelesaiCtrl.text = s.ayatSelesai.toString())
            .toList();
      }
    }
    _wafaLevel = e?.wafaLevel;
    _halamanWafaCtrl.text = e?.halamanWafa ?? '';
    _tahsinMode = e?.tahsinMode ?? TahsinMode.wafa;
    _catatanCtrl.text = e?.catatan ?? '';

    if (e == null) {
      // Laporan baru (bukan edit) & user cuma punya 1 assignment
      // (kelas+halaqoh) -> pre-fill otomatis biar nggak perlu milih ulang
      // tiap bikin laporan (tetap bisa ganti manual kalau memang punya
      // lebih dari satu assignment, atau admin yang aktifkan mode lihat
      // semua kelas). Dilewati kalau identitas sudah dikunci dari kartu
      // santri (widget.lockIdentity) — presetKelas/Halaqoh di atas sudah
      // pasti benar, jangan ditimpa.
      if (!widget.lockIdentity) {
        final scope = _scope;
        if (scope != null && scope.user.assignments.length == 1) {
          final only = scope.user.assignments.first;
          _kelas = only.kelas;
          _halaqoh = only.halaqoh;
        }
      }

      // Cek apakah ada draf laporan yang belum sempat disimpan dari sesi
      // sebelumnya (mis. bottom sheet ini ke-tutup nggak sengaja). Kalau
      // ada & isinya nggak kosong, tawarkan buat dilanjutkan lewat
      // banner di atas form — jangan langsung timpa isian pre-fill di
      // atas tanpa persetujuan user. Dilewati kalau identitas dikunci
      // (draf lama bisa saja punya kelas/halaqoh/nama santri LAIN, yang
      // kalau di-restore malah bertentangan sama kartu yang lagi dibuka).
      if (!widget.lockIdentity) {
        final raw = AppPrefsService.instance.recordDraftJson;
        if (raw != null && raw.trim().isNotEmpty) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final looksNonEmpty = ((map['kelas'] as String?) ?? '').isNotEmpty ||
                ((map['halaqoh'] as String?) ?? '').isNotEmpty ||
                ((map['nama'] as String?) ?? '').isNotEmpty ||
                ((map['catatan'] as String?) ?? '').isNotEmpty;
            if (looksNonEmpty) {
              _restorableDraft = map;
              _draftBannerVisible = true;
            }
          } catch (_) {
            // Draf korup/format lama — abaikan aja, jangan sampai bikin
            // form ini crash cuma gara-gara draf lama yang nggak valid.
          }
        }
      }
    }

    if (e != null &&
        (e.status == HafalanStatus.tahfizh || e.status == HafalanStatus.tahsinTahfizh) &&
        e.totalBaris != null) {
      // Re-generate biar tampilan baris konsisten saat edit.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _generateAllLines(silent: true));
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    for (final s in _tahfizhSegs) {
      s.dispose();
    }
    for (final s in _tilawahSegs) {
      s.dispose();
    }
    _halamanWafaCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  // --- Opsi kelas/halaqoh/nama santri ---

  bool get _hasOwnAssignments => (_scope?.user.assignments ?? const []).isNotEmpty;

  /// Admin yang JUGA punya assignment sendiri: default dibatasi ke
  /// assignment-nya sendiri (sama seperti guru pembimbing biasa), kecuali
  /// mode "lihat semua kelas" diaktifkan. Admin TANPA assignment sendiri
  /// (murni admin) selalu nggak dibatasi (karena nggak ada "kelas
  /// sendiri" yang bisa jadi default). Guru pembimbing biasa (bukan
  /// admin) selalu dibatasi.
  bool get _restrictToOwn {
    final scope = _scope;
    if (scope == null) return false;
    if (!_hasOwnAssignments) return false;
    if (scope.isAdmin) return !_adminBrowseAll;
    return true;
  }

  bool get _showAdminBrowseToggle {
    final scope = _scope;
    return scope != null && scope.isAdmin && _hasOwnAssignments;
  }

  List<String> _kelasOptions() {
    final scope = _scope;
    final dataset = context.read<RecordsProvider>();
    final accessibleStudents = context.read<StudentsProvider>().accessibleFor(scope);
    if (_restrictToOwn) {
      return (scope!.user.assignments.map((a) => a.kelas).toSet().toList()..sort());
    }
    return ({...dataset.distinctKelas, ...accessibleStudents.map((s) => s.kelas)}.toList()..sort());
  }

  // PENTING: kelas & halaqoh adalah PASANGAN per assignment (lihat
  // KelasHalaqoh) — makanya opsi halaqoh di sini DIPENGARUHI kelas yang
  // lagi dipilih (_kelas), bukan gabungan bebas semua halaqoh yang
  // pernah diampu user ini di kelas manapun.
  List<String> _halaqohOptions() {
    final scope = _scope;
    final dataset = context.read<RecordsProvider>();
    final accessibleStudents = context.read<StudentsProvider>().accessibleFor(scope);
    if (_restrictToOwn) {
      final validForKelas = scope!.user.assignments
          .where((a) => a.kelas == _kelas)
          .map((a) => a.halaqoh)
          .toList();
      // Kelas belum dipilih (atau belum cocok assignment manapun) ->
      // tampilkan union semua halaqoh assignment-nya dulu, biar dropdown
      // nggak kosong; begitu kelas valid dipilih, otomatis menyempit ke
      // halaqoh yang benar-benar berpasangan.
      return validForKelas.isNotEmpty
          ? validForKelas
          : (scope.user.assignments.map((a) => a.halaqoh).toSet().toList()..sort());
    }
    return ({...dataset.distinctHalaqoh, ...accessibleStudents.map((s) => s.halaqoh)}.toList()..sort());
  }

  /// Nama santri: HARUS kelas & halaqoh sudah dipilih dulu, baru
  /// nampilin santri yang benar-benar ada di kombinasi kelas+halaqoh itu
  /// — bukan gabungan semua santri dari semua kelas/halaqoh kayak
  /// sebelumnya. Gabungan riwayat laporan (sudah otomatis discope lewat
  /// RecordsProvider) + data master santri assignment ini — supaya user
  /// juga bisa pilih santri yang belum pernah dilaporkan sama sekali,
  /// tanpa pernah nampilin nama santri kelas/halaqoh lain.
  List<String> _namaOptions() {
    if (_kelas == null || _kelas!.trim().isEmpty || _halaqoh == null || _halaqoh!.trim().isEmpty) {
      return const [];
    }
    final dataset = context.read<RecordsProvider>();
    final accessibleStudents = context.read<StudentsProvider>().accessibleFor(_scope);
    final names = <String>{
      ...accessibleStudents
          .where((s) => s.kelas == _kelas && s.halaqoh == _halaqoh)
          .map((s) => s.nama),
      ...dataset.all
          .where((r) => r.kelas == _kelas && r.halaqoh == _halaqoh)
          .map((r) => r.namaAnak),
    };
    return names.toList()..sort();
  }

  // --- Handler perubahan pilihan ---

  void _onKelasChanged(String? v) {
    setState(() {
      _kelas = v;
      _kelasError = null;
    });
    // Kelas ganti -> halaqoh yang lagi kepilih mungkin udah nggak valid
    // buat kelas baru ini (khusus mode dibatasi assignment sendiri) ->
    // reset biar nggak nyangkut pasangan yang salah. Nama santri ikut
    // di-resync juga karena bergantung kombinasi kelas+halaqoh.
    final validHalaqoh = _halaqohOptions();
    if (_halaqoh != null && !validHalaqoh.contains(_halaqoh)) {
      setState(() => _halaqoh = null);
    }
    _resyncNamaIfInvalid();
    _maybeWarnOwnership();
    _markEditedAndScheduleDraftSave();
  }

  void _onHalaqohChanged(String? v) {
    setState(() {
      _halaqoh = v;
      _halaqohError = null;
    });
    _resyncNamaIfInvalid();
    _maybeWarnOwnership();
    _markEditedAndScheduleDraftSave();
  }

  void _onNamaChanged(String? v) {
    setState(() {
      _nama = v;
      _namaError = null;
    });
    _markEditedAndScheduleDraftSave();
  }

  void _resyncNamaIfInvalid() {
    final validNama = _namaOptions();
    if (_nama != null && !validNama.contains(_nama)) {
      setState(() => _nama = null);
    }
  }

  void _setAdminBrowseAll(bool value) {
    setState(() => _adminBrowseAll = value);
    final validKelas = _kelasOptions();
    if (_kelas != null && !validKelas.contains(_kelas)) {
      setState(() => _kelas = null);
    }
    final validHalaqoh = _halaqohOptions();
    if (_halaqoh != null && !validHalaqoh.contains(_halaqoh)) {
      setState(() => _halaqoh = null);
    }
    _resyncNamaIfInvalid();
    _maybeWarnOwnership();
    _markEditedAndScheduleDraftSave();
  }

  /// Kalau kelas+halaqoh yang lagi dipilih BUKAN salah satu assignment
  /// user yang login (cuma bisa terjadi kalau admin, karena guru
  /// pembimbing biasa nggak pernah bisa milih di luar assignment-nya
  /// sendiri) — kasih tahu lewat snackbar LOKAL di dalam sheet ini
  /// (bukan snackbar halaman di belakangnya, biar nggak membelakangi/
  /// ketutup sheet).
  void _maybeWarnOwnership() {
    final scope = _scope;
    if (scope == null || _kelas == null || _halaqoh == null) return;
    final mismatched =
        !scope.user.assignments.any((a) => a.kelas == _kelas && a.halaqoh == _halaqoh);
    final comboKey = '$_kelas|$_halaqoh';
    if (!mismatched) {
      _lastWarnedCombo = null;
      return;
    }
    if (_lastWarnedCombo == comboKey) return;
    _lastWarnedCombo = comboKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _localMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            scope.isAdmin
                ? 'Anda mengisi laporan ini sebagai Admin — kelas/halaqoh ini bukan tanggung jawab Anda sendiri.'
                : 'Kelas/halaqoh ini bukan tanggung jawab Anda.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  // --- Draft laporan baru ---

  void _markEditedAndScheduleDraftSave() {
    if (_isEdit) return;
    // Begitu user mulai pilih/ketik sendiri, banner "lanjutkan draf lama"
    // udah nggak relevan lagi (isian yang sedang berjalan SEKARANG-lah
    // yang jadi draf terbaru).
    if (_draftBannerVisible) {
      setState(() => _draftBannerVisible = false);
    }
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 500), _persistDraftNow);
  }

  Map<String, dynamic> _draftSnapshot() => {
        'tanggal': _tanggal.toIso8601String(),
        'kelas': _kelas,
        'halaqoh': _halaqoh,
        'nama': _nama,
        'status': _status.name,
        'keterangan': _keterangan.name,
        'tahfizhSegs': _tahfizhSegs
            .map((s) => {
                  'surahNumber': s.surahNumber,
                  'ayatMulai': s.ayatMulaiCtrl.text,
                  'ayatSelesai': s.ayatSelesaiCtrl.text,
                })
            .toList(),
        'tahsinMode': _tahsinMode.name,
        'wafaLevel': _wafaLevel?.name,
        'halamanWafa': _halamanWafaCtrl.text,
        'tilawahSegs': _tilawahSegs
            .map((s) => {
                  'surahNumber': s.surahNumber,
                  'ayatMulai': s.ayatMulaiCtrl.text,
                  'ayatSelesai': s.ayatSelesaiCtrl.text,
                })
            .toList(),
        'catatan': _catatanCtrl.text,
      };

  Future<void> _persistDraftNow() async {
    if (_isEdit || !mounted) return;
    await AppPrefsService.instance.saveRecordDraft(jsonEncode(_draftSnapshot()));
  }

  Future<void> _clearDraft() async {
    _draftDebounce?.cancel();
    await AppPrefsService.instance.clearRecordDraft();
  }

  void _restoreDraft() {
    final d = _restorableDraft;
    if (d == null) return;
    try {
      setState(() {
        _draftBannerVisible = false;
        final tanggalStr = d['tanggal'] as String?;
        if (tanggalStr != null) {
          _tanggal = DateTime.tryParse(tanggalStr) ?? _tanggal;
        }
        _kelas = d['kelas'] as String?;
        _halaqoh = d['halaqoh'] as String?;
        _nama = d['nama'] as String?;
        final statusName = d['status'] as String?;
        if (statusName != null) {
          _status = HafalanStatus.values.byName(statusName);
        }
        final keteranganName = d['keterangan'] as String?;
        if (keteranganName != null) {
          _keterangan = Keterangan.values.byName(keteranganName);
        }
        final tahfizhSegsRaw = d['tahfizhSegs'] as List?;
        if (tahfizhSegsRaw != null && tahfizhSegsRaw.isNotEmpty) {
          _tahfizhSegs = tahfizhSegsRaw.map((raw) {
            final m = raw as Map<String, dynamic>;
            return _TahfizhSegState()
              ..surahNumber = m['surahNumber'] as int?
              ..ayatMulaiCtrl.text = (m['ayatMulai'] as String?) ?? ''
              ..ayatSelesaiCtrl.text = (m['ayatSelesai'] as String?) ?? '';
          }).toList();
        }
        final wafaName = d['wafaLevel'] as String?;
        _wafaLevel = wafaName != null ? WafaLevel.values.byName(wafaName) : null;
        _halamanWafaCtrl.text = (d['halamanWafa'] as String?) ?? '';
        final tahsinModeName = d['tahsinMode'] as String?;
        _tahsinMode =
            tahsinModeName != null ? TahsinMode.values.byName(tahsinModeName) : TahsinMode.wafa;
        final tilawahSegsRaw = d['tilawahSegs'] as List?;
        if (tilawahSegsRaw != null && tilawahSegsRaw.isNotEmpty) {
          _tilawahSegs = tilawahSegsRaw.map((raw) {
            final m = raw as Map<String, dynamic>;
            return _TilawahSegState()
              ..surahNumber = m['surahNumber'] as int?
              ..ayatMulaiCtrl.text = (m['ayatMulai'] as String?) ?? ''
              ..ayatSelesaiCtrl.text = (m['ayatSelesai'] as String?) ?? '';
          }).toList();
        }
        _catatanCtrl.text = (d['catatan'] as String?) ?? '';
      });
    } catch (_) {
      // Draf format lama/nggak dikenal sebagian field-nya — biarkan aja
      // apa yang berhasil ke-restore, jangan crash.
    }

    if ((_status == HafalanStatus.tahfizh || _status == HafalanStatus.tahsinTahfizh) &&
        _tahfizhSegs.every((s) =>
            s.surahNumber != null &&
            s.ayatMulaiCtrl.text.trim().isNotEmpty &&
            s.ayatSelesaiCtrl.text.trim().isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateAllLines(silent: true));
    }
    _maybeWarnOwnership();
  }

  void _discardDraft() {
    setState(() {
      _draftBannerVisible = false;
      _restorableDraft = null;
    });
    _clearDraft();
  }

  void _addTahfizhSegment() {
    setState(() => _tahfizhSegs.add(_TahfizhSegState()));
    _markEditedAndScheduleDraftSave();
  }

  void _removeTahfizhSegment(int index) {
    setState(() {
      _tahfizhSegs[index].dispose();
      _tahfizhSegs.removeAt(index);
    });
    _markEditedAndScheduleDraftSave();
  }

  void _addTilawahSegment() {
    setState(() => _tilawahSegs.add(_TilawahSegState()));
    _markEditedAndScheduleDraftSave();
  }

  void _removeTilawahSegment(int index) {
    setState(() {
      _tilawahSegs[index].dispose();
      _tilawahSegs.removeAt(index);
    });
    _markEditedAndScheduleDraftSave();
  }

  /// Generate baris untuk SEMUA segmen Tahfizh sekaligus (bisa lebih dari
  /// 1 surah kalau santri setoran nyambung lintas surah dalam 1
  /// pertemuan). Tiap segmen digenerate sendiri-sendiri lewat
  /// [QuranEngineService.generateLines] (yang cuma nerima 1 surah per
  /// panggilan), lalu digabung. Baris yang sudah ke-generate di segmen
  /// SEBELUMNYA (dalam laporan yang sama) ikut di-exclude di segmen
  /// berikutnya — jaga-jaga kalau ada baris fisik yang somehow overlap
  /// antar segmen (jarang, tapi mungkin di batas transisi surah).
  Future<void> _generateAllLines({bool silent = false}) async {
    if (_nama == null || _nama!.trim().isEmpty) {
      if (!silent) {
        setState(() => _generateError =
            'Pilih nama anak dulu — dipakai untuk cek riwayat baris.');
      }
      return;
    }
    final ranges = <(int surah, int start, int end)>[];
    for (final seg in _tahfizhSegs) {
      if (seg.surahNumber == null ||
          seg.ayatMulaiCtrl.text.trim().isEmpty ||
          seg.ayatSelesaiCtrl.text.trim().isEmpty) {
        if (!silent) {
          setState(() =>
              _generateError = 'Pilih surah dan isi rentang ayat dulu (semua segmen).');
        }
        return;
      }
      final start = int.tryParse(seg.ayatMulaiCtrl.text.trim());
      final end = int.tryParse(seg.ayatSelesaiCtrl.text.trim());
      if (start == null || end == null || start < 1 || end < start) {
        if (!silent) {
          setState(() => _generateError = 'Rentang ayat tidak valid.');
        }
        return;
      }
      ranges.add((seg.surahNumber!, start, end));
    }

    setState(() {
      _generating = true;
      _generateError = null;
    });

    await QuranEngineService.instance.load();

    final history = mounted
        ? context.read<RecordsProvider>().lineHistoryFor(
              _nama!,
              excludeRecordId: widget.existing?.id,
            )
        : <String>{};

    final excludeSoFar = {...history};
    var anyUnavailable = false;
    for (var i = 0; i < ranges.length; i++) {
      final (surah, start, end) = ranges[i];
      final result = QuranEngineService.instance.generateLines(
        surah: surah,
        start: start,
        end: end,
        excludeLineIds: excludeSoFar,
      );
      _tahfizhSegs[i].generated = result;
      excludeSoFar.addAll(result.newLineIds);
      if (!result.available) anyUnavailable = true;
    }

    setState(() {
      _generating = false;
      if (anyUnavailable) {
        _generateError =
            'Mapping baris belum tersedia untuk salah satu surah pada dataset aktif (${QuranEngineService.instance.missingText()}).';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _tanggal = picked);
      _markEditedAndScheduleDraftSave();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus laporan ini?'),
        content: Text(
          'Laporan ${_nama ?? existing.namaAnak} tanggal '
          '${DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(existing.tanggal)} '
          'akan dihapus permanen dan tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<RecordsProvider>().delete(existing.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    setState(() {
      _kelasError = (_kelas == null || _kelas!.trim().isEmpty) ? 'Wajib dipilih' : null;
      _halaqohError = (_halaqoh == null || _halaqoh!.trim().isEmpty) ? 'Wajib dipilih' : null;
      _namaError = (_nama == null || _nama!.trim().isEmpty) ? 'Wajib dipilih' : null;
    });
    final formValid = _formKey.currentState!.validate();
    if (!formValid ||
        _kelasError != null ||
        _halaqohError != null ||
        _namaError != null) {
      return;
    }

    final isiStatusCapaian = _wajibIsiStatusCapaian;

    final needsTahfizhPart =
        _status == HafalanStatus.tahfizh || _status == HafalanStatus.tahsinTahfizh;

    if (isiStatusCapaian && needsTahfizhPart) {
      // Segmen dianggap siap kalau (a) generate sukses dari dataset, ATAU
      // (b) dataset belum meng-cover surah itu (mis. Juz 11-25) TAPI user
      // sudah isi jumlah baris manual sebagai fallback — lihat
      // `manualBarisCtrl` di `_TahfizhSegState`.
      final allReady = _tahfizhSegs.every((s) {
        if (s.surahNumber == null || s.generated == null) return false;
        if (s.generated!.available) return true;
        final manual = int.tryParse(s.manualBarisCtrl.text.trim());
        return manual != null && manual > 0;
      });
      if (!allReady) {
        final anyUnavailable =
            _tahfizhSegs.any((s) => s.generated != null && !s.generated!.available);
        _localMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text(anyUnavailable
                  ? 'Isi jumlah baris manual dulu untuk surah yang belum ada di dataset.'
                  : 'Generate baris dulu sebelum simpan (untuk hafalan Tahfizh).')),
        );
        return;
      }
    }

    final isTahfizhPart = isiStatusCapaian && needsTahfizhPart;
    final needsTahsinPart =
        _status == HafalanStatus.tahsin || _status == HafalanStatus.tahsinTahfizh;
    final isTahsinPart = isiStatusCapaian && needsTahsinPart;
    final isTahsinWafa = isTahsinPart && _tahsinMode == TahsinMode.wafa;
    final isTahsinTilawah = isTahsinPart && _tahsinMode == TahsinMode.tilawah;
    final isMurojaah = isiStatusCapaian && _status == HafalanStatus.murojaahTasmi;
    // Field "tilawah" (surah+ayat, tanpa generate) dipakai bareng oleh
    // Tahsin-mode-Tilawah DAN Muroja'ah/Tasmi'.
    final isTilawahShaped = isTahsinTilawah || isMurojaah;

    // Bentuk daftar segmen Tahfizh lengkap dari state form (bisa >1 kalau
    // santri setoran nyambung lintas surah). totalBaris/lineIds di bawah
    // tetap diisi AGREGAT dari semua segmen (lihat catatan di model) biar
    // konsumen lama (statistik/rekap) yang belum tahu soal multi-surah
    // tetap dapat angka yang benar. surahNumber/surahName/ayatMulai/
    // ayatSelesai (singular) diisi dari segmen PERTAMA saja, buat
    // backward compat.
    final tahfizhSegments = isTahfizhPart
        ? _tahfizhSegs
            .map((s) {
              // Fallback manual: dataset belum cover juz-nya (mis. Juz
              // 11-25), jadi baris dihitung dari input manual user,
              // bukan dari generate. lineIds sengaja dibiarkan kosong
              // (tidak ada mapping baris fisik buat di-exclude di
              // laporan berikutnya).
              final useManual = s.generated == null || !s.generated!.available;
              final manualBaris = useManual
                  ? (int.tryParse(s.manualBarisCtrl.text.trim()) ?? 0)
                  : 0;
              return TahfizhSegment(
                surahNumber: s.surahNumber!,
                surahName: kSurahNames[s.surahNumber!]!,
                ayatMulai: int.parse(s.ayatMulaiCtrl.text.trim()),
                ayatSelesai: int.parse(s.ayatSelesaiCtrl.text.trim()),
                totalBaris: useManual ? manualBaris : (s.generated?.totalBaris ?? 0),
                lineIds: useManual ? const [] : (s.generated?.newLineIds ?? const []),
              );
            })
            .toList()
        : null;
    final tilawahSegments = isTilawahShaped
        ? _tilawahSegs
            .where((s) =>
                s.surahNumber != null &&
                s.ayatMulaiCtrl.text.trim().isNotEmpty &&
                s.ayatSelesaiCtrl.text.trim().isNotEmpty)
            .map((s) => TilawahSegment(
                  surahNumber: s.surahNumber!,
                  surahName: kSurahNames[s.surahNumber!]!,
                  ayatMulai: int.tryParse(s.ayatMulaiCtrl.text.trim()) ?? 0,
                  ayatSelesai: int.tryParse(s.ayatSelesaiCtrl.text.trim()) ?? 0,
                ))
            .toList()
        : null;

    final record = SantriRecord(
      id: widget.existing?.id ?? const Uuid().v4(),
      tanggal: _tanggal,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      // Diedit = laporan yang sudah ada (_isEdit) dan barusan disimpan
      // ulang -> catat waktunya sekarang buat badge "Diedit" di kartu.
      // Laporan baru (bukan edit): tetap null.
      editedAt: _isEdit ? DateTime.now() : null,
      kelas: _kelas!.trim(),
      halaqoh: _halaqoh!.trim(),
      namaAnak: _nama!.trim(),
      status: _status,
      keterangan: _keterangan,
      surahNumber: tahfizhSegments?.first.surahNumber,
      surahName: tahfizhSegments?.first.surahName,
      ayatMulai: tahfizhSegments?.first.ayatMulai,
      ayatSelesai: tahfizhSegments?.first.ayatSelesai,
      totalBaris: tahfizhSegments?.fold<int>(0, (a, s) => a + s.totalBaris),
      lineIds: tahfizhSegments?.expand((s) => s.lineIds).toSet().toList(),
      tahfizhSegments: tahfizhSegments,
      tahsinMode: isTahsinPart ? _tahsinMode : null,
      wafaLevel: isTahsinWafa ? _wafaLevel : null,
      halamanWafa: isTahsinWafa ? _halamanWafaCtrl.text.trim() : null,
      tilawahSurahNumber: tilawahSegments?.isNotEmpty == true ? tilawahSegments!.first.surahNumber : null,
      tilawahSurahName: tilawahSegments?.isNotEmpty == true ? tilawahSegments!.first.surahName : null,
      tilawahAyatMulai: tilawahSegments?.isNotEmpty == true ? tilawahSegments!.first.ayatMulai : null,
      tilawahAyatSelesai: tilawahSegments?.isNotEmpty == true ? tilawahSegments!.first.ayatSelesai : null,
      tilawahSegments: tilawahSegments,
      catatan:
          _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
      folderId: widget.existing?.folderId ?? widget.initialFolderId,
      // Dicatat buat audit "siapa sebenarnya yang input laporan ini" —
      // penting khususnya buat kasus admin yang input di luar kelas/
      // halaqoh miliknya sendiri (lihat _maybeWarnOwnership). Laporan
      // lama yang di-edit ulang: ownerId tetap dari record aslinya kalau
      // sudah ada, biar nggak menimpa jejak siapa yang PERTAMA kali buat.
      ownerId: widget.existing?.ownerId ?? _scope?.user.id,
    );

    // context dipakai lagi setelah await -> WAJIB cek `mounted` dulu tiap
    // kali, biar lint "don't use BuildContext across async gaps" bersih
    // (pola .then()/.catchError() sebelumnya nggak kebaca aman oleh
    // analyzer walau ada context.mounted di dalam closure-nya).
    final recordsProvider = context.read<RecordsProvider>();
    try {
      await recordsProvider.upsert(record);
      // Laporan berhasil disimpan -> draf yang sempat kesimpen (kalau
      // ada) udah nggak relevan lagi, bersihkan.
      if (!_isEdit) await _clearDraft();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _localMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            e is ScopeViolationException ? e.message : 'Gagal menyimpan laporan.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    // context.watch di sini yang bikin build() ini rebuild otomatis tiap
    // RecordsProvider/StudentsProvider notifyListeners — helper _kelasOptions
    // dkk di atas boleh pakai context.read internal karena elemen ini
    // sudah "berlangganan" lewat watch di bawah ini.
    context.watch<RecordsProvider>();
    context.watch<StudentsProvider>();

    final kelasOptions = _kelasOptions();
    final halaqohOptions = _halaqohOptions();
    final namaOptions = _namaOptions();
    final comboBelumLengkap =
        _kelas == null || _kelas!.trim().isEmpty || _halaqoh == null || _halaqoh!.trim().isEmpty;

    return ScaffoldMessenger(
      key: _localMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // WAJIB false: tinggi sheet (sheetHeight di bawah) dan padding
        // bawah ListView sudah kita hitung manual pakai mq.viewInsets.bottom
        // (punya State ini, dari MediaQuery di LUAR Scaffold ini). Kalau
        // resizeToAvoidBottomInset dibiarkan default (true), Scaffold ini
        // ATURAN LAGI ngecilin constraints-nya sendiri buat keyboard —
        // jadinya tinggi keyboard kehitung 2x (dobel): sekali otomatis
        // oleh Scaffold, sekali lagi manual di padding ListView. Akibatnya
        // muncul celah kosong raksasa di bawah tombol Simpan pas keyboard
        // muncul & di-scroll (bug layar item "melayang" jauh dari keyboard).
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          // Ganti dari DraggableScrollableSheet ke pendekatan manual ini:
          // DraggableScrollableSheet menghitung persentase tingginya
          // relatif ke "safe area" bawaan modal, yang di device tertentu
          // ternyata BUKAN sama persis dengan tinggi layar penuh — jadi
          // walau initialChildSize < 1.0, ujung bawah sheet kadang nggak
          // benar-benar nempel ke bagian paling bawah layar, nyisain
          // celah tipis yang nampilin lagi navbar custom app di
          // belakangnya. Dengan LayoutBuilder, kita ambil `constraints`
          // yang dikasih Scaffold ini SENDIRI (yang sudah pasti = tinggi
          // layar penuh, karena showModalBottomSheet dipanggil dengan
          // useRootNavigator:true) lalu hitung tinggi sheet manual dari
          // situ — dijamin selalu presisi nempel ke y=0 (dim di atas,
          // rounded corner kelihatan) sampai y=tinggi layar (nutup penuh
          // ke bawah, termasuk area navbar custom, tanpa celah sama
          // sekali).
          builder: (context, constraints) {
            final sheetHeight = constraints.maxHeight * 0.9;
            return Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: sheetHeight,
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).bottomSheetTheme.backgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEdit ? 'Edit Laporan' : 'Laporan Baru',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              if (_nama != null && _nama!.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  _nama!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5,
                                    color: cs.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((_kelas ?? '').isNotEmpty || (_halaqoh ?? '').isNotEmpty)
                                  Text(
                                    '${_kelas ?? '-'} • Halaqoh ${_halaqoh ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ],
                          ),
                        ),
                        if (_isEdit)
                          IconButton(
                            onPressed: () => _confirmDelete(context),
                            icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                            tooltip: 'Hapus laporan ini',
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    // Padding bawah di SINI (bukan di dalam padding konten
                    // ListView) sengaja dipakai buat "mengecilkan" tinggi
                    // viewport ListView pas keyboard muncul — supaya field
                    // yang lagi difokus otomatis ke-scroll ke atas keyboard
                    // (mekanisme bawaan Flutter, Scrollable.ensureVisible,
                    // baru jalan kalau ukuran viewport-nya BENERAN mengecil;
                    // sebelumnya cuma padding konten ListView yang nambah,
                    // jadi ukuran viewport tetap sama dan field yang ketutup
                    // keyboard nggak pernah dianggap "di luar layar" —
                    // makanya sheet kelihatan nggak langsung nyesuain
                    // keyboard). Ini TIDAK bentrok dengan resizeToAvoidBottomInset
                    // yang sengaja false di atas, karena cuma satu tempat ini
                    // yang mengurangi viewInsets.bottom (bukan dobel).
                    child: Padding(
                      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          children: [
                            if (_draftBannerVisible) ...[
                              _buildDraftBanner(cs),
                              const SizedBox(height: 16),
                          ],
                          FormSectionCard(
                            title: 'Tanggal',
                            icon: Icons.event_rounded,
                            child: _buildDateField(cs),
                          ),
                          // Identitas santri (Kelas/Halaqoh/Nama) SENGAJA
                          // disembunyikan total (bukan cuma di-disable) saat
                          // dibuka dari kartu santri di tab Laporan
                          // (lockIdentity) — identitasnya sudah jelas dari
                          // konteks kartu itu, jadi form di sini cukup
                          // tanggal + status capaian + keterangan + catatan.
                          if (!widget.lockIdentity) ...[
                            const SizedBox(height: 16),
                            FormSectionCard(
                              title: 'Identitas Santri',
                              icon: Icons.badge_outlined,
                              child: Column(
                                children: [
                                  if (_showAdminBrowseToggle) ...[
                                    _buildAdminBrowseToggle(cs),
                                    const SizedBox(height: 12),
                                  ],
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SelectField(
                                          key: ValueKey('kelas_$_kelas'),
                                          value: _kelas,
                                          label: 'Kelas',
                                          icon: Icons.class_outlined,
                                          options: kelasOptions,
                                          errorText: _kelasError,
                                          accent: cs.primary,
                                          enabled: !widget.lockIdentity,
                                          onChanged: _onKelasChanged,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: SelectField(
                                          key: ValueKey('halaqoh_$_halaqoh'),
                                          value: _halaqoh,
                                          label: 'Halaqoh',
                                          icon: Icons.groups_outlined,
                                          options: halaqohOptions,
                                          errorText: _halaqohError,
                                          accent: cs.primary,
                                          enabled: !widget.lockIdentity,
                                          onChanged: _onHalaqohChanged,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SelectField(
                                    key: ValueKey('nama_$_nama'),
                                    value: _nama,
                                    label: 'Nama Anak',
                                    hint: comboBelumLengkap
                                        ? 'Pilih kelas & halaqoh dulu'
                                        : null,
                                    icon: Icons.person_outline_rounded,
                                    options: namaOptions,
                                    errorText: _namaError,
                                    accent: cs.primary,
                                    enabled: !widget.lockIdentity,
                                    onChanged: _onNamaChanged,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FormSectionCard(
                            title: 'Status Capaian',
                            icon: Icons.trending_up_rounded,
                            child: Column(
                              children: [
                                _buildStatusSelector(cs),
                                if (!_wajibIsiStatusCapaian) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded,
                                            size: 16, color: AppColors.tahsinOn(context)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Keterangan "${_keterangan.label}" — kolom status capaian nggak wajib diisi, akan dikosongkan saat disimpan.',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.tahsinOn(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: switch (_status) {
                                    HafalanStatus.tahfizh => _buildTahfizhFields(cs),
                                    HafalanStatus.tahsin => _buildTahsinFields(cs),
                                    HafalanStatus.tahsinTahfizh =>
                                      _buildTahsinTahfizhFields(cs),
                                    HafalanStatus.murojaahTasmi => _buildMurojaahFields(cs),
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          FormSectionCard(
                            title: 'Keterangan',
                            icon: Icons.fact_check_outlined,
                            child: _buildKeteranganSelector(cs),
                          ),
                          const SizedBox(height: 16),
                          FormSectionCard(
                            title: 'Catatan (Opsional)',
                            icon: Icons.edit_note_rounded,
                            child: TextFormField(
                              controller: _catatanCtrl,
                              maxLines: 3,
                              decoration: fieldDecoration(
                                context,
                                icon: Icons.notes_rounded,
                                label: 'Catatan',
                                hint: 'Catatan tambahan untuk guru pembimbing/ortu...',
                                accent: cs.primary,
                              ),
                              onChanged: (_) => _markEditedAndScheduleDraftSave(),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.primary.withValues(alpha: 0.14),
                                foregroundColor: cs.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              onPressed: _submit,
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: Text(
                                  _isEdit ? 'Simpan Perubahan' : 'Simpan Laporan'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ),
        );
          },
        ),
      ),
    );
  }

  Widget _buildDraftBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ada draf laporan yang belum sempat disimpan.',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kelihatannya form sebelumnya sempat tertutup sebelum disimpan. Lanjutkan isian tadi?',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _discardDraft,
                  child: const Text('Buang'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _restoreDraft,
                  child: const Text('Lanjutkan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBrowseToggle(ColorScheme cs) {
    final active = _adminBrowseAll;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _setAdminBrowseAll(!active),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.admin_panel_settings_outlined,
                size: 18, color: active ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                active
                    ? 'Mode Admin aktif — semua kelas & halaqoh bisa dipilih'
                    : 'Default: kelas & halaqoh Anda sendiri saja',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
            Switch(
              value: active,
              onChanged: _setAdminBrowseAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(ColorScheme cs) {
    // Skin senada dengan kolom lain (fieldDecoration: ikon dalam kotak
    // warna, rounded-16, filled) — nggak beda desain lagi dari kolom teks.
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: fieldDecoration(
          context,
          icon: Icons.calendar_month_rounded,
          label: 'Tanggal Laporan',
          accent: cs.primary,
        ).copyWith(
          suffixIcon:
              Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
        ),
        child: Text(
          DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_tanggal),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }

  Widget _buildStatusSelector(ColorScheme cs) {
    // 4 status sekarang -> grid 2x2 (2 baris) biar tetap muat & label
    // "Tahsin+Tahfizh"/"Muroja'ah/Tasmi'" yang lebih panjang nggak sempit.
    Widget tile(HafalanStatus s) {
      return Expanded(
        child: CategoryTile(
          label: s.label,
          icon: s.icon,
          color: AppColors.statusOn(context, s),
          active: _status == s,
          onTap: () {
            setState(() {
              _status = s;
              _generateError = null;
            });
            _markEditedAndScheduleDraftSave();
          },
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            tile(HafalanStatus.tahfizh),
            const SizedBox(width: 10),
            tile(HafalanStatus.tahsin),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tile(HafalanStatus.tahsinTahfizh),
            const SizedBox(width: 10),
            tile(HafalanStatus.murojaahTasmi),
          ],
        ),
      ],
    );
  }

  /// Panel hasil generate ("Kolom Baris") untuk SATU segmen — dipakai
  /// berulang, satu per segmen Tahfizh.
  Widget _buildGeneratedPanel(ColorScheme cs, GeneratedLinesResult result) {
    return Material(
      // Sebelumnya Container(decoration: BoxDecoration(color, border,
      // borderRadius)) — diganti Material(shape: RoundedRectangleBorder)
      // biar background+border tetap identik TAPI ListTile "Hal. X —
      // Baris Y" di dalamnya (lihat ListView di bawah) punya Material
      // terdekat yang benar, nggak ketutup DecoratedBox lagi.
      color: cs.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.format_list_numbered_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kolom Baris',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${result.totalBaris} baris baru',
                    style: TextStyle(
                        color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (result.alreadyCountedLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 15, color: AppColors.tahsinOn(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${result.alreadyCountedLines.length} baris sudah pernah dihitung di laporan sebelumnya (tidak dihitung dobel)',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.tahsinOn(context),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (result.newLines.isEmpty && result.alreadyCountedLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'Semua baris di rentang ini sudah pernah dihitung sebelumnya.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          if (result.newLines.isNotEmpty) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: result.newLines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 14, endIndent: 14),
                itemBuilder: (context, i) {
                  final l = result.newLines[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 13,
                      backgroundColor: cs.primary.withValues(alpha: 0.15),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                      ),
                    ),
                    title: Text('Hal. ${l.pageNumber} — Baris ${l.lineNumber}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(l.ayatRangeText, style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 1 blok surah+ayat Tahfizh (dipakai berulang buat tiap segmen).
  /// Segmen ke-2 dst punya label "Surah ke-N" + tombol hapus.
  Widget _buildTahfizhSegmentField(ColorScheme cs, int index) {
    final seg = _tahfizhSegs[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Surah ke-${index + 1} (nyambung)',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _removeTahfizhSegment(index),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 18, color: cs.error),
                  ),
                ),
              ],
            ),
          ),
        DropdownButtonFormField<int>(
          initialValue: seg.surahNumber,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
          decoration: fieldDecoration(
            context,
            icon: Icons.menu_book_rounded,
            label: 'Surah',
            accent: cs.primary,
          ),
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
          items: kSurahNames.entries
              .map((e) => DropdownMenuItem(
                  value: e.key, child: Text('${e.key}. ${e.value}')))
              .toList(),
          onChanged: (v) {
            setState(() {
              seg.surahNumber = v;
              seg.generated = null;
              _generateError = null;
            });
            _markEditedAndScheduleDraftSave();
          },
          validator: (v) =>
              !_wajibIsiStatusCapaian ? null : (v == null ? 'Pilih surah' : null),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: seg.ayatMulaiCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  context,
                  icon: Icons.first_page_rounded,
                  label: 'Dari Ayat',
                  accent: cs.primary,
                ),
                onChanged: (_) {
                  setState(() => seg.generated = null);
                  _markEditedAndScheduleDraftSave();
                },
                validator: (v) => !_wajibIsiStatusCapaian
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: seg.ayatSelesaiCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  context,
                  icon: Icons.last_page_rounded,
                  label: 'Sampai Ayat',
                  accent: cs.primary,
                ),
                onChanged: (_) {
                  setState(() => seg.generated = null);
                  _markEditedAndScheduleDraftSave();
                },
                validator: (v) => !_wajibIsiStatusCapaian
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
          ],
        ),
        if (seg.generated != null && seg.generated!.available) ...[
          const SizedBox(height: 14),
          _buildGeneratedPanel(cs, seg.generated!),
        ],
        if (seg.generated != null && !seg.generated!.available) ...[
          const SizedBox(height: 14),
          _buildManualBarisFallback(cs, seg),
        ],
      ],
    );
  }

  /// Panel fallback saat surah yang dipilih ada di rentang juz yang
  /// datasetnya belum tersedia (Juz 11-25) — generate otomatis tidak
  /// bisa jalan, jadi user isi sendiri jumlah baris hafalannya.
  Widget _buildManualBarisFallback(ColorScheme cs, _TahfizhSegState seg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: cs.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mapping baris belum tersedia untuk surah ini '
                  '(${QuranEngineService.instance.missingText()}). '
                  'Isi jumlah baris secara manual.',
                  style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: seg.manualBarisCtrl,
            keyboardType: TextInputType.number,
            decoration: fieldDecoration(
              context,
              icon: Icons.format_list_numbered_rounded,
              label: 'Jumlah Baris (manual)',
              accent: cs.error,
            ),
            onChanged: (_) => _markEditedAndScheduleDraftSave(),
          ),
        ],
      ),
    );
  }

  Widget _buildTahfizhFields(ColorScheme cs) {
    final totalBarisAll = _tahfizhSegs.fold<int>(0, (a, s) {
      if (s.generated != null && !s.generated!.available) {
        return a + (int.tryParse(s.manualBarisCtrl.text.trim()) ?? 0);
      }
      return a + (s.generated?.totalBaris ?? 0);
    });
    final anyGenerated = _tahfizhSegs.any((s) =>
        (s.generated != null && s.generated!.available) ||
        (s.generated != null &&
            !s.generated!.available &&
            (int.tryParse(s.manualBarisCtrl.text.trim()) ?? 0) > 0));
    return Column(
      key: const ValueKey('tahfizh'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _tahfizhSegs.length; i++) ...[
          _buildTahfizhSegmentField(cs, i),
          if (i != _tahfizhSegs.length - 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addTahfizhSegment,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Tambah Surah (nyambung)'),
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
            ),
            onPressed: _generating ? null : () => _generateAllLines(),
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high_rounded, size: 19),
            label: Text(_generating
                ? 'Menghitung...'
                : (_tahfizhSegs.length > 1 ? 'Generate Semua Baris' : 'Generate Baris')),
          ),
        ),
        if (_generateError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_generateError!,
                      style: TextStyle(fontSize: 12.5, color: cs.error)),
                ),
              ],
            ),
          ),
        ],
        if (_tahfizhSegs.length > 1 && anyGenerated) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.functions_rounded, size: 17, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Total ${_tahfizhSegs.length} surah',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.primary)),
                ),
                Text('$totalBarisAll baris baru',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: cs.primary)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Toggle kecil WAFA / Tilawah — dipakai di dalam status Tahsin & bagian
  /// Tahsin di Tahsin+Tahfizh.
  Widget _buildTahsinModeToggle(ColorScheme cs) {
    Widget seg(TahsinMode mode) {
      final selected = _tahsinMode == mode;
      final color = AppColors.tahsinOn(context);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _tahsinMode = mode);
            _markEditedAndScheduleDraftSave();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? color : cs.outlineVariant, width: 1.2),
            ),
            child: Text(
              mode.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? color : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg(TahsinMode.wafa),
        const SizedBox(width: 10),
        seg(TahsinMode.tilawah),
      ],
    );
  }

  /// 1 blok surah+ayat Tilawah (dipakai berulang buat tiap segmen).
  Widget _buildTilawahSegmentField(ColorScheme cs, int index, Color accent) {
    final seg = _tilawahSegs[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Surah ke-${index + 1} (nyambung)',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _removeTilawahSegment(index),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 18, color: cs.error),
                  ),
                ),
              ],
            ),
          ),
        DropdownButtonFormField<int>(
          initialValue: seg.surahNumber,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
          decoration: fieldDecoration(
            context,
            icon: Icons.menu_book_rounded,
            label: 'Surah',
            accent: accent,
          ),
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
          items: kSurahNames.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key}. ${e.value}')))
              .toList(),
          onChanged: (v) {
            setState(() => seg.surahNumber = v);
            _markEditedAndScheduleDraftSave();
          },
          validator: (v) =>
              !_wajibIsiStatusCapaian ? null : (v == null ? 'Pilih surah' : null),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: seg.ayatMulaiCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  context,
                  icon: Icons.first_page_rounded,
                  label: 'Dari Ayat',
                  accent: accent,
                ),
                onChanged: (_) => _markEditedAndScheduleDraftSave(),
                validator: (v) => !_wajibIsiStatusCapaian
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: seg.ayatSelesaiCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  context,
                  icon: Icons.last_page_rounded,
                  label: 'Sampai Ayat',
                  accent: accent,
                ),
                onChanged: (_) => _markEditedAndScheduleDraftSave(),
                validator: (v) => !_wajibIsiStatusCapaian
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Blok surah + rentang ayat TANPA tombol generate/hitung baris —
  /// dipakai untuk Tahsin bermode Tilawah, bagian Tahsin di
  /// Tahsin+Tahfizh (saat modenya Tilawah), dan Muroja'ah/Tasmi'. Bisa
  /// lebih dari 1 segmen (tombol "+") kalau setoran nyambung lintas surah.
  Widget _buildTilawahBlock(ColorScheme cs, {Key? key}) {
    final accent = AppColors.tahsinOn(context);
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _tilawahSegs.length; i++) ...[
          _buildTilawahSegmentField(cs, i, accent),
          if (i != _tilawahSegs.length - 1) const SizedBox(height: 14),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addTilawahSegment,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Tambah Surah (nyambung)'),
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTahsinFields(ColorScheme cs) {
    return Column(
      key: const ValueKey('tahsin'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTahsinModeToggle(cs),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _tahsinMode == TahsinMode.wafa
              ? _buildWafaBlock(cs, key: const ValueKey('wafa'))
              : _buildTilawahBlock(cs, key: const ValueKey('tilawah_in_tahsin')),
        ),
      ],
    );
  }

  /// Blok WAFA (jenjang + halaman) — dipisah dari [_buildTahsinFields]
  /// biar bisa dipakai ulang persis sama di dalam Tahsin+Tahfizh.
  Widget _buildWafaBlock(ColorScheme cs, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<WafaLevel>(
          initialValue: _wafaLevel,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
          decoration: fieldDecoration(
            context,
            icon: Icons.auto_stories_outlined,
            label: 'Jenjang WAFA',
            accent: AppColors.tahsinOn(context),
          ),
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
          items: WafaLevel.values
              .map((w) => DropdownMenuItem(value: w, child: Text(w.label)))
              .toList(),
          onChanged: (v) {
            setState(() => _wafaLevel = v);
            _markEditedAndScheduleDraftSave();
          },
          validator: (v) => !_wajibIsiStatusCapaian
              ? null
              : (v == null ? 'Pilih jenjang WAFA' : null),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _halamanWafaCtrl,
          decoration: fieldDecoration(
            context,
            icon: Icons.tag_rounded,
            label: 'Halaman',
            hint: 'mis. 12 atau 12-13',
            accent: AppColors.tahsinOn(context),
          ),
          onChanged: (_) => _markEditedAndScheduleDraftSave(),
          validator: (v) => !_wajibIsiStatusCapaian
              ? null
              : ((v == null || v.trim().isEmpty) ? 'Wajib diisi' : null),
        ),
      ],
    );
  }

  /// Label kecil berwarna buat memisahkan "Bagian Tahsin" / "Bagian
  /// Tahfizh" di dalam form gabungan Tahsin+Tahfizh.
  Widget _buildPartLabel(String text, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  /// Tahsin+Tahfizh = bagian Tahsin (toggle WAFA/Tilawah, seperti status
  /// Tahsin biasa) + bagian Tahfizh (surah+ayat+generate baris, seperti
  /// status Tahfizh biasa) sekaligus dalam satu laporan.
  Widget _buildTahsinTahfizhFields(ColorScheme cs) {
    return Column(
      key: const ValueKey('tahsin_tahfizh'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPartLabel('Bagian Tahsin', AppColors.tahsinOn(context),
            HafalanStatus.tahsin.icon),
        const SizedBox(height: 10),
        _buildTahsinModeToggle(cs),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _tahsinMode == TahsinMode.wafa
              ? _buildWafaBlock(cs, key: const ValueKey('wafa_in_combo'))
              : _buildTilawahBlock(cs, key: const ValueKey('tilawah_in_combo')),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _buildPartLabel(
            'Bagian Tahfizh (Hafalan Baru)', cs.primary, HafalanStatus.tahfizh.icon),
        const SizedBox(height: 10),
        _buildTahfizhFields(cs),
      ],
    );
  }

  /// Muroja'ah/Tasmi' selalu berbentuk seperti Tilawah — surah + rentang
  /// ayat, tanpa generate baris.
  Widget _buildMurojaahFields(ColorScheme cs) {
    return _buildTilawahBlock(cs, key: const ValueKey('murojaah'));
  }

  Widget _buildKeteranganSelector(ColorScheme cs) {
    // Dibuat justify
    Widget chip(Keterangan k) {
      final selected = _keterangan == k;
      final color = AppColors.keteranganColorOn(context, k.name);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _keterangan = k);
            _markEditedAndScheduleDraftSave();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.14)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? color : Colors.transparent, width: 1.3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(k.icon,
                    size: 17, color: selected ? color : cs.onSurfaceVariant),
                const SizedBox(height: 4),
                Text(
                  k.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const values = Keterangan.values;

    Widget spacedRow(List<Keterangan> row) => Row(
          children: [
            for (int i = 0; i < row.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              chip(row[i]),
            ],
          ],
        );

    // Dulu cuma 2 baris hardcode (sublist(0,3) + sublist(3)) — pas
    // Keterangan cuma 6 macam pas 3+3. Sekarang jumlahnya udah 9 (nambah
    // 3 keterangan sanksi), jadi di-chunk otomatis per 3 biar berapa pun
    // jumlah keterangan ke depannya nggak perlu ubah kode ini lagi (baris
    // terakhir yang nggak genap 3 tetap di-render, sisanya dibiarkan
    // kosong lewat Expanded standar yang sama).
    final rows = <List<Keterangan>>[];
    for (var i = 0; i < values.length; i += 3) {
      rows.add(values.sublist(i, i + 3 > values.length ? values.length : i + 3));
    }

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          spacedRow(rows[i]),
        ],
      ],
    );
  }
}
