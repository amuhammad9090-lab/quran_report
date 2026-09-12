import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/student.dart';
import '../../../data/repositories/api_student_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    // <-- Beda dari StudentsProvider.load() biasa (yang cache-first buat
    // startup cepat, lihat ApiStudentRepository.getAll) -- di sini admin
    // BARU MAU EDIT, jadi wajar nunggu data ter-anyar dari Firestore
    // dulu (ApiStudentRepository.refresh, ada timeout 10 detik).
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final students = context.watch<StudentsProvider>().all;
    final filtered = _query.trim().isEmpty
        ? students
        : students.where((s) => s.nama.toLowerCase().contains(_query.toLowerCase())).toList();

    // Urut biar gampang di-scan: kelas -> halaqoh -> nama.
    final sorted = [...filtered]..sort((a, b) {
        final byKelas = a.kelas.compareTo(b.kelas);
        if (byKelas != 0) return byKelas;
        final byHalaqoh = a.halaqoh.compareTo(b.halaqoh);
        if (byHalaqoh != 0) return byHalaqoh;
        return a.nama.compareTo(b.nama);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Data Murid'),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.refreshCw),
            onPressed: _refreshing ? null : _refresh,
            tooltip: 'Muat ulang dari cloud',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: fieldDecoration(context, icon: LucideIcons.search, label: 'Cari nama santri'),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? const EmptyState(
                    icon: LucideIcons.users,
                    title: 'Belum ada data murid',
                    subtitle: 'Coba muat ulang, atau jalankan migrasi data dari Pengaturan dulu.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final s = sorted[i];
                      return ListTile(
                        leading: SoftIconBox(icon: LucideIcons.user, color: cs.primary),
                        title: Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${s.kelas} • ${s.halaqoh}'),
                        trailing: const Icon(LucideIcons.penLine),
                        onTap: () => _editStudent(context, s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editStudent(BuildContext context, Student student) async {
    final studentsProvider = context.read<StudentsProvider>();
    final authProvider = context.read<AuthProvider>();

    // Daftar kelas & halaqoh yang VALID diambil dari data murid+guru yang
    // SUDAH ADA saat ini (bukan diketik bebas) — biar gak ada typo yang
    // bikin santri "hilang" karena kelas/halaqoh-nya nggak cocok sama
    // assignment guru manapun (lihat AccessScope — pencocokan kelas &
    // halaqoh itu EXACT STRING MATCH).
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
