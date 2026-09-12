import 'package:flutter/material.dart';

import '../../data/models/folder.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Kartu folder di section "Folder" pada tab Laporan.
/// - Tap → buka halaman isi folder.
/// - Tekan lama (hold) → menu Ubah Nama / Hapus.
/// - Jadi [DragTarget] — kalau ada SantriReportCard yang di-drag
///   (identityKey santri) dilepas di atas kartu ini, kartu itu dipindah
///   ke folder ini.
class FolderCard extends StatelessWidget {
  final ReportFolder folder;
  final int recordCount;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(List<String> recordIds)? onDropRecord;

  /// Jumlah kartu DI DALAM folder ini yang cocok filter/pencarian aktif
  /// (0/null kalau tidak ada filter aktif, atau tidak ada yang cocok) —
  /// dipakai buat badge kecil di pojok kartu. Filter kategori (Tahfizh/
  /// Tahsin/dll) di tab Laporan sengaja TIDAK meng-auto-expand isi folder
  /// (lihat `LaporanTab._filteredCards`), jadi tanpa badge ini, santri
  /// yang cocok filter tapi kartunya "nyangkut" di dalam folder jadi
  /// nggak kelihatan sama sekali sampai foldernya dibuka manual. Badge ini
  /// cuma penanda "ada yang cocok di dalam" — buka folder tetap wajib
  /// buat lihat detailnya (BUKAN auto-expand).
  final int matchingFilterCount;

  const FolderCard({
    super.key,
    required this.folder,
    required this.recordCount,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    this.onDropRecord,
    this.matchingFilterCount = 0,
  });

  void _showActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          // Container ini SEKARANG cuma buat `margin` — background+rounded
          // corner dipindah ke Material di dalamnya, biar ListTile "Ubah
          // Nama"/"Hapus Folder" di bawah punya Material terdekat yang
          // benar, nggak ketutup DecoratedBox (lihat assertion "ListTile
          // background color or ink splashes may be invisible").
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: Theme.of(ctx).bottomSheetTheme.backgroundColor,
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                  child: Row(
                    children: [
                      Icon(LucideIcons.folder, color: cs.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          folder.nama,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 18, indent: 18, endIndent: 18),
                ListTile(
                  leading: Icon(LucideIcons.squarePen, color: cs.primary),
                  title: const Text('Ubah Nama', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onRename();
                  },
                ),
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: cs.error),
                  title: Text('Hapus Folder',
                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) => onDropRecord != null,
      onAcceptWithDetails: (details) => onDropRecord?.call(details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedScale(
          scale: hovering ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Card(
                color: hovering ? cs.secondaryContainer.withValues(alpha: 0.6) : null,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: () => _showActions(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.secondary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(LucideIcons.folder, color: cs.secondary, size: 22),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          folder.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$recordCount santri',
                          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Badge "ada yang cocok filter di dalam" — cuma nongol kalau
              // filter/pencarian lagi aktif DAN memang ada yang match.
              // Sengaja tidak nge-auto-buka folder-nya, cuma penanda; buka
              // folder tetap wajib buat lihat siapa aja yang cocok.
              if (matchingFilterCount > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Tooltip(
                    message:
                        '$matchingFilterCount santri di folder ini cocok filter aktif',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      constraints: const BoxConstraints(minWidth: 20),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(context).cardTheme.color ??
                              Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '$matchingFilterCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: cs.onPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
