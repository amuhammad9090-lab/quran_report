import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../data/models/student.dart';
import '../../../data/models/user_account.dart';
import '../../../data/repositories/api_auth_repository.dart';
import '../../../data/repositories/api_student_repository.dart';
import '../../../data/services/platform_file/file_actions.dart';
import '../../../data/services/school_data_excel_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/common/pushed_page_header.dart';
import '../../widgets/common/soft_icon_box.dart';
import 'kelola_data_import_preview.dart';
import 'kelola_data_widgets.dart';
import 'kelola_guru_screen.dart';
import 'kelola_murid_screen.dart';

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
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  const PushedPageHeader(
                    title: 'Kelola Sekolah',
                    titleFontSize: 17,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    sliver: SliverList.list(
                      children: [
                        KelolaSectionCard(
                          title: 'Kelola Data',
                          children: [
                            ListTile(
                              leading: SoftIconBox(icon: LucideIcons.medal, color: cs.primary),
                              title: const Text('Kelola Guru'),
                              subtitle: const Text('Ubah nama, role, dan kelas/halaqoh guru'),
                              trailing: const Icon(LucideIcons.chevronRight),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const KelolaGuruScreen()),
                              ),
                            ),
                            ListTile(
                              leading: SoftIconBox(icon: LucideIcons.users, color: cs.primary),
                              title: const Text('Kelola Siswa'),
                              subtitle: const Text('Pindah kelas/halaqoh (mis. naik Tahsin → Tahfizh)'),
                              trailing: const Icon(LucideIcons.chevronRight),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const KelolaMuridScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        KelolaSectionCard(
                          title: 'Ekspor & Impor',
                          children: [
                            ListTile(
                              leading: SoftIconBox(icon: LucideIcons.fileDown, color: cs.primary),
                              title: const Text('Ekspor ke Excel'),
                              subtitle: const Text('Satu file .xlsx, sheet "Siswa" & "Guru"'),
                              onTap: () => _withBusy(() => _exportExcel(context)),
                            ),
                            ListTile(
                              leading: SoftIconBox(icon: LucideIcons.cloudUpload, color: cs.primary),
                              title: const Text('Impor dari Excel'),
                              subtitle: const Text('Unggah file yang sudah diedit (ada pratinjau dulu)'),
                              onTap: () => _withBusy(() => _importExcel(context)),
                            ),
                            ListTile(
                              leading: SoftIconBox(icon: LucideIcons.code, color: cs.primary),
                              title: const Text('Export sebagai kode seed (.dart)'),
                              subtitle: const Text('Untuk developer: cadangan data awal di dalam app'),
                              onTap: () => _withBusy(() => _exportSeedCode(context)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
        const SnackBar(content: Text('Belum ada data guru/siswa untuk diekspor.')),
      );
      return;
    }
    try {
      final file = await SchoolDataExcelService.instance.saveWorkbook(students, accounts);
      if (!context.mounted) return;
      await shareExportedFile(
        file,
        subject: 'Data Guru & Siswa. Edit sheet "Siswa"/"Guru", lalu unggah lewat "Impor dari Excel".',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ekspor: $e')));
    }
  }

  Future<void> _exportSeedCode(BuildContext context) async {
    final (students, accounts) = await _refreshedData();
    if (!context.mounted) return;
    if (students.isEmpty && accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data guru/siswa untuk diekspor.')),
      );
      return;
    }
    final code = SchoolDataExcelService.instance.buildSeedDartCode(students, accounts);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeedCodeScreen(code: code)),
    );
  }

  Future<void> _importExcel(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result.isEmpty) return; // dibatalin user (v13: list kosong, bukan null)
    final bytes = await result.first.readAsBytes();

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
        SnackBar(content: Text('File tidak terbaca. Gunakan file .xlsx hasil ekspor dari sini. ($e)')),
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
                ? 'Tidak ada perubahan di file ini.'
                : 'Tidak ada perubahan valid. $unknownTotal baris dengan ID tidak dikenali.',
          ),
        ),
      );
      return;
    }

    final applied = await Navigator.of(context).push<ImportSelection>(
      MaterialPageRoute(builder: (_) => ImportPreviewScreen(result: parsed)),
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
          content: Text('Berhasil! $writtenStudents siswa & $writtenAccounts guru diperbarui.'),
        ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }
}

