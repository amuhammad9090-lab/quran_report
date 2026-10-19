part of 'record_form_sheet.dart';

/// Field state + opsi kelas/halaqoh/nama + handler pilihan untuk [_RecordFormSheetState].
/// Dipisah ke file sendiri supaya file sheet tidak membengkak; perilakunya tidak berubah.
mixin _RecordFormFields on State<RecordFormSheet> {
  /// Diimplementasi di [_RecordFormLogic]: tandai form berubah + jadwalkan simpan draf.
  void _markEditedAndScheduleDraftSave();

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

  // Nilai (ketik bebas). Ketuntasan diputuskan guru lewat tombol di Generate Laporan Pekanan.
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
}
