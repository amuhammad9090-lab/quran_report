import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/access/access_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/app_prefs_service.dart';
import '../../../data/services/quran_engine_service.dart';
import '../../../providers/records_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/common/status_icons.dart';
import '../../widgets/common/viewer_guard.dart';
import '../../widgets/forms/field_decoration.dart';
import '../../widgets/forms/form_section_card.dart';
import '../../widgets/record/keterangan_selector.dart';
import '../../widgets/record/record_draft_banner.dart';
import '../../widgets/record/record_form_header.dart';
import '../../widgets/record/record_identity_fields.dart';
import '../../widgets/record/record_optional_status_notice.dart';
import '../../widgets/record/record_status_selector.dart';
import '../../widgets/record/record_submit_button.dart';
import '../../widgets/record/segment_states.dart';
import '../../widgets/record/tahfizh_fields.dart';
import '../../widgets/record/tahsin_fields.dart';
import '../../widgets/record/tilawah_fields.dart';
import 'record_form_options.dart';

/// Modal bottom sheet full-height untuk tambah/edit laporan. [presetKelas]/[presetHalaqoh]/
/// [presetNama]/[presetTanggal] dipakai saat dibuka dari kartu santri di tab Laporan; dengan
/// [lockIdentity] identitas dikunci agar guru tak "salah pindah" ke santri lain di tengah pengisian.
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
  if (blockIfViewer(context)) return Future<void>.value();
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

  // ScaffoldMessenger LOKAL milik sheet ini: ScaffoldMessenger.of(context) biasa membuat
  // snackbar tembus ke Scaffold di BELAKANG modal sehingga tak terlihat; dengan messenger
  // lokal snackbar tampil DI DALAM sheet, di depan.
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

  // Toggle "Hadir tanpa capaian hari ini": santri hadir tapi tak ada capaian untuk dilaporkan
  // (bukan izin/alpa). Sengaja EKSPLISIT (checkbox, default OFF), bukan capaian opsional diam-diam,
  // agar guru sadar menandai. Lihat _wajibIsiStatusCapaian & KeteranganSelector.
  bool _tanpaCapaian = false;

  // Error manual buat 3 field select (di luar Form karena
  // DropdownButtonFormField dari [SelectField] nggak otomatis nyambung
  // sempurna ke error state kalau errorText di-drive manual kayak gini).
  String? _kelasError;
  String? _halaqohError;
  String? _namaError;

  // Tahfizh — list segmen (selalu >= 1 elemen). Tombol "+" di UI nambah
  // elemen baru kalau santri setoran nyambung lintas surah.
  List<TahfizhSegState> _tahfizhSegs = [TahfizhSegState()];
  bool _generating = false;
  String? _generateError;

  // Tahsin
  TahsinMode _tahsinMode = TahsinMode.wafa;
  WafaLevel? _wafaLevel;
  final _halamanWafaCtrl = TextEditingController();

  // Tilawah — dipakai bersama oleh Tahsin mode Tilawah, bagian Tahsin di Tahsin+Tahfizh,
  // dan Muroja'ah/Tasmi' (selalu berbentuk Tilawah). Tidak ada generate baris di sini.
  List<TilawahSegState> _tilawahSegs = [TilawahSegState()];

  final _catatanCtrl = TextEditingController();

  // Nilai (ketik bebas). Ketuntasan dihitung otomatis di rekap pekanan/bulanan.
  final _nilaiCtrl = TextEditingController();

  // Pembatasan admin kini mengikuti toggle GLOBAL "Mode Admin" di Profil (AccessScope.adminModeActive,
  // AuthProvider.setAdminModeActive) yang mengatur form, folder, dan statistik sekaligus,
  // bukan toggle lokal per-sheet; lihat `_restrictToOwn` yang langsung membaca `scope.isAdmin`.

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

  // Kalau bukan "Hadir", ATAU "Hadir" tapi ditandai "tanpa capaian hari
  // ini" (lihat [_tanpaCapaian]), kolom status capaian nggak wajib diisi
  // & bakal dikosongin lagi pas disimpan (biar konsisten pas diekspor).
  bool get _wajibIsiStatusCapaian => _keterangan == Keterangan.hadir && !_tanpaCapaian;

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
            .map((s) => TahfizhSegState()
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
            .map((s) => TilawahSegState()
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
    _nilaiCtrl.text = e?.nilai ?? '';

    if (e == null) {
      // Laporan baru & user hanya punya 1 assignment -> pre-fill kelas+halaqoh (tetap bisa diganti).
      // Dilewati kalau identitas dikunci dari kartu santri (lockIdentity): presetKelas/Halaqoh
      // sudah pasti benar dan tidak boleh ditimpa.
      if (!widget.lockIdentity) {
        final scope = _scope;
        if (scope != null && scope.user.assignments.length == 1) {
          final only = scope.user.assignments.first;
          _kelas = only.kelas;
          _halaqoh = only.halaqoh;
        }
      }

      // Cek draf laporan yang belum sempat disimpan (mis. sheet tertutup tak sengaja): kalau ada dan
      // tidak kosong, tawarkan lewat banner (jangan langsung menimpa pre-fill). Dilewati saat identitas
      // dikunci karena draf lama bisa milik santri LAIN dan bertentangan dengan kartu yang dibuka.
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
    _nilaiCtrl.dispose();
    super.dispose();
  }

  // --- Opsi kelas/halaqoh/nama santri ---

  bool get _hasOwnAssignments => (_scope?.user.assignments ?? const []).isNotEmpty;

  /// `scope.isAdmin` sudah memperhitungkan toggle GLOBAL "Mode Admin" (AccessScope.adminModeActive):
  /// saat aktif form tidak dibatasi; guru pembimbing biasa dan admin yang Mode Admin-nya nonaktif
  /// selalu dibatasi ke assignment sendiri.
  bool get _restrictToOwn {
    final scope = _scope;
    if (scope == null) return false;
    if (!_hasOwnAssignments) return false;
    return !scope.isAdmin;
  }

  RecordFormOptions _options() => RecordFormOptions(
        scope: _scope,
        restrictToOwn: _restrictToOwn,
        dataset: context.read<RecordsProvider>(),
        students: context.read<StudentsProvider>(),
      );

  List<String> _kelasOptions() => _options().kelas();
  List<String> _halaqohOptions() => _options().halaqoh(_kelas);
  List<String> _namaOptions() => _options().nama(_kelas, _halaqoh);

  // --- Handler perubahan pilihan ---

  void _onKelasChanged(String? v) {
    setState(() {
      _kelas = v;
      _kelasError = null;
    });
    // Kelas ganti -> halaqoh terpilih mungkin tak valid lagi (mode dibatasi assignment) -> reset;
    // nama santri ikut di-resync karena bergantung kombinasi kelas+halaqoh.
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

  /// Bila kelas+halaqoh terpilih BUKAN assignment user yang login (hanya bisa terjadi pada admin),
  /// beri tahu lewat snackbar LOKAL di dalam sheet ini (bukan snackbar halaman di belakangnya
  /// yang tertutup sheet).
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
                ? 'Anda mengisi sebagai Admin. Ini bukan kelas/halaqoh Anda.'
                : 'Ini bukan kelas/halaqoh Anda.',
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
        'nilai': _nilaiCtrl.text,
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
            return TahfizhSegState()
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
            return TilawahSegState()
              ..surahNumber = m['surahNumber'] as int?
              ..ayatMulaiCtrl.text = (m['ayatMulai'] as String?) ?? ''
              ..ayatSelesaiCtrl.text = (m['ayatSelesai'] as String?) ?? '';
          }).toList();
        }
        _catatanCtrl.text = (d['catatan'] as String?) ?? '';
        _nilaiCtrl.text = (d['nilai'] as String?) ?? '';
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
    setState(() => _tahfizhSegs.add(TahfizhSegState()));
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
    setState(() => _tilawahSegs.add(TilawahSegState()));
    _markEditedAndScheduleDraftSave();
  }

  void _removeTilawahSegment(int index) {
    setState(() {
      _tilawahSegs[index].dispose();
      _tilawahSegs.removeAt(index);
    });
    _markEditedAndScheduleDraftSave();
  }

  /// Generate baris untuk SEMUA segmen Tahfizh (bisa >1 surah): tiap segmen digenerate sendiri lewat
  /// [QuranEngineService.generateLines] (1 surah per panggilan) lalu digabung; baris dari segmen
  /// sebelumnya ikut di-exclude di segmen berikutnya (jaga-jaga overlap di batas transisi surah).
  Future<void> _generateAllLines({bool silent = false}) async {
    if (_nama == null || _nama!.trim().isEmpty) {
      if (!silent) {
        setState(() => _generateError =
            'Pilih nama siswa dulu.');
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
            'Data baris belum tersedia untuk salah satu surah (${QuranEngineService.instance.missingText()}).';
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

    // Kalau ditandai "Hadir tanpa capaian hari ini", catatan WAJIB diisi — itu satu-satunya
    // penjelasan kenapa tak ada capaian padahal Hadir (lihat toggle _tanpaCapaian).
    if (_tanpaCapaian && _catatanCtrl.text.trim().isEmpty) {
      _localMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Isi catatan dulu: wajib jika tidak ada capaian hari ini.'),
        ),
      );
      return;
    }

    final isiStatusCapaian = _wajibIsiStatusCapaian;

    final needsTahfizhPart =
        _status == HafalanStatus.tahfizh || _status == HafalanStatus.tahsinTahfizh;

    if (isiStatusCapaian && needsTahfizhPart) {
      // Segmen siap kalau (a) generate sukses dari dataset, ATAU (b) dataset belum meng-cover surah itu
      // (mis. Juz 11-25) tapi user sudah mengisi jumlah baris manual (lihat `manualBarisCtrl`).
      final allReady = _tahfizhSegs.every((s) => s.isReady);
      if (!allReady) {
        final anyUnavailable = _tahfizhSegs.any((s) => s.datasetUnavailable);
        _localMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text(anyUnavailable
                  ? 'Isi jumlah baris manual untuk surah yang datanya belum ada.'
                  : 'Tekan Generate Baris dulu sebelum menyimpan.')),
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

    // Daftar segmen Tahfizh dari state form (bisa >1 surah). totalBaris/lineIds tetap AGREGAT semua
    // segmen agar konsumen lama (statistik/rekap) tetap benar; field singular (surahNumber, dst)
    // diisi dari segmen PERTAMA untuk backward compat.
    final tahfizhSegments =
        isTahfizhPart ? _tahfizhSegs.map((s) => s.toSegment()).toList() : null;
    final tilawahSegments = isTilawahShaped
        ? _tilawahSegs.where((s) => s.isFilled).map((s) => s.toSegment()).toList()
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
      nilai: _nilaiCtrl.text.trim().isEmpty ? null : _nilaiCtrl.text.trim(),
      folderId: widget.existing?.folderId ?? widget.initialFolderId,
      // Dicatat untuk audit "siapa yang input laporan ini" (terutama admin di luar kelas/halaqoh-nya,
      // lihat _maybeWarnOwnership). Laporan lama yang diedit tetap memakai ownerId aslinya agar jejak
      // pembuat PERTAMA tidak tertimpa.
      ownerId: widget.existing?.ownerId ?? _scope?.user.id,
    );

    // context dipakai lagi setelah await -> WAJIB cek `mounted` tiap kali agar lint "don't use
    // BuildContext across async gaps" bersih (pola .then()/.catchError() tak terbaca aman analyzer).
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
    // context.watch di sini membuat build() rebuild tiap RecordsProvider/StudentsProvider berubah;
    // helper _kelasOptions dkk boleh memakai context.read karena elemen ini sudah "berlangganan".
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
        // WAJIB false: tinggi sheet dan padding bawah ListView sudah dihitung manual dengan
        // mq.viewInsets.bottom; kalau default (true), tinggi keyboard terhitung 2x sehingga muncul
        // celah kosong raksasa di bawah tombol Simpan saat keyboard muncul & di-scroll.
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          // Pendekatan manual (bukan DraggableScrollableSheet, yang menghitung tinggi relatif safe area
          // dan bisa menyisakan celah di bawah): tinggi sheet dihitung dari `constraints` Scaffold ini
          // (= tinggi layar penuh berkat useRootNavigator:true), jadi presisi menempel ke y=0 sampai bawah.
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
                  RecordFormHeader(
                    isEdit: _isEdit,
                    nama: _nama,
                    kelas: _kelas,
                    halaqoh: _halaqoh,
                    onDelete: () => _confirmDelete(context),
                  ),
                  Expanded(
                    // Padding bawah di SINI (bukan di padding konten ListView) sengaja mengecilkan viewport saat
                    // keyboard muncul agar field terfokus ter-scroll ke atas keyboard (Scrollable.ensureVisible).
                    // Tak bentrok dengan resizeToAvoidBottomInset=false: hanya satu tempat ini yang mengurangi viewInsets.
                    child: Padding(
                      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          children: [
                            if (_draftBannerVisible) ...[
                              RecordDraftBanner(onDiscard: _discardDraft, onRestore: _restoreDraft),
                              const SizedBox(height: 16),
                          ],
                          FormSectionCard(
                            title: 'Tanggal',
                            icon: LucideIcons.calendarDays,
                            child: _buildDateField(cs),
                          ),
                          // Identitas santri (Kelas/Halaqoh/Nama) SENGAJA disembunyikan total saat dibuka dari kartu santri
                          // (lockIdentity): identitasnya sudah jelas dari kartu, form cukup tanggal + status capaian +
                          // keterangan + catatan.
                          if (!widget.lockIdentity) ...[
                            const SizedBox(height: 16),
                            FormSectionCard(
                              title: 'Identitas Siswa',
                              icon: LucideIcons.medal,
                              child: RecordIdentityFields(
                                kelas: _kelas,
                                halaqoh: _halaqoh,
                                nama: _nama,
                                kelasOptions: kelasOptions,
                                halaqohOptions: halaqohOptions,
                                namaOptions: namaOptions,
                                kelasError: _kelasError,
                                halaqohError: _halaqohError,
                                namaError: _namaError,
                                comboBelumLengkap: comboBelumLengkap,
                                lockIdentity: widget.lockIdentity,
                                onKelasChanged: _onKelasChanged,
                                onHalaqohChanged: _onHalaqohChanged,
                                onNamaChanged: _onNamaChanged,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FormSectionCard(
                            title: 'Status Capaian',
                            icon: LucideIcons.trendingUp,
                            child: Column(
                              children: [
                                RecordStatusSelector(
                                  selected: _status,
                                  onChanged: (s) {
                                    setState(() {
                                      _status = s;
                                      _generateError = null;
                                    });
                                    _markEditedAndScheduleDraftSave();
                                  },
                                ),
                                if (!_wajibIsiStatusCapaian)
                                  RecordOptionalStatusNotice(
                                    tanpaCapaian: _tanpaCapaian,
                                    keteranganLabel: _keterangan.label,
                                  ),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: switch (_status) {
                                    HafalanStatus.tahfizh => _tahfizhFields(),
                                    HafalanStatus.tahsin => _buildTahsinFields(),
                                    HafalanStatus.tahsinTahfizh =>
                                      _buildTahsinTahfizhFields(cs),
                                    HafalanStatus.murojaahTasmi => _buildMurojaahFields(),
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          FormSectionCard(
                            title: 'Nilai',
                            icon: LucideIcons.hash,
                            child: TextFormField(
                              controller: _nilaiCtrl,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              decoration: fieldDecoration(
                                context,
                                icon: LucideIcons.hash,
                                label: 'Nilai',
                                hint: 'ketik nilai',
                                accent: cs.primary,
                              ),
                              onChanged: (_) => _markEditedAndScheduleDraftSave(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FormSectionCard(
                            title: 'Keterangan',
                            icon: LucideIcons.clipboardCheck,
                            child: KeteranganSelector(
                              selected: _keterangan,
                              tanpaCapaian: _tanpaCapaian,
                              onSelected: (k) {
                                setState(() {
                                  _keterangan = k;
                                  // Toggle "tanpa capaian" hanya relevan untuk Hadir; reset
                                  // saat keterangan dipindah agar nilainya tidak nyangkut.
                                  if (k != Keterangan.hadir) _tanpaCapaian = false;
                                });
                                _markEditedAndScheduleDraftSave();
                              },
                              onTanpaCapaianChanged: (v) {
                                setState(() => _tanpaCapaian = v);
                                _markEditedAndScheduleDraftSave();
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          FormSectionCard(
                            title: _tanpaCapaian ? 'Catatan (Wajib)' : 'Catatan (Opsional)',
                            icon: LucideIcons.penLine,
                            child: TextFormField(
                              controller: _catatanCtrl,
                              maxLines: 3,
                              decoration: fieldDecoration(
                                context,
                                icon: LucideIcons.fileText,
                                label: _tanpaCapaian ? 'Catatan (wajib diisi)' : 'Catatan',
                                hint: _tanpaCapaian
                                    ? 'Alasan tidak ada capaian hari ini...'
                                    : 'Catatan tambahan untuk guru atau orang tua...',
                                accent: cs.primary,
                              ),
                              onChanged: (_) => _markEditedAndScheduleDraftSave(),
                            ),
                          ),
                          const SizedBox(height: 28),
                          RecordSubmitButton(isEdit: _isEdit, onPressed: _submit),
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

  Widget _buildDateField(ColorScheme cs) {
    // Skin senada dengan kolom lain (fieldDecoration: ikon dalam kotak
    // warna, rounded-16, filled) — nggak beda desain lagi dari kolom teks.
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: fieldDecoration(
          context,
          icon: LucideIcons.calendarDays,
          label: 'Tanggal Laporan',
          accent: cs.primary,
        ).copyWith(
          suffixIcon:
              Icon(LucideIcons.chevronDown, color: cs.onSurfaceVariant),
        ),
        child: Text(
          DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_tanggal),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }

  // --- Adapter ke widget bagian form (widgets/record/): state tetap di sini, widgetnya
  // hanya menerima nilai + callback.

  Widget _tahfizhFields() => TahfizhFields(
        key: const ValueKey('tahfizh'),
        segs: _tahfizhSegs,
        generating: _generating,
        generateError: _generateError,
        requireInput: () => _wajibIsiStatusCapaian,
        onAddSegment: _addTahfizhSegment,
        onRemoveSegment: _removeTahfizhSegment,
        onSurahChanged: (seg, v) {
          setState(() {
            seg.surahNumber = v;
            seg.generated = null;
            _generateError = null;
          });
          _markEditedAndScheduleDraftSave();
        },
        onAyatChanged: (seg) {
          setState(() => seg.generated = null);
          _markEditedAndScheduleDraftSave();
        },
        onManualBarisChanged: _markEditedAndScheduleDraftSave,
        onGenerate: () => _generateAllLines(),
        missingText: () => QuranEngineService.instance.missingText(),
      );

  Widget _tilawahFields({Key? key}) => TilawahFields(
        key: key,
        segs: _tilawahSegs,
        requireInput: () => _wajibIsiStatusCapaian,
        onAddSegment: _addTilawahSegment,
        onRemoveSegment: _removeTilawahSegment,
        onSurahChanged: (seg, v) {
          setState(() => seg.surahNumber = v);
          _markEditedAndScheduleDraftSave();
        },
        onChanged: _markEditedAndScheduleDraftSave,
      );

  Widget _tahsinModeToggle() => TahsinModeToggle(
        mode: _tahsinMode,
        onChanged: (m) {
          setState(() => _tahsinMode = m);
          _markEditedAndScheduleDraftSave();
        },
      );

  Widget _wafaFields({Key? key}) => WafaFields(
        key: key,
        level: _wafaLevel,
        halamanCtrl: _halamanWafaCtrl,
        requireInput: () => _wajibIsiStatusCapaian,
        onLevelChanged: (v) {
          setState(() => _wafaLevel = v);
          _markEditedAndScheduleDraftSave();
        },
        onHalamanChanged: _markEditedAndScheduleDraftSave,
      );

  Widget _buildTahsinFields() {
    return Column(
      key: const ValueKey('tahsin'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tahsinModeToggle(),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _tahsinMode == TahsinMode.wafa
              ? _wafaFields(key: const ValueKey('wafa'))
              : _tilawahFields(key: const ValueKey('tilawah_in_tahsin')),
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
        _tahsinModeToggle(),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _tahsinMode == TahsinMode.wafa
              ? _wafaFields(key: const ValueKey('wafa_in_combo'))
              : _tilawahFields(key: const ValueKey('tilawah_in_combo')),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _buildPartLabel(
            'Bagian Tahfizh (Hafalan Baru)', cs.primary, HafalanStatus.tahfizh.icon),
        const SizedBox(height: 10),
        _tahfizhFields(),
      ],
    );
  }

  /// Muroja'ah/Tasmi' selalu berbentuk seperti Tilawah — surah + rentang
  /// ayat, tanpa generate baris.
  Widget _buildMurojaahFields() {
    return _tilawahFields(key: const ValueKey('murojaah'));
  }

}
