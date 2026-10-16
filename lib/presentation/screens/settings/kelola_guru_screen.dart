import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../data/models/kelas_halaqoh.dart';
import '../../../data/models/user_account.dart';
import '../../../data/repositories/api_auth_repository.dart';
import '../../../data/repositories/api_student_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/manage_list_widgets.dart';
import '../../widgets/common/motion_widgets.dart';
import '../../widgets/common/pushed_page_header.dart';
import '../../widgets/common/soft_icon_box.dart';
import '../../widgets/forms/field_decoration.dart';

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
  bool _syncingGuruAccountId = false;

  // <-- BARU: backfill manual [ApiStudentRepository.resyncAllGuruAccountIds]
  // -- beda dari reconcile otomatis di [_editAccount] yang cuma nyentuh
  // santri KENA DAMPAK edit assignment TERAKHIR. Tombol ini buat nutup
  // celah assignment lama yang dibuat sebelum reconcile itu ada, atau
  // santri yang guruAccountId-nya sempat ke-null-kan gara-gara bug
  // _accountsForGuruResolution dulu (lihat catatan di sana).
  Future<void> _resyncGuruAccountIds(BuildContext context) async {
    setState(() => _syncingGuruAccountId = true);
    try {
      final changed = await ApiStudentRepository.instance.resyncAllGuruAccountIds();
      if (!context.mounted) return;
      if (!mounted) return;
      setState(() => _syncingGuruAccountId = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed == 0
                ? 'Semua siswa sudah sesuai.'
                : 'Berhasil! $changed siswa disinkronkan ke guru pembimbing terbaru.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncingGuruAccountId = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal sinkron: $e')),
      );
    }
  }

  /// Dialog nama + username -> buat akun -> langsung buka sheet edit (isi email Google, pilih role).
  Future<void> _tambahAkun(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Akun'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama lengkap'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: userCtrl,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Username (tanpa spasi)', prefixText: '@'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buat')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final user = userCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    nameCtrl.dispose();
    userCtrl.dispose();
    if (ok != true || !context.mounted) return;
    if (name.isEmpty || user.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan username wajib diisi.')),
      );
      return;
    }
    try {
      final acc = await ApiAuthRepository.instance.createAccount(displayName: name, username: user);
      if (!context.mounted) return;
      await context.read<AuthProvider>().reloadAccounts();
      if (!context.mounted) return;
      await _editAccount(context, acc);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat akun: $e')));
    }
  }

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

  /// Hapus akun dengan penjagaan: bukan akun yang sedang dipakai, dan bukan admin terakhir.
  Future<void> _hapusAkun(BuildContext context, UserAccount acc) async {
    final authProvider = context.read<AuthProvider>();
    final studentsProvider = context.read<StudentsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (authProvider.currentUser?.id == acc.id) {
      messenger.showSnackBar(const SnackBar(content: Text('Akun yang sedang dipakai tidak bisa dihapus.')));
      return;
    }
    final adminCount = authProvider.allAccounts.where((a) => a.isAdmin).length;
    if (acc.isAdmin && adminCount <= 1) {
      messenger.showSnackBar(const SnackBar(content: Text('Admin terakhir tidak bisa dihapus.')));
      return;
    }

    final ok = await confirmDelete(
      context,
      title: 'Hapus akun ${acc.displayName}?',
      message: 'Akun dan akses login Google-nya akan dihapus.\n\n'
          '• Laporan yang pernah ditulis akun ini tidak ikut terhapus di cloud, tapi tidak lagi terhubung ke akun.\n'
          '• Guru pembimbing siswa di kelas/halaqoh akun ini akan dikosongkan sampai ada guru baru.\n\n'
          'Tindakan ini tidak bisa dibatalkan.',
    );
    if (!ok || !context.mounted) return;

    try {
      await ApiAuthRepository.instance.deleteAccount(acc);
      // Siswa yang terhubung ke akun ini: hitung ulang guru pembimbingnya dari daftar akun terbaru.
      final keys = {for (final a in acc.assignments) a.key};
      final affected = studentsProvider.all
          .where((st) => keys.contains(KelasHalaqoh(kelas: st.kelas, halaqoh: st.halaqoh).key))
          .toList();
      if (affected.isNotEmpty) {
        await ApiStudentRepository.instance.bulkUpdateKelasHalaqoh(affected);
      }
      if (!context.mounted) return;
      await authProvider.reloadAccounts();
      if (!context.mounted) return;
      await studentsProvider.load();
      messenger.showSnackBar(SnackBar(content: Text('Akun ${acc.displayName} dihapus.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  String _query = '';

  Widget _accountCard(BuildContext context, UserAccount acc, int index) {
    final cs = Theme.of(context).colorScheme;
    final noGoogleEmail = acc.googleEmail == null;
    final roleColor = acc.isAdmin ? cs.tertiary : (acc.isPengawas ? cs.secondary : cs.primary);
    return ManageRowCard(
      leading: SoftIconBox(
        icon: acc.isAdmin ? LucideIcons.shield : (acc.isPengawas ? LucideIcons.eye : LucideIcons.user),
        color: noGoogleEmail ? cs.error : roleColor,
        size: 22,
        padding: 11,
        radius: 14,
      ),
      index: index,
      title: acc.displayName,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            noGoogleEmail ? '@${acc.username}' : '@${acc.username} • ${acc.googleEmail}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ManageChip(label: acc.role.label, color: roleColor),
              if (acc.assignments.isNotEmpty)
                ManageChip(
                  label: '${acc.assignments.length} kelas/halaqoh',
                  color: cs.onSurfaceVariant,
                  icon: LucideIcons.usersRound,
                ),
              if (noGoogleEmail)
                ManageChip(label: 'Belum ada email Google', color: cs.error, icon: LucideIcons.triangleAlert),
            ],
          ),
        ],
      ),
      onTap: () => _editAccount(context, acc),
      onEdit: () => _editAccount(context, acc),
      onDelete: () => _hapusAkun(context, acc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AuthProvider>().allAccounts;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? accounts
        : accounts
            .where((a) =>
                a.displayName.toLowerCase().contains(q) ||
                a.username.toLowerCase().contains(q) ||
                (a.googleEmail ?? '').toLowerCase().contains(q))
            .toList();
    int byName(UserAccount a, UserAccount b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    final admins = filtered.where((a) => a.isAdmin).toList()..sort(byName);
    final pengawas = filtered.where((a) => a.isPengawas).toList()..sort(byName);
    final guru = filtered.where((a) => !a.isAdmin && !a.isPengawas).toList()..sort(byName);

    Widget section(String title, List<UserAccount> list) => SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(child: ManageSectionHeader(title: title, count: list.length)),
            SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => _accountCard(context, list[i], i),
            ),
          ],
        );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tambahAkun(context),
        icon: const Icon(LucideIcons.userPlus),
        label: const Text('Tambah Akun'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            PushedPageHeader(
              title: 'Kelola Akun Guru',
              subtitle: '${accounts.length} akun',
              titleFontSize: 17,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: _refreshing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.refreshCw),
                    onPressed: _refreshing ? null : _refresh,
                    tooltip: 'Muat ulang dari cloud',
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Lainnya',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    enabled: !_syncingGuruAccountId,
                    onSelected: (v) {
                      if (v == 'sync') _resyncGuruAccountIds(context);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'sync',
                        child: Row(children: [
                          _syncingGuruAccountId
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(LucideIcons.users, size: 18),
                          const SizedBox(width: 12),
                          const Text('Sinkronkan guru ke siswa'),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: fieldDecoration(context, icon: LucideIcons.search, label: 'Cari nama, username, atau email'),
                ),
              ),
            ),
            if (accounts.isEmpty && _refreshing)
              const SliverToBoxAdapter(child: SkeletonList())
            else if (accounts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.medal,
                  title: 'Belum ada akun guru',
                  subtitle: 'Coba muat ulang, atau jalankan migrasi data di Pengaturan > Kelola Sekolah.',
                ),
              )
            else if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.search,
                  title: 'Tidak ditemukan',
                  subtitle: 'Coba kata kunci lain.',
                ),
              )
            else ...[
              if (admins.isNotEmpty) section('ADMIN', admins),
              if (pengawas.isNotEmpty) section('PENGAWAS', pengawas),
              if (guru.isNotEmpty) section('GURU PEMBIMBING', guru),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ],
        ),
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
    final kelasList = <String>{
      ...studentsProvider.all.map((s) => s.kelas),
      ...authProvider.allAccounts.expand((a) => a.assignments.map((x) => x.kelas)),
    };
    for (final k in kelasList) {
      for (final h in standardHalaqohForKelas(k)) {
        final p = KelasHalaqoh(kelas: k, halaqoh: h);
        allPairs.putIfAbsent(p.key, () => p);
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
    // Role admin (akses global). Akun yang sedang dipakai login TIDAK boleh diubah rolenya dari
    // sini, supaya admin tidak tidak sengaja mencabut akses admin dirinya sendiri.
    var selectedRole = account.role;
    final isSelf = authProvider.currentUser?.id == account.id;
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
                          label: 'Email Google (untuk login)',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dipakai untuk login dengan Google. Kosongkan untuk mencabut akses.',
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 11.5),
                      ),
                      Text('Role', style: Theme.of(ctx).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      SegmentedButton<UserRole>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: UserRole.guruPembimbing, label: Text('Guru')),
                          ButtonSegment(value: UserRole.pengawas, label: Text('Pengawas')),
                          ButtonSegment(value: UserRole.admin, label: Text('Admin')),
                        ],
                        selected: {selectedRole},
                        onSelectionChanged: isSelf ? null : (v) => setSheetState(() => selectedRole = v.first),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSelf
                            ? 'Role akun yang sedang dipakai tidak bisa diubah dari sini.'
                            : switch (selectedRole) {
                                UserRole.admin => 'Admin: akses global, boleh mengubah data dan mengelola sekolah.',
                                UserRole.pengawas => 'Pengawas: melihat semua kelas, halaqoh, statistik, dan ekspor. Tidak bisa mengubah data.',
                                UserRole.guruPembimbing => 'Guru: hanya kelas dan halaqoh yang diampu.',
                              },
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 11.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kelas & halaqoh yang diampu',
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
                                    // Role diubah DULU dan akun hasilnya dipakai sebagai basis
                                    // updateAssignments, karena updateAssignments menulis ulang
                                    // seluruh dokumen (role lama akan menimpa kalau basisnya `account`).
                                    var base = account;
                                    if (selectedRole != account.role) {
                                      final newRole = selectedRole;
                                      await ApiAuthRepository.instance.updateRole(account, newRole);
                                      base = await ApiAuthRepository.instance.findById(account.id) ??
                                          account.copyWith(role: newRole);
                                    }
                                    await ApiAuthRepository.instance.updateAssignments(
                                      base,
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

                                    // <-- BARU: reconcile [Student.guruAccountId].
                                    // BUG yang diperbaiki: updateAssignments di
                                    // atas cuma nulis `accounts/{id}.assignments`
                                    // — TIDAK PERNAH menyentuh dokumen
                                    // `students/{id}` mana pun. Padahal
                                    // `guruAccountId` di situ adalah field
                                    // DENORMALISASI yang cuma kehitung ulang
                                    // saat `updateKelasHalaqoh`/
                                    // `bulkUpdateKelasHalaqoh` jalan (lihat
                                    // ApiStudentRepository) — biasanya dari
                                    // Kelola Data Murid, BUKAN dari sini.
                                    // Akibatnya: assign guru pembimbing ke
                                    // kelas+halaqoh yang SANTRINYA SUDAH ADA
                                    // duluan tidak pernah ke-reflect ke
                                    // Portal Ortu — guruAccountId mereka
                                    // tetap null/basi SELAMANYA sampai ada
                                    // yang kebetulan re-save kelas/halaqoh
                                    // santri itu satu-satu secara manual.
                                    //
                                    // Fix: begitu assignment BERUBAH, cari
                                    // semua santri yang kelas+halaqoh-nya ada
                                    // di assignment LAMA *atau* BARU (union —
                                    // assignment yang DICABUT juga perlu
                                    // reconcile, bukan cuma yang ditambah,
                                    // supaya guruAccountId mereka ikut
                                    // diperbarui ke guru lain/null kalau ada
                                    // pergantian), lalu panggil
                                    // `bulkUpdateKelasHalaqoh` dengan
                                    // kelas/halaqoh MEREKA SENDIRI (tidak
                                    // diubah) — method itu tetap recompute
                                    // guruAccountId dari assignment TERBARU
                                    // (yang barusan disimpan), jadi cukup
                                    // "re-save" tanpa perlu buka Kelola Data
                                    // Murid satu-satu.
                                    final affectedKeys = <String>{
                                      for (final a in account.assignments) a.key,
                                      for (final a in newAssignments) a.key,
                                    };
                                    final affectedStudents = studentsProvider.all
                                        .where((s) => affectedKeys
                                            .contains(KelasHalaqoh(kelas: s.kelas, halaqoh: s.halaqoh).key))
                                        .toList();
                                    if (affectedStudents.isNotEmpty) {
                                      await ApiStudentRepository.instance
                                          .bulkUpdateKelasHalaqoh(affectedStudents);
                                    }

                                    if (!ctx.mounted) return;
                                    await authProvider.reloadAccounts();
                                    if (!ctx.mounted) return;
                                    await studentsProvider.load();
                                    if (!ctx.mounted) return;
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(affectedStudents.isEmpty
                                            ? 'Akun ${nameCtrl.text.trim()} tersimpan.'
                                            : 'Akun ${nameCtrl.text.trim()} tersimpan. '
                                                '${affectedStudents.length} siswa disinkronkan.'),
                                      ),
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
