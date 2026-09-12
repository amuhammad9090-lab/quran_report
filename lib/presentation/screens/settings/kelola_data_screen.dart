import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/models/student.dart';
import '../../../data/models/user_account.dart';
import '../../../data/repositories/api_auth_repository.dart';
import '../../../data/repositories/api_student_repository.dart';
import '../../../data/services/platform_file/file_actions.dart';
import '../../../data/services/school_data_excel_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'kelola_guru_screen.dart';
import 'kelola_murid_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// "Halaman Kelola" -- pusat Mode Admin buat data guru & murid: pindah ke
/// Kelola Guru/Kelola Murid (edit satuan), export/import Excel (edit
/// massal, satu file dua sheet: Murid & Guru), export kode seed (.dart),
/// dan migrasi data bawaan APK ke cloud.
class KelolaDataScreen extends StatefulWidget {
  const KelolaDataScreen({super.key});

  @override
  State<KelolaDataScreen> createState() => _KelolaDataScreenState();
}

class _KelolaDataScreenState extends State<KelolaDataScreen> {
  bool _busy = false;

  Future<void> _withBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Tarik data guru & murid TER-ANYAR dari Firestore dulu -- dipakai
  /// sebelum export/import biar gak ketinggalan zaman (sama alasannya
  /// kayak KelolaMuridScreen/KelolaGuruScreen).
  Future<(List<Student>, List<UserAccount>)> _refreshedData() async {
    final students = await ApiStudentRepository.instance.refresh();
    final accounts = await ApiAuthRepository.instance.refresh();
    if (!mounted) return (students, accounts);
    await context.read<StudentsProvider>().load();
    if (!mounted) return (students, accounts);
    await context.read<AuthProvider>().reloadAccounts();
    return (students, accounts);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Halaman Kelola')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _SectionCard(
                  title: 'Kelola Data',
                  children: [
                    ListTile(
                      leading: SoftIconBox(icon: LucideIcons.medal, color: cs.primary),
                      title: const Text('Kelola Guru'),
                      subtitle: const Text('Ubah nama & assignment kelas/halaqoh guru pembimbing'),
                      trailing: const Icon(LucideIcons.chevronRight),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const KelolaGuruScreen()),
                      ),
                    ),
                    ListTile(
                      leading: SoftIconBox(icon: LucideIcons.users, color: cs.primary),
                      title: const Text('Kelola Murid'),
                      subtitle: const Text('Pindah kelas/halaqoh (mis. naik Tahsin → Tahfizh)'),
                      trailing: const Icon(LucideIcons.chevronRight),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const KelolaMuridScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Export & Import',
                  children: [
                    ListTile(
                      leading: SoftIconBox(icon: LucideIcons.fileDown, color: cs.primary),
                      title: const Text('Export ke Excel'),
                      subtitle: const Text('Satu file .xlsx, sheet "Murid" & "Guru"'),
                      onTap: () => _withBusy(() => _exportExcel(context)),
                    ),
                    ListTile(
                      leading: SoftIconBox(icon: LucideIcons.cloudUpload, color: cs.primary),
                      title: const Text('Import dari Excel'),
                      subtitle: const Text('Upload balik file yang sudah diedit, ada preview dulu'),
                      onTap: () => _withBusy(() => _importExcel(context)),
                    ),
                    ListTile(
                      leading: SoftIconBox(icon: LucideIcons.code, color: cs.primary),
                      title: const Text('Export sebagai kode seed (.dart)'),
                      subtitle: const Text('Buat developer, sebelum build APK berikutnya'),
                      onTap: () => _withBusy(() => _exportSeedCode(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Migrasi',
                  children: [
                    ListTile(
                      leading: SoftIconBox(icon: LucideIcons.cloud, color: cs.primary),
                      title: const Text('Migrasi Data Guru & Murid ke Cloud'),
                      subtitle: const Text(
                        'Sekali jalan — pindahin data bawaan APK ke cloud, aman dipencet berkali-kali',
                      ),
                      onTap: () => _confirmMigrateSeed(context),
                    ),
                  ],
                ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.transparent,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    final (students, accounts) = await _refreshedData();
    if (!context.mounted) return;
    if (students.isEmpty && accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data guru/murid buat di-export.')),
      );
      return;
    }
    try {
      final file = await SchoolDataExcelService.instance.saveWorkbook(students, accounts);
      if (!context.mounted) return;
      await shareExportedFile(
        file,
        subject: 'Data Guru & Murid — edit sheet "Murid"/"Guru", lalu upload balik lewat "Import dari Excel"',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
    }
  }

  Future<void> _exportSeedCode(BuildContext context) async {
    final (students, accounts) = await _refreshedData();
    if (!context.mounted) return;
    if (students.isEmpty && accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data guru/murid buat di-export.')),
      );
      return;
    }
    final code = SchoolDataExcelService.instance.buildSeedDartCode(students, accounts);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _SeedCodeScreen(code: code)),
    );
  }

  Future<void> _importExcel(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return; // dibatalin user

    final (students, accounts) = await _refreshedData();
    if (!context.mounted) return;

    late final SchoolDataImportResult parsed;
    try {
      parsed = SchoolDataExcelService.instance.parseImport(
        bytes,
        currentStudents: students,
        currentAccounts: accounts,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File gak kebaca -- pastikan formatnya .xlsx hasil export dari sini. ($e)')),
      );
      return;
    }

    if (!context.mounted) return;

    if (!parsed.hasAnyChange) {
      final unknownTotal = parsed.students.unknownIds.length + parsed.accounts.unknownIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unknownTotal == 0
                ? 'Gak ada perubahan yang terdeteksi di file ini.'
                : 'Gak ada perubahan valid. $unknownTotal baris id-nya gak dikenali.',
          ),
        ),
      );
      return;
    }

    final applied = await Navigator.of(context).push<_ImportSelection>(
      MaterialPageRoute(builder: (_) => _ImportPreviewScreen(result: parsed)),
    );
    if (applied == null || !context.mounted) return;
    if (applied.students.isEmpty && applied.accounts.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyimpan perubahan...'), duration: Duration(seconds: 30)),
    );

    try {
      final writtenStudents = applied.students.isEmpty
          ? 0
          : await ApiStudentRepository.instance.bulkUpdateKelasHalaqoh(applied.students);
      final writtenAccounts = applied.accounts.isEmpty
          ? 0
          : await ApiAuthRepository.instance.bulkUpdateAssignments(applied.accounts);

      if (!context.mounted) return;
      await context.read<StudentsProvider>().load();
      if (!context.mounted) return;
      await context.read<AuthProvider>().reloadAccounts();
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Berhasil! $writtenStudents murid & $writtenAccounts guru diperbarui.'),
        ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  // Migrasi Data Guru & Murid ke Cloud.
  void _confirmMigrateSeed(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Migrasi data ke Cloud?'),
        content: const Text(
          'Data guru & murid bawaan APK akan disalin ke cloud, TAPI id yang sudah ada di cloud '
          'akan dilewatin (tidak ditimpa) -- jadi perubahan yang sudah kamu buat lewat Kelola Guru/'
          'Murid atau Import Excel tetap aman. Aman dijalankan berkali-kali. Butuh koneksi internet.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _migrateSeed(context);
            },
            child: const Text('Migrasi'),
          ),
        ],
      ),
    );
  }

  Future<void> _migrateSeed(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final students = await ApiStudentRepository.instance.migrateSeedToFirestore();
      final accounts = await ApiAuthRepository.instance.migrateSeedToFirestore();

      if (!context.mounted) return;
      await context.read<StudentsProvider>().load();
      if (!context.mounted) return;
      await context.read<AuthProvider>().reloadAccounts();
      if (!context.mounted) return;

      Navigator.of(context).pop(); // tutup dialog loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil! $students murid & $accounts akun guru tersalin ke cloud.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal migrasi: $e')),
      );
    }
  }
}

/// Hasil pilihan admin di [_ImportPreviewScreen] -- baris mana yang jadi
/// beneran diterapkan (student & account bisa jalan independen, admin
/// boleh cuma terapkan salah satu sheet doang).
class _ImportSelection {
  final List<Student> students;
  final List<UserAccount> accounts;
  const _ImportSelection({required this.students, required this.accounts});
}

/// Preview perubahan hasil parsing file Excel (sheet Murid & Guru)
/// SEBELUM ditulis ke Firestore -- admin bisa uncheck baris tertentu per
/// sheet, atau batal semua kalau salah file.
class _ImportPreviewScreen extends StatefulWidget {
  final SchoolDataImportResult result;
  const _ImportPreviewScreen({required this.result});

  @override
  State<_ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<_ImportPreviewScreen> {
  late final Set<String> _excludedStudents = {};
  late final Set<String> _excludedAccounts = {};

  @override
  Widget build(BuildContext context) {
    final studentChanges = widget.result.students.changedRows;
    final accountChanges = widget.result.accounts.changedRows;
    final includedCount = (studentChanges.length - _excludedStudents.length) +
        (accountChanges.length - _excludedAccounts.length);

    return Scaffold(
      appBar: AppBar(title: Text('Preview ($includedCount perubahan)')),
      body: Column(
        children: [
          if (widget.result.students.unknownIds.isNotEmpty || widget.result.accounts.unknownIds.isNotEmpty)
            _UnknownIdsBanner(
              studentUnknownIds: widget.result.students.unknownIds,
              accountUnknownIds: widget.result.accounts.unknownIds,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (accountChanges.isNotEmpty) ...[
                  const _PreviewSectionLabel('Guru'),
                  for (final row in accountChanges)
                    CheckboxListTile(
                      value: !_excludedAccounts.contains(row.current.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _excludedAccounts.remove(row.current.id);
                        } else {
                          _excludedAccounts.add(row.current.id);
                        }
                      }),
                      title: Text(row.current.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${row.current.displayName} (${row.current.assignments.length} assignment)  →  '
                        '${row.newDisplayName} (${row.newAssignments.length} assignment)',
                      ),
                    ),
                ],
                if (studentChanges.isNotEmpty) ...[
                  const _PreviewSectionLabel('Murid'),
                  for (final row in studentChanges)
                    CheckboxListTile(
                      value: !_excludedStudents.contains(row.current.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _excludedStudents.remove(row.current.id);
                        } else {
                          _excludedStudents.add(row.current.id);
                        }
                      }),
                      title: Text(row.current.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${row.current.kelas} • ${row.current.halaqoh}  →  ${row.newKelas} • ${row.newHalaqoh}',
                      ),
                    ),
                ],
                if (studentChanges.isEmpty && accountChanges.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: LucideIcons.folderLock,
                      title: 'Gak ada perubahan',
                      subtitle: 'Semua baris di file sama persis dengan data sekarang.',
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: includedCount == 0
                    ? null
                    : () => Navigator.of(context).pop(
                          _ImportSelection(
                            students: [
                              for (final row in studentChanges)
                                if (!_excludedStudents.contains(row.current.id)) row.toUpdatedStudent(),
                            ],
                            accounts: [
                              for (final row in accountChanges)
                                if (!_excludedAccounts.contains(row.current.id)) row.toUpdatedAccount(),
                            ],
                          ),
                        ),
                icon: const Icon(LucideIcons.circleCheck),
                label: Text('Terapkan $includedCount Perubahan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSectionLabel extends StatelessWidget {
  final String title;
  const _PreviewSectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.3,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _UnknownIdsBanner extends StatelessWidget {
  final List<String> studentUnknownIds;
  final List<String> accountUnknownIds;
  const _UnknownIdsBanner({required this.studentUnknownIds, required this.accountUnknownIds});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (studentUnknownIds.isNotEmpty)
        '${studentUnknownIds.length} baris murid id-nya gak dikenali: '
            '${studentUnknownIds.take(5).join(', ')}${studentUnknownIds.length > 5 ? ', ...' : ''}',
      if (accountUnknownIds.isNotEmpty)
        '${accountUnknownIds.length} baris guru id-nya gak dikenali: '
            '${accountUnknownIds.take(5).join(', ')}${accountUnknownIds.length > 5 ? ', ...' : ''}',
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 18, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('\n'),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nampilin kode Dart hasil generate (kSeedAccountsJson + kSeedStudentsJson)
/// buat di-copy manual sama developer ke local_seed_data.dart. Cuma
/// preview + copy -- gak ada tombol "simpan otomatis ke project" karena
/// app yang jalan di HP emang gak punya akses ke source code-nya sendiri.
class _SeedCodeScreen extends StatelessWidget {
  final String code;
  const _SeedCodeScreen({required this.code});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kode Seed (.dart)'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy),
            tooltip: 'Copy semua',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kode disalin ke clipboard.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: const Text(
              'Copy kode di bawah, tempel ke local_seed_data.dart (ganti isi kSeedAccountsJson '
              'dan kSeedStudentsJson yang lama), lalu build APK versi berikutnya. Ini cuma '
              'nyegerin fallback darurat -- data yang beneran kepakai sehari-hari tetap dari cloud.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                code,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu section -- salinan kecil dari `_SectionCard` di settings_screen.dart.
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: SectionLabel(title),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 16,
                      color: Theme.of(context).dividerTheme.color,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
