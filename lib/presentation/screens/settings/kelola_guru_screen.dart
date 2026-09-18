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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Kelola Akun Guru',
              titleFontSize: 17,
              trailing: IconButton(
                icon: _refreshing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.refreshCw),
                onPressed: _refreshing ? null : _refresh,
                tooltip: 'Muat ulang dari cloud',
              ),
            ),
            if (sorted.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.medal,
                  title: 'Belum ada akun guru',
                  subtitle: 'Coba muat ulang, atau jalankan migrasi data dari Pengaturan dulu.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final acc = sorted[i];
                    // <-- BARU (migrasi auth): tanda kecil kalau akun ini
                    // BELUM di-mapping email Google -- berarti guru
                    // tersebut belum/tidak bisa login sama sekali (lihat
                    // dokumentasi UserAccount.googleEmail).
                    final noGoogleEmail = acc.googleEmail == null;
                    return ListTile(
                      leading: SoftIconBox(
                        icon: acc.isAdmin ? LucideIcons.shield : LucideIcons.user,
                        color: noGoogleEmail ? cs.error : cs.primary,
                      ),
                      title: Text(acc.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          '@${acc.username}',
                          if (acc.assignments.isNotEmpty) '${acc.assignments.length} assignment' else acc.role.label,
                          if (noGoogleEmail) 'belum ada email Google' else acc.googleEmail!,
                        ].join(' • '),
                        style: noGoogleEmail ? TextStyle(color: cs.error) : null,
                      ),
                      trailing: const Icon(LucideIcons.penLine),
                      onTap: () => _editAccount(context, acc),
                    );
                  },
                ),
              ),
          ],
        ),
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
    // <-- BARU (migrasi auth: Anonymous -> Google Sign-In). Ini
    // SATU-SATUNYA tempat admin men-daftarkan (whitelist) email Google
    // seorang guru -- tanpa ini, guru itu TIDAK BISA login sama sekali
    // (lihat AuthRepository.findByGoogleEmail & ApiAuthRepository.
    // updateGoogleEmail). Kosongkan field ini buat MENCABUT akses login
    // Google guru tersebut (assignment/data laporannya TIDAK ikut
    // terhapus, cuma tidak bisa login lagi sampai diisi ulang).
    final googleEmailCtrl = TextEditingController(text: account.googleEmail ?? '');
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: googleEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: fieldDecoration(
                          ctx,
                          icon: LucideIcons.mail,
                          label: 'Email Google (buat login)',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Guru login pakai akun Google ini. Kosongkan untuk mencabut akses login.',
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 11.5),
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
                                    // <-- BARU (migrasi auth): simpan
                                    // mapping email Google TERPISAH dari
                                    // updateAssignments di atas (dua
                                    // dokumen Firestore berbeda yang
                                    // perlu di-jaga sinkron -- lihat
                                    // dokumentasi ApiAuthRepository.
                                    // updateGoogleEmail).
                                    //
                                    // PENTING: pakai account HASIL
                                    // updateAssignments barusan (via
                                    // findById, yang bacanya dari cache
                                    // yang SUDAH ke-update) sebagai
                                    // referensi -- BUKAN `account` yang
                                    // lama (dari sebelum sheet ini
                                    // dibuka). Kalau pakai yang lama,
                                    // updateGoogleEmail akan menulis
                                    // ULANG accounts/{id} dengan
                                    // displayName/assignments yang SUDAH
                                    // BASI, menimpa balik perubahan yang
                                    // baru saja disimpan updateAssignments
                                    // di atas.
                                    final refreshed = await ApiAuthRepository.instance.findById(account.id) ?? account;
                                    final newEmail = googleEmailCtrl.text.trim();
                                    await ApiAuthRepository.instance.updateGoogleEmail(
                                      refreshed,
                                      newEmail.isEmpty ? null : newEmail,
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
