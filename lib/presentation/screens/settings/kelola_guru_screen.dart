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
import 'kelola_guru_edit_sheet.dart';

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
      await showEditAccountSheet(context, acc);
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
      onTap: () => showEditAccountSheet(context, acc),
      onEdit: () => showEditAccountSheet(context, acc),
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

}
