import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/kelas_halaqoh.dart';
import '../../../data/models/user_account.dart';
import '../../../data/repositories/api_auth_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Layar ADMIN-ONLY buat ngedit nama tampilan & assignment kelas+halaqoh
/// akun guru pembimbing — LANGSUNG lewat app, gak perlu edit
/// `local_seed_data.dart` + build ulang APK. SENGAJA TIDAK termasuk ganti
/// password/role dari sini — itu tetap lewat alur yang sudah ada (lihat
/// ApiAuthRepository.updateAssignments).
class KelolaGuruScreen extends StatefulWidget {
  const KelolaGuruScreen({super.key});

  @override
  State<KelolaGuruScreen> createState() => _KelolaGuruScreenState();
}

class _KelolaGuruScreenState extends State<KelolaGuruScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // <-- Sama alasannya kayak KelolaMuridScreen: admin BARU MAU EDIT,
    // wajar nunggu data ter-anyar dulu (bukan cache-first kayak startup).
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await ApiAuthRepository.instance.refresh();
    if (!mounted) return;
    await context.read<AuthProvider>().reloadAccounts();
    if (!mounted) return;
    await context.read<StudentsProvider>().load();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accounts = context.watch<AuthProvider>().allAccounts;
    final sorted = [...accounts]..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Akun Guru'),
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
      body: sorted.isEmpty
          ? const EmptyState(
              icon: LucideIcons.medal,
              title: 'Belum ada akun guru',
              subtitle: 'Coba muat ulang, atau jalankan migrasi data dari Pengaturan dulu.',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final acc = sorted[i];
                return ListTile(
                  leading: SoftIconBox(
                    icon: acc.isAdmin ? LucideIcons.shield : LucideIcons.user,
                    color: cs.primary,
                  ),
                  title: Text(acc.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    acc.assignments.isEmpty
                        ? '@${acc.username} • ${acc.role.label}'
                        : '@${acc.username} • ${acc.assignments.length} assignment',
                  ),
                  trailing: const Icon(LucideIcons.penLine),
                  onTap: () => _editAccount(context, acc),
                );
              },
            ),
    );
  }

  Future<void> _editAccount(BuildContext context, UserAccount account) async {
    final authProvider = context.read<AuthProvider>();
    final studentsProvider = context.read<StudentsProvider>();

    // Semua pasangan kelas+halaqoh yang VALID & udah dikenal saat ini
    // (dari data murid + assignment guru lain) — admin tinggal centang,
    // bukan ngetik bebas (biar gak ada typo yang bikin assignment gak
    // cocok sama kelas/halaqoh manapun -- lihat catatan yang sama di
    // KelolaMuridScreen).
    final allPairs = <String, KelasHalaqoh>{};
    for (final s in studentsProvider.all) {
      final p = KelasHalaqoh(kelas: s.kelas, halaqoh: s.halaqoh);
      allPairs[p.key] = p;
    }
    for (final a in authProvider.allAccounts) {
      for (final p in a.assignments) {
        allPairs[p.key] = p;
      }
    }
    final pairOptions = allPairs.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    final nameCtrl = TextEditingController(text: account.displayName);
    final selected = {for (final a in account.assignments) a.key};
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${account.username}',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: fieldDecoration(ctx, icon: LucideIcons.medal, label: 'Nama tampilan'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Assignment kelas+halaqoh (${account.role.label})',
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: pairOptions.length,
                          itemBuilder: (context, i) {
                            final p = pairOptions[i];
                            final checked = selected.contains(p.key);
                            return CheckboxListTile(
                              value: checked,
                              title: Text(p.label),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setSheetState(() {
                                if (v == true) {
                                  selected.add(p.key);
                                } else {
                                  selected.remove(p.key);
                                }
                              }),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (saving || nameCtrl.text.trim().isEmpty)
                              ? null
                              : () async {
                                  setSheetState(() => saving = true);
                                  try {
                                    final newAssignments = pairOptions.where((p) => selected.contains(p.key)).toList();
                                    await ApiAuthRepository.instance.updateAssignments(
                                      account,
                                      displayName: nameCtrl.text.trim(),
                                      assignments: newAssignments,
                                    );
                                    if (!ctx.mounted) return;
                                    await authProvider.reloadAccounts();
                                    if (!ctx.mounted) return;
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Akun ${nameCtrl.text.trim()} tersimpan.')),
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
      },
    );
  }
}
