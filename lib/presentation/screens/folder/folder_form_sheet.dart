import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/access/access_scope.dart';
import '../../../data/models/folder.dart';
import '../../../providers/folders_provider.dart';
import '../../../providers/records_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Bottom sheet buat folder baru, atau rename folder yang sudah ada kalau
/// [existing] diisi. Muncul dengan animasi nyembul-dari-bawah bawaan
/// [showModalBottomSheet].
Future<void> showFolderFormSheet(BuildContext context, {ReportFolder? existing}) {
  return showModalBottomSheet(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FolderFormSheet(existing: existing),
  );
}

class FolderFormSheet extends StatefulWidget {
  final ReportFolder? existing;
  const FolderFormSheet({super.key, this.existing});

  @override
  State<FolderFormSheet> createState() => _FolderFormSheetState();
}

class _FolderFormSheetState extends State<FolderFormSheet> {
  // Nama folder SEKARANG selalu disusun dari Kelas + Halaqoh yang dipilih
  // lewat dropdown (nggak ada lagi kolom ketik bebas) — biar penamaan
  // folder konsisten & selalu nyambung ke data kelas/halaqoh yang beneran
  // ada, bukan teks sembarangan.
  String? _kelas;
  String? _halaqoh;
  String? _kelasError;
  String? _halaqohError;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existingNama = widget.existing?.nama;
    if (existingNama != null) {
      // Folder lama (sebelum perubahan ini) namanya masih teks bebas —
      // coba tebak Kelas/Halaqoh-nya dari pola "Kelas X - Halaqoh Y" yang
      // memang jadi format baku sejak awal fitur folder ini ada. Kalau
      // nggak cocok pola (folder lama dengan nama lain), biarkan dropdown
      // kosong — user tinggal pilih ulang.
      final match = RegExp(r'^Kelas\s+(.+?)\s+-\s+Halaqoh\s+(.+)$').firstMatch(existingNama.trim());
      if (match != null) {
        _kelas = match.group(1);
        _halaqoh = match.group(2);
      }
    }
  }

  AccessScope? get _scope => context.read<RecordsProvider>().scope;

  bool get _hasOwnAssignments => (_scope?.user.assignments ?? const []).isNotEmpty;

  /// <-- BERUBAH: dulu admin yang JUGA punya assignment sendiri SELALU
  /// dibatasi ke kelas/halaqoh sendiri di sini (gak pernah bisa bikin
  /// folder buat kelas lain walau admin) — beda sendiri dari form
  /// laporan yang sudah punya jalan keluarnya. Sekarang disamain: kalau
  /// toggle GLOBAL "Mode Admin" di Profil aktif (`scope.isAdmin`, lihat
  /// AccessScope.adminModeActive), admin dengan assignment sendiri pun
  /// bisa bikin folder untuk kelas manapun, sama seperti admin murni.
  /// Guru pembimbing biasa (bukan admin) & admin yang Mode Admin-nya
  /// nonaktif tetap dibatasi ke assignment sendiri.
  bool get _restrictToOwn {
    final scope = _scope;
    if (scope == null) return false;
    if (!_hasOwnAssignments) return false;
    return !scope.isAdmin;
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

  List<String> _halaqohOptions() {
    final scope = _scope;
    final dataset = context.read<RecordsProvider>();
    final accessibleStudents = context.read<StudentsProvider>().accessibleFor(scope);
    if (_restrictToOwn) {
      final validForKelas = scope!.user.assignments
          .where((a) => a.kelas == _kelas)
          .map((a) => a.halaqoh)
          .toList();
      return validForKelas.isNotEmpty
          ? validForKelas
          : (scope.user.assignments.map((a) => a.halaqoh).toSet().toList()..sort());
    }
    return ({...dataset.distinctHalaqoh, ...accessibleStudents.map((s) => s.halaqoh)}.toList()..sort());
  }

  void _onKelasChanged(String? v) {
    setState(() {
      _kelas = v;
      _kelasError = null;
    });
    // Kelas ganti -> halaqoh yang lagi kepilih mungkin udah nggak valid
    // buat kelas baru ini (khusus mode dibatasi assignment sendiri) ->
    // reset biar nggak nyangkut pasangan yang salah.
    final validHalaqoh = _halaqohOptions();
    if (_halaqoh != null && !validHalaqoh.contains(_halaqoh)) {
      setState(() => _halaqoh = null);
    }
  }

  void _onHalaqohChanged(String? v) {
    setState(() {
      _halaqoh = v;
      _halaqohError = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _kelasError = (_kelas == null || _kelas!.trim().isEmpty) ? 'Wajib dipilih' : null;
      _halaqohError = (_halaqoh == null || _halaqoh!.trim().isEmpty) ? 'Wajib dipilih' : null;
    });
    if (_kelasError != null || _halaqohError != null) return;

    final nama = 'Kelas ${_kelas!.trim()} - Halaqoh ${_halaqoh!.trim()}';
    setState(() => _saving = true);
    final provider = context.read<FoldersProvider>();
    if (_isEdit) {
      await provider.rename(widget.existing!.id, nama);
    } else {
      await provider.create(nama);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // context.watch di sini biar build() ini rebuild otomatis tiap
    // RecordsProvider/StudentsProvider notifyListeners — _kelasOptions()
    // dkk di atas boleh pakai context.read internal karena widget ini
    // sudah "berlangganan" lewat watch di bawah.
    context.watch<RecordsProvider>();
    context.watch<StudentsProvider>();

    final kelasOptions = _kelasOptions();
    final halaqohOptions = _halaqohOptions();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).bottomSheetTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  SoftIconBox(icon: Icons.folder_rounded, color: cs.secondary),
                  const SizedBox(width: 12),
                  Text(
                    _isEdit ? 'Ubah Folder' : 'Buat Folder Baru',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 18),
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
                      accent: cs.secondary,
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
                      accent: cs.secondary,
                      onChanged: _onHalaqohChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(_isEdit ? 'Simpan' : 'Buat Folder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
