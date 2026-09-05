import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/access/access_scope.dart';
import '../../../providers/records_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Tahap 1 alur "Buat Laporan" (lihat spesifikasi perubahan Laporan &
/// Statistik, bagian 1): form IDENTITAS SAJA (Kelas → Halaqoh → Nama
/// Santri) — SENGAJA tidak menanyakan capaian/tahfizh/tahsin/dst di sini.
/// Begitu identitas disimpan, 1 kartu santri langsung muncul di tab
/// Laporan (lihat [RecordsProvider.laporanCards]); capaian pekanan diisi
/// belakangan lewat kartu itu (tap kartu -> Bottom Sheet "Laporan Baru"
/// yang sudah ada, tidak dibuat ulang).
Future<void> showBuatLaporanSheet(
  BuildContext context, {
  String? folderId,
  ValueChanged<bool>? onFabVisibilityChanged,
}) {
  return showModalBottomSheet(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BuatLaporanSheet(
      folderId: folderId,
      onFabVisibilityChanged: onFabVisibilityChanged,
    ),
  );
}

class BuatLaporanSheet extends StatefulWidget {
  /// Diisi kalau sheet ini dibuka dari dalam [FolderDetailScreen] — kartu
  /// santri yang baru dibuat langsung "diparkir" ke folder ini (lihat
  /// [RecordsProvider.activateIdentity]), jadi user nggak perlu pindahkan
  /// manual lagi sesudahnya.
  final String? folderId;
  /// Diteruskan ke [showAppSnackbar] supaya FAB di layar belakang ikut
  /// disembunyikan selama snackbar "kartu dibuat/sudah ada/gagal" tampil
  /// (sheet ini sendiri nggak punya FAB, tapi Scaffold di baliknya punya).
  final ValueChanged<bool>? onFabVisibilityChanged;
  const BuatLaporanSheet({super.key, this.folderId, this.onFabVisibilityChanged});

  @override
  State<BuatLaporanSheet> createState() => _BuatLaporanSheetState();
}

class _BuatLaporanSheetState extends State<BuatLaporanSheet> {
  String? _kelas;
  String? _halaqoh;
  String? _nama;
  String? _kelasError;
  String? _halaqohError;
  String? _namaError;
  bool _saving = false;

  // <-- BERUBAH: dulu toggle LOKAL "_adminBrowseAll" di sheet ini. Sekarang
  // pakai toggle GLOBAL "Mode Admin" di Profil (lihat
  // AccessScope.adminModeActive & AuthProvider.setAdminModeActive) — lihat
  // catatan lengkap di RecordFormSheet._restrictToOwn (pola sama persis).

  AccessScope? get _scope => context.read<RecordsProvider>().scope;
  bool get _hasOwnAssignments => (_scope?.user.assignments ?? const []).isNotEmpty;

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

  void _onKelasChanged(String? v) {
    setState(() {
      _kelas = v;
      _kelasError = null;
    });
    final validHalaqoh = _halaqohOptions();
    if (_halaqoh != null && !validHalaqoh.contains(_halaqoh)) {
      setState(() => _halaqoh = null);
    }
    _resyncNamaIfInvalid();
  }

  void _onHalaqohChanged(String? v) {
    setState(() {
      _halaqoh = v;
      _halaqohError = null;
    });
    _resyncNamaIfInvalid();
  }

  void _onNamaChanged(String? v) {
    setState(() {
      _nama = v;
      _namaError = null;
    });
  }

  void _resyncNamaIfInvalid() {
    final validNama = _namaOptions();
    if (_nama != null && !validNama.contains(_nama)) {
      setState(() => _nama = null);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _kelasError = (_kelas == null || _kelas!.trim().isEmpty) ? 'Wajib dipilih' : null;
      _halaqohError = (_halaqoh == null || _halaqoh!.trim().isEmpty) ? 'Wajib dipilih' : null;
      _namaError = (_nama == null || _nama!.trim().isEmpty) ? 'Wajib dipilih' : null;
    });
    if (_kelasError != null || _halaqohError != null || _namaError != null) return;

    final provider = context.read<RecordsProvider>();

    // Kalau kartu untuk santri ini sudah ada (baik dari laporan asli
    // maupun dari identitas yang sebelumnya sudah diaktifkan), jangan
    // bikin duplikat — cukup tutup sheet ini, kartunya sudah ada di tab
    // Laporan.
    final key = reportIdentityKey(_kelas!, _halaqoh!, _nama!);
    final alreadyExists = provider.laporanCards.any((c) => c.identityKey == key);
    if (alreadyExists) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        'Kartu laporan "$_nama" sudah ada.',
        icon: Icons.info_outline_rounded,
        onFabVisibilityChanged: widget.onFabVisibilityChanged,
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    try {
      await provider.activateIdentity(
        kelas: _kelas!.trim(),
        halaqoh: _halaqoh!.trim(),
        nama: _nama!.trim(),
        folderId: widget.folderId,
      );
      if (!mounted) return;
      showAppSnackbar(
        context,
        'Kartu laporan "$_nama" dibuat.',
        icon: Icons.check_circle_outline_rounded,
        onFabVisibilityChanged: widget.onFabVisibilityChanged,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackbar(
        context,
        e is ScopeViolationException ? e.message : 'Gagal membuat kartu laporan.',
        icon: Icons.error_outline_rounded,
        onFabVisibilityChanged: widget.onFabVisibilityChanged,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    context.watch<RecordsProvider>();
    context.watch<StudentsProvider>();

    final kelasOptions = _kelasOptions();
    final halaqohOptions = _halaqohOptions();
    final namaOptions = _namaOptions();
    final comboBelumLengkap =
        _kelas == null || _kelas!.trim().isEmpty || _halaqoh == null || _halaqoh!.trim().isEmpty;

    return SafeArea(
      child: Material(
        // Sebelumnya: Container(decoration: BoxDecoration(color:...,
        // borderRadius:...)). Diganti ke Material supaya widget ini
        // SENDIRI jadi ancestor Material terdekat buat SwitchListTile di
        // bawah (Material mendukung `color` + `borderRadius` langsung,
        // hasil render identik dengan Container+BoxDecoration sebelumnya,
        // cuma sekarang background & ink splash SwitchListTile ikut
        // kepotong rounded corner dengan benar, tidak ketiban DecoratedBox
        // lagi). Lihat: assertion "ListTile background color or ink
        // splashes may be invisible".
        color: Theme.of(context).bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
            Text('Buat Laporan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Pilih identitas santri dulu — capaian pekanan diisi belakangan lewat kartunya.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SelectField(
                    key: ValueKey('bl_kelas_$_kelas'),
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
                    key: ValueKey('bl_halaqoh_$_halaqoh'),
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
              key: ValueKey('bl_nama_$_nama'),
              value: _nama,
              label: 'Nama Santri',
              hint: comboBelumLengkap ? 'Pilih kelas & halaqoh dulu' : null,
              icon: Icons.person_outline_rounded,
              options: namaOptions,
              errorText: _namaError,
              accent: cs.primary,
              onChanged: _onNamaChanged,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: const Text('Simpan'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
