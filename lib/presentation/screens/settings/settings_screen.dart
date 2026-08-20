import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/theme_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../about/about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // CustomScrollView + SliverAppBar pinned: judul "menempel" di atas dan
      // list section di bawahnya scroll lewat di belakangnya (dapat shadow
      // tipis via scrolledUnderElevation), bukan AppBar polos seperti biasa.
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.10),
            toolbarHeight: 82,
            titleSpacing: 20,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ukuran & bobot disamakan dengan header Statistik/Laporan.
                Text(
                  'Pengaturan',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kelola tampilan & data aplikasi',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
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
                      leading: _IconBox(
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
                      leading: _IconBox(
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

/// Kotak ikon bertinta lembut — dipakai konsisten di semua leading icon
/// list tile pengaturan, senada dengan gaya CategoryTile/StatItem di Home.
class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

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
      leading: _IconBox(
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
