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
Future<void> showRecordFormSheet(BuildContext context,
    {SantriRecord? existing, String? initialFolderId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RecordFormSheet(existing: existing, initialFolderId: initialFolderId),
  );
}

class RecordFormSheet extends StatefulWidget {
  final SantriRecord? existing;
  // Kalau laporan ini dibuat langsung dari dalam halaman folder, laporan
  // baru otomatis masuk ke folder tersebut.
  final String? initialFolderId;
  const RecordFormSheet({super.key, this.existing, this.initialFolderId});

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

  // Tahfizh
  int? _surahNumber;
  final _ayatMulaiCtrl = TextEditingController();
  final _ayatSelesaiCtrl = TextEditingController();
  GeneratedLinesResult? _generated;
  bool _generating = false;
  String? _generateError;

  // Tahsin
  WafaLevel? _wafaLevel;
  final _halamanWafaCtrl = TextEditingController();

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
    _tanggal = e?.tanggal ?? DateTime.now();
    _kelas = e?.kelas;
    _halaqoh = e?.halaqoh;
    _nama = e?.namaAnak;
    _status = e?.status ?? HafalanStatus.tahfizh;
    _keterangan = e?.keterangan ?? Keterangan.hadir;
    _surahNumber = e?.surahNumber;
    _ayatMulaiCtrl.text = e?.ayatMulai?.toString() ?? '';
    _ayatSelesaiCtrl.text = e?.ayatSelesai?.toString() ?? '';
    _wafaLevel = e?.wafaLevel;
    _halamanWafaCtrl.text = e?.halamanWafa ?? '';
    _catatanCtrl.text = e?.catatan ?? '';

    if (e == null) {
      // Laporan baru (bukan edit) & user cuma punya 1 assignment
      // (kelas+halaqoh) -> pre-fill otomatis biar nggak perlu milih ulang
      // tiap bikin laporan (tetap bisa ganti manual kalau memang punya
      // lebih dari satu assignment, atau admin yang aktifkan mode lihat
      // semua kelas).
      final scope = _scope;
      if (scope != null && scope.user.assignments.length == 1) {
        final only = scope.user.assignments.first;
        _kelas = only.kelas;
        _halaqoh = only.halaqoh;
      }

      // Cek apakah ada draf laporan yang belum sempat disimpan dari sesi
      // sebelumnya (mis. bottom sheet ini ke-tutup nggak sengaja). Kalau
      // ada & isinya nggak kosong, tawarkan buat dilanjutkan lewat
      // banner di atas form — jangan langsung timpa isian pre-fill di
      // atas tanpa persetujuan user.
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

    if (e != null &&
        e.status == HafalanStatus.tahfizh &&
        e.totalBaris != null) {
      // Re-generate biar tampilan baris konsisten saat edit.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _generateLines(silent: true));
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _ayatMulaiCtrl.dispose();
    _ayatSelesaiCtrl.dispose();
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
        'surahNumber': _surahNumber,
        'ayatMulai': _ayatMulaiCtrl.text,
        'ayatSelesai': _ayatSelesaiCtrl.text,
        'wafaLevel': _wafaLevel?.name,
        'halamanWafa': _halamanWafaCtrl.text,
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
        _surahNumber = d['surahNumber'] as int?;
        _ayatMulaiCtrl.text = (d['ayatMulai'] as String?) ?? '';
        _ayatSelesaiCtrl.text = (d['ayatSelesai'] as String?) ?? '';
        final wafaName = d['wafaLevel'] as String?;
        _wafaLevel = wafaName != null ? WafaLevel.values.byName(wafaName) : null;
        _halamanWafaCtrl.text = (d['halamanWafa'] as String?) ?? '';
        _catatanCtrl.text = (d['catatan'] as String?) ?? '';
      });
    } catch (_) {
      // Draf format lama/nggak dikenal sebagian field-nya — biarkan aja
      // apa yang berhasil ke-restore, jangan crash.
    }

    if (_status == HafalanStatus.tahfizh &&
        _surahNumber != null &&
        _ayatMulaiCtrl.text.trim().isNotEmpty &&
        _ayatSelesaiCtrl.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateLines(silent: true));
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

  Future<void> _generateLines({bool silent = false}) async {
    if (_nama == null || _nama!.trim().isEmpty) {
      if (!silent) {
        setState(() => _generateError =
            'Pilih nama anak dulu — dipakai untuk cek riwayat baris.');
      }
      return;
    }
    if (_surahNumber == null ||
        _ayatMulaiCtrl.text.trim().isEmpty ||
        _ayatSelesaiCtrl.text.trim().isEmpty) {
      if (!silent) {
        setState(
            () => _generateError = 'Pilih surah dan isi rentang ayat dulu.');
      }
      return;
    }
    final start = int.tryParse(_ayatMulaiCtrl.text.trim());
    final end = int.tryParse(_ayatSelesaiCtrl.text.trim());
    if (start == null || end == null || start < 1 || end < start) {
      if (!silent) {
        setState(() => _generateError = 'Rentang ayat tidak valid.');
      }
      return;
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

    final result = QuranEngineService.instance.generateLines(
      surah: _surahNumber!,
      start: start,
      end: end,
      excludeLineIds: history,
    );

    setState(() {
      _generating = false;
      _generated = result;
      if (!result.available) {
        _generateError =
            'Mapping baris belum tersedia untuk surah ini pada dataset aktif (${QuranEngineService.instance.missingText()}).';
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

    if (isiStatusCapaian && _status == HafalanStatus.tahfizh) {
      if (_surahNumber == null ||
          _generated == null ||
          !_generated!.available) {
        _localMessengerKey.currentState?.showSnackBar(
          const SnackBar(
              content:
                  Text('Generate baris dulu sebelum simpan (untuk tahfizh).')),
        );
        return;
      }
    }

    final isTahfizh = isiStatusCapaian && _status == HafalanStatus.tahfizh;
    final isTahsin = isiStatusCapaian && _status == HafalanStatus.tahsin;

    final record = SantriRecord(
      id: widget.existing?.id ?? const Uuid().v4(),
      tanggal: _tanggal,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      kelas: _kelas!.trim(),
      halaqoh: _halaqoh!.trim(),
      namaAnak: _nama!.trim(),
      status: _status,
      keterangan: _keterangan,
      surahNumber: isTahfizh ? _surahNumber : null,
      surahName: isTahfizh ? kSurahNames[_surahNumber] : null,
      ayatMulai: isTahfizh ? int.tryParse(_ayatMulaiCtrl.text) : null,
      ayatSelesai: isTahfizh ? int.tryParse(_ayatSelesaiCtrl.text) : null,
      totalBaris: isTahfizh ? _generated?.totalBaris : null,
      lineIds: isTahfizh ? _generated?.newLineIds : null,
      wafaLevel: isTahsin ? _wafaLevel : null,
      halamanWafa: isTahsin ? _halamanWafaCtrl.text.trim() : null,
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
        body: DraggableScrollableSheet(
          initialChildSize: 0.92,
          maxChildSize: 0.96,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
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
                      children: [
                        Expanded(
                          child: Text(
                            _isEdit ? 'Edit Laporan' : 'Laporan Baru',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18),
                          ),
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
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                            20, 16, 20, mq.viewInsets.bottom + 24),
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
                                  onChanged: _onNamaChanged,
                                ),
                              ],
                            ),
                          ),
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
                                  child: _status == HafalanStatus.tahfizh
                                      ? _buildTahfizhFields(cs)
                                      : _buildTahsinFields(cs),
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
                                padding: const EdgeInsets.symmetric(vertical: 22),
                                textStyle: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              onPressed: _submit,
                              icon: const Icon(Icons.check_rounded, size: 26),
                              label: Text(
                                  _isEdit ? 'Simpan Perubahan' : 'Simpan Laporan'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
    // Bungkus card lama dilepas — section-nya sekarang sudah dibungkus
    // FormSectionCard di build(), jadi cukup Row polos biar nggak dobel-kartu.
    return Row(
      children: [
        Expanded(
          child: CategoryTile(
            label: HafalanStatus.tahfizh.label,
            icon: HafalanStatus.tahfizh.icon,
            color: cs.primary,
            active: _status == HafalanStatus.tahfizh,
            onTap: () {
              setState(() {
                _status = HafalanStatus.tahfizh;
                _generateError = null;
              });
              _markEditedAndScheduleDraftSave();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CategoryTile(
            label: HafalanStatus.tahsin.label,
            icon: HafalanStatus.tahsin.icon,
            color: AppColors.tahsinOn(context),
            active: _status == HafalanStatus.tahsin,
            onTap: () {
              setState(() {
                _status = HafalanStatus.tahsin;
                _generateError = null;
              });
              _markEditedAndScheduleDraftSave();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTahfizhFields(ColorScheme cs) {
    return Column(
      key: const ValueKey('tahfizh'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _surahNumber,
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
              _surahNumber = v;
              _generated = null;
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
                controller: _ayatMulaiCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  context,
                  icon: Icons.first_page_rounded,
                  label: 'Dari Ayat',
                  accent: cs.primary,
                ),
                onChanged: (_) {
                  setState(() => _generated = null);
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
                controller: _ayatSelesaiCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  context,
                  icon: Icons.last_page_rounded,
                  label: 'Sampai Ayat',
                  accent: cs.primary,
                ),
                onChanged: (_) {
                  setState(() => _generated = null);
                  _markEditedAndScheduleDraftSave();
                },
                validator: (v) => !_wajibIsiStatusCapaian
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              textStyle: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800),
            ),
            onPressed: _generating ? null : () => _generateLines(),
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high_rounded, size: 24),
            label: Text(_generating ? 'Menghitung...' : 'Generate Baris'),
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
        if (_generated != null && _generated!.available) ...[
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      Icon(Icons.format_list_numbered_rounded,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kolom Baris',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: cs.primary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_generated!.totalBaris} baris baru',
                          style: TextStyle(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_generated!.alreadyCountedLines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded,
                              size: 15, color: AppColors.tahsinOn(context)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_generated!.alreadyCountedLines.length} baris sudah pernah dihitung di laporan sebelumnya (tidak dihitung dobel)',
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
                if (_generated!.newLines.isEmpty &&
                    _generated!.alreadyCountedLines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(
                      'Semua baris di rentang ini sudah pernah dihitung sebelumnya.',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                if (_generated!.newLines.isNotEmpty) ...[
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _generated!.newLines.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 14, endIndent: 14),
                      itemBuilder: (context, i) {
                        final l = _generated!.newLines[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 13,
                            backgroundColor: cs.primary.withValues(alpha: 0.15),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary),
                            ),
                          ),
                          title: Text(
                              'Hal. ${l.pageNumber} — Baris ${l.lineNumber}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(l.ayatRangeText,
                              style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTahsinFields(ColorScheme cs) {
    return Column(
      key: const ValueKey('tahsin'),
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
    final firstRow = values.sublist(0, 3);
    final secondRow = values.sublist(3);

    Widget spacedRow(List<Keterangan> row) => Row(
          children: [
            for (int i = 0; i < row.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              chip(row[i]),
            ],
          ],
        );

    return Column(
      children: [
        spacedRow(firstRow),
        const SizedBox(height: 8),
        spacedRow(secondRow),
      ],
    );
  }
}
