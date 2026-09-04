import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart'; // <-- BARU
import '../../../providers/records_provider.dart';
import '../../../providers/folders_provider.dart'; // <-- BARU
import '../../../data/services/storage_service.dart';
import '../../../data/services/app_prefs_service.dart'; // <-- BARU
import '../../widgets/misc_widgets.dart';
import '../about/about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 3,
            shadowColor: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10),
            toolbarHeight: 62,
            titleSpacing: 20,
            title: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pengaturan',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverList.list(
              children: [
                _SectionCard(
                  title: 'Tampilan',
                  children: [
                    _ThemeOption(
                      icon: Icons.light_mode_rounded,
                      label: 'Terang',
                      selected: themeProvider.mode == ThemeMode.light,
                      onTap: () => themeProvider.setMode(ThemeMode.light),
                    ),
                    _ThemeOption(
                      icon: Icons.dark_mode_rounded,
                      label: 'Gelap',
                      selected: themeProvider.mode == ThemeMode.dark,
                      onTap: () => themeProvider.setMode(ThemeMode.dark),
                    ),
                    _ThemeOption(
                      icon: Icons.smartphone_rounded,
                      label: 'Ikuti Sistem',
                      selected: themeProvider.mode == ThemeMode.system,
                      onTap: () => themeProvider.setMode(ThemeMode.system),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Data',
                  children: [
                    ListTile(
                      leading: SoftIconBox(
                        icon: Icons.cloud_upload_outlined,
                        color: cs.primary,
                      ),
                      title: const Text('Backup ke Cloud'),
                      subtitle: const Text('Kirim ulang semua laporan ke Portal Orang Tua'),
                      onTap: () => _syncToCloud(context),
                    ),
                    // <-- BARU: seluruh ListTile ini. Kebalikan dari
                    // "Backup ke Cloud" — dipakai kalau data lokal di HP
                    // ini hilang (HP baru, app di-uninstall install
                    // ulang, atau kalau app ini dipakai sebagai Web/PWA
                    // lalu cache-nya dibersihkan/PWA-nya dihapus dari
                    // Home Screen).
                    ListTile(
                      leading: SoftIconBox(
                        icon: Icons.cloud_download_outlined,
                        color: cs.primary,
                      ),
                      title: const Text('Pulihkan dari Cloud'),
                      subtitle: const Text('Tarik kembali laporan yang pernah di-backup'),
                      onTap: () => _confirmRestoreFromCloud(context),
                    ),
                    ListTile(
                      leading: SoftIconBox(
                        icon: Icons.delete_sweep_outlined,
                        color: cs.error,
                      ),
                      title: const Text('Hapus Semua Data'),
                      subtitle: const Text('Menghapus seluruh laporan tersimpan'),
                      onTap: () => _confirmClearAll(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Lainnya',
                  children: [
                    ListTile(
                      leading: SoftIconBox(
                        icon: Icons.info_outline_rounded,
                        color: cs.primary,
                      ),
                      title: const Text('Tentang Aplikasi'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // <-- BARU: seluruh method ini. Handler tombol "Sinkronkan ke Cloud".
  Future<void> _syncToCloud(BuildContext context) async {
    // Dialog loading tak-tertutup (barrierDismissible: false) — sengaja,
    // biar guru gak nge-tap-tap lagi selagi proses jalan (bisa makan
    // beberapa detik kalau laporannya ratusan).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 16),
            Expanded(child: Text('Menyinkronkan laporan...')),
          ],
        ),
      ),
    );

    try {
      final count = await StorageService.instance.syncAllToFirestore();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // tutup dialog loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil! $count laporan tersinkron ke cloud.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal sinkron: $e. Cek koneksi internet, lalu coba lagi.')),
      );
    }
  }

  // <-- BARU: seluruh method ini. Konfirmasi dulu sebelum "Pulihkan dari
  // Cloud" — walau restore-nya sendiri aman (laporan yang diedit lebih
  // baru di lokal tidak akan ketiban versi cloud yang lebih lama, lihat
  // StorageService.restoreFromFirestore), tetap butuh koneksi internet &
  // makan beberapa detik kalau laporannya banyak, jadi guru perlu tahu
  // dulu sebelum mulai.
  void _confirmRestoreFromCloud(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan dari Cloud?'),
        content: const Text(
          'Semua laporan yang pernah ter-backup ke cloud akan ditarik kembali ke HP ini. '
          'Laporan yang sudah ada & lebih baru di HP ini tidak akan ditimpa. Butuh koneksi internet.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restoreFromCloud(context);
            },
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreFromCloud(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 16),
            Expanded(child: Text('Memulihkan laporan...')),
          ],
        ),
      ),
    );

    try {
      // <-- BERUBAH: folder dipulihkan DULUAN sebelum laporan. Urutan ini
      // sengaja — laporan yang balik dari Firestore masih bawa `folderId`
      // lama, jadi folder tujuannya harus sudah ada di Hive duluan
      // sebelum RecordsProvider/FoldersProvider di-reload, supaya laporan
      // itu langsung ketemu folder "rumah"-nya begitu tab Laporan
      // ke-render (tidak sempat kelihatan "hilang" walau cuma sekejap).
      // <-- BERUBAH: pass scope guru yang lagi login, biar restore cuma
      // narik record kelas+halaqoh yang emang tanggung jawabnya (lihat
      // catatan lengkap di StorageService.restoreFromFirestore).
      final scope = context.read<AuthProvider>().scope;
      await StorageService.instance.restoreFoldersFromFirestore();
      final count =
          await StorageService.instance.restoreFromFirestore(scope: scope);
      // Metadata kartu kosong (identitas yang diaktifkan tapi belum ada
      // laporannya) ikut dipulihkan juga — lihat catatan lengkapnya di
      // AppPrefsService.restoreActivatedMetaFromFirestore soal kenapa ini
      // perlu, BUKAN cuma data laporan.
      await AppPrefsService.instance.restoreActivatedMetaFromFirestore();
      if (!context.mounted) return;
      // Reload provider supaya seluruh app (tab Laporan, Statistik, dst)
      // langsung baca data yang baru dipulihkan ini. FoldersProvider juga
      // ikut di-reload — sebelumnya luput, jadi walau foldernya sudah
      // masuk ke Hive, tab Laporan/FolderDetail masih nampilin state
      // folder yang LAMA (sebelum restore) sampai app di-restart manual.
      await context.read<RecordsProvider>().load();
      if (!context.mounted) return;
      await context.read<FoldersProvider>().load();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // tutup dialog loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil! $count laporan dipulihkan dari cloud.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memulihkan: $e. Cek koneksi internet, lalu coba lagi.')),
      );
    }
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: const Text(
            'Seluruh laporan yang tersimpan akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () async {
              await context.read<RecordsProvider>().clearAllData();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }
}

/// Kotak ikon bertinta lembut untuk leading icon list tile pengaturan —
/// pakai [SoftIconBox] bersama dari misc_widgets.dart.

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
          // Label section sama persis dengan yang dipakai di Home &
          // form laporan — biar konsisten satu aplikasi.
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

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: SoftIconBox(
        icon: icon,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: cs.primary)
          : Icon(Icons.circle_outlined,
          color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
      onTap: onTap,
    );
  }
}