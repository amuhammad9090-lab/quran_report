import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Header pinned seragam untuk halaman non-Home yang dibuka lewat push
/// (Daftar Santri, Detail Santri, Kehadiran, Rekap Bulanan): tombol kembali +
/// judul + subjudul opsional, senada SliverAppBar pinned di Home.
class PushedPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double titleFontSize;

  const PushedPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleFontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10,
      ),
      toolbarHeight: subtitle != null ? 68 : 56,
      titleSpacing: 4,
      title: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
