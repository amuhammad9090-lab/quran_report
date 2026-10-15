import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../data/models/kelas_halaqoh.dart';
import '../../../data/models/student.dart';
import '../../../data/repositories/api_student_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/manage_list_widgets.dart';
import '../../widgets/common/pushed_page_header.dart';
import '../../widgets/common/soft_icon_box.dart';
import '../../widgets/forms/field_decoration.dart';
import '../../widgets/forms/select_field.dart';

/// Layar ADMIN-ONLY buat ngedit kelas/halaqoh satu santri (mis. santri
/// Tahsin yang udah mampu dipindah ke halaqoh Tahfizh) — LANGSUNG lewat
/// app, gak perlu edit `local_seed_data.dart` + build ulang APK. Lihat
/// ApiStudentRepository buat penjelasan lengkap arsitekturnya.
class KelolaMuridScreen extends StatefulWidget {
  const KelolaMuridScreen({super.key});

  @override
  State<KelolaMuridScreen> createState() => _KelolaMuridScreenState();
}

class _KelolaMuridScreenState extends State<KelolaMuridScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await ApiStudentRepository.instance.refresh();
    if (!mounted) return;
    await context.read<StudentsProvider>().load();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _hapusSiswa(BuildContext context, Student s) async {
    final provider = context.read<StudentsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDelete(
      context,
      title: 'Hapus ${s.nama}?',
      message: 'Siswa ini akan dihapus dari data master (${s.kelas} • ${s.halaqoh}) '
          'dan tidak muncul lagi di pilihan nama saat membuat laporan.\n\n'
          'Laporan yang sudah pernah ditulis tidak ikut terhapus.\n\n'
          'Tindakan ini tidak bisa dibatalkan.',
    );
    if (!ok || !context.mounted) return;
    try {
      await ApiStudentRepository.instance.deleteStudent(s);
      await provider.load();
      messenger.showSnackBar(SnackBar(content: Text('${s.nama} dihapus.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  String? _kelasFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final students = context.watch<StudentsProvider>().all;
    final q = _query.trim().toLowerCase();
    final kelasList = students.map((s) => s.kelas).toSet().toList()..sort();
    final filtered = students
        .where((s) => (_kelasFilter == null || s.kelas == _kelasFilter) && (q.isEmpty || s.nama.toLowerCase().contains(q)))
        .toList();

    // Urut biar gampang di-scan: kelas -> halaqoh -> nama.
    final sorted = [...filtered]..sort((a, b) {
        final byKelas = a.kelas.compareTo(b.kelas);
        if (byKelas != 0) return byKelas;
        final byHalaqoh = a.halaqoh.compareTo(b.halaqoh);
        if (byHalaqoh != 0) return byHalaqoh;
        return a.nama.toLowerCase().compareTo(b.nama.toLowerCase());
      });

    // Kelompokkan per "Kelas • Halaqoh" (urutan tetap mengikuti sorted).
    final groups = <String, List<Student>>{};
    for (final s in sorted) {
      groups.putIfAbsent('${s.kelas} • ${s.halaqoh}', () => []).add(s);
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Kelola Data Siswa',
              subtitle: _kelasFilter == null || q.isNotEmpty
                  ? '${filtered.length} dari ${students.length} siswa'
                  : '${filtered.length} siswa • Kelas $_kelasFilter',
              titleFontSize: 17,
              trailing: IconButton(
                icon: _refreshing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.refreshCw),
                onPressed: _refreshing ? null : _refresh,
                tooltip: 'Muat ulang dari cloud',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: fieldDecoration(context, icon: LucideIcons.search, label: 'Cari nama siswa'),
                ),
              ),
            ),
            if (kelasList.length > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Semua'),
                          selected: _kelasFilter == null,
                          onSelected: (_) => setState(() => _kelasFilter = null),
                        ),
                      ),
                      for (final k in kelasList)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('Kelas $k'),
                            selected: _kelasFilter == k,
                            onSelected: (_) => setState(() => _kelasFilter = _kelasFilter == k ? null : k),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (students.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.users,
                  title: 'Belum ada data siswa',
                  subtitle: 'Coba muat ulang, atau jalankan migrasi data di Pengaturan > Kelola Sekolah.',
                ),
              )
            else if (sorted.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.search,
                  title: 'Tidak ditemukan',
                  subtitle: 'Coba kata kunci atau filter kelas lain.',
                ),
              )
            else ...[
              for (final e in groups.entries)
                SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: ManageSectionHeader(title: 'KELAS ${e.key}'.toUpperCase(), count: e.value.length),
                    ),
                    SliverList.builder(
                      itemCount: e.value.length,
                      itemBuilder: (context, i) {
                        final s = e.value[i];
                        return ManageRowCard(
                          leading: SoftIconBox(
                            icon: LucideIcons.user,
                            color: cs.primary,
                            size: 20,
                            padding: 10,
                            radius: 14,
                          ),
                          title: s.nama,
                          body: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ManageChip(label: 'Kelas ${s.kelas}', color: cs.onSurfaceVariant),
                              ManageChip(label: s.halaqoh, color: cs.primary, icon: LucideIcons.usersRound),
                            ],
                          ),
                          editLabel: 'Pindah kelas/halaqoh',
                          onTap: () => _editStudent(context, s),
                          onEdit: () => _editStudent(context, s),
                          onDelete: () => _hapusSiswa(context, s),
                        );
                      },
                    ),
                  ],
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editStudent(BuildContext context, Student student) async {
    final studentsProvider = context.read<StudentsProvider>();
    final authProvider = context.read<AuthProvider>();
    final allKelas = <String>{
      ...studentsProvider.all.map((s) => s.kelas),
      ...authProvider.allAccounts.expand((a) => a.assignments.map((x) => x.kelas)),
    }.toList()
      ..sort();

    String? kelas = student.kelas;
    String? halaqoh = student.halaqoh;

    List<String> halaqohOptionsFor(String? k) {
      if (k == null) return const [];
      return <String>{
        ...kStandardHalaqoh,
        ...studentsProvider.all.where((s) => s.kelas == k).map((s) => s.halaqoh),
        ...authProvider.allAccounts
            .expand((a) => a.assignments)
            .where((x) => x.kelas == k)
            .map((x) => x.halaqoh),
      }.toList()
        ..sort();
    }

    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final halaqohOptions = halaqohOptionsFor(kelas);
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.nama, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Kelas & halaqoh sekarang: ${student.kelas} • ${student.halaqoh}',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  SelectField(
                    value: kelas,
                    label: 'Kelas baru',
                    icon: LucideIcons.graduationCap,
                    options: allKelas,
                    onChanged: (v) => setSheetState(() {
                      kelas = v;
                      halaqoh = null; // reset -- halaqoh tergantung kelas
                    }),
                  ),
                  const SizedBox(height: 12),
                  SelectField(
                    value: halaqoh,
                    label: 'Halaqoh baru',
                    hint: kelas == null ? 'Pilih kelas dulu' : null,
                    icon: LucideIcons.usersRound,
                    options: halaqohOptions,
                    enabled: kelas != null,
                    onChanged: (v) => setSheetState(() => halaqoh = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (kelas == null || halaqoh == null || saving)
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              try {
                                await ApiStudentRepository.instance.updateKelasHalaqoh(
                                  student,
                                  kelas: kelas!,
                                  halaqoh: halaqoh!,
                                );
                                if (!ctx.mounted) return;
                                await studentsProvider.load();
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${student.nama} dipindah ke $kelas • $halaqoh.')),
                                );
                              } catch (e) {
                                setSheetState(() => saving = false);
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Gagal menyimpan: $e')),
                                );
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.save),
                      label: Text(saving ? 'Menyimpan...' : 'Simpan'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
