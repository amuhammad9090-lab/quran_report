// Bagian-bagian tampilan tab Laporan: judul, kolom cari + filter, dan section Folder.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../data/models/folder.dart';
import '../../../providers/folders_provider.dart';
import '../../../providers/records_provider.dart';
import '../../sheets/filter/filter_sheet.dart';
import '../../sheets/folder/folder_form_sheet.dart';
import '../../widgets/common/section_label.dart';
import '../../widgets/folder_card.dart';
import '../folder/folder_detail_screen.dart';
import 'laporan_filters.dart';
import 'search_results_screen.dart';

class LaporanTitle extends StatelessWidget {
  const LaporanTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Laporan',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            'Kelola kartu laporan hafalan siswa',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class LaporanSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final RecordsProvider provider;
  const LaporanSearchBar({super.key, required this.controller, required this.provider});

  /// Bug fix: dulu ada halaman "Hasil Pencarian" ([SearchResultsScreen])
  /// yang nyari ke SEMUA kartu santri.
  void _openSearchResults(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchResultsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            // Bug fix: field ini sebelumnya TextField biasa yang langsung
            // bisa diketik di tempat.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSearchResults(context),
              child: AbsorbPointer(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama siswa...',
                    prefixIcon: Icon(LucideIcons.search),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton.filledTonal(
                onPressed: () => showFilterSheet(context),
                icon: const Icon(LucideIcons.slidersHorizontal),
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                ),
              ),
              if (provider.hasActiveFilters)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class LaporanFolderSection extends StatelessWidget {
  final List<ReportFolder> folders;
  final RecordsProvider provider;
  final ValueChanged<bool>? onFabVisibilityChanged;
  final Future<void> Function(BuildContext context, SantriCardInfo card, String folderId) onMoveCard;
  const LaporanFolderSection({
    super.key,
    required this.folders,
    required this.provider,
    required this.onMoveCard,
    this.onFabVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Folder',
          trailing: IconButton(
            onPressed: () => showFolderFormSheet(context),
            icon: const Icon(LucideIcons.circlePlus, size: 20),
            tooltip: 'Buat folder',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),
        if (folders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Belum ada folder',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
              ),
            ),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: folders.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final f = folders[i];
                return SizedBox(
                  width: 130,
                  child: FolderCard(
                    folder: f,
                    recordCount: provider.countInFolder(f.id),
                    matchingFilterCount: matchingCountInFolder(f.id, provider),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FolderDetailScreen(
                          folderId: f.id,
                          onFabVisibilityChanged: onFabVisibilityChanged,
                        ),
                      ),
                    ),
                    onRename: () => showFolderFormSheet(context, existing: f),
                    onDelete: () => confirmDeleteFolder(context, f.id),
                    // Drop hasil drag SantriReportCard
                    onDropRecord: (identityKeys) async {
                      for (final key in identityKeys) {
                        if (!context.mounted) return;
                        final c = provider.cardByIdentityKey(key);
                        if (c != null) await onMoveCard(context, c, f.id);
                      }
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

void confirmDeleteFolder(BuildContext context, String folderId) {
  final recordsProvider = context.read<RecordsProvider>();
  final jumlahSantri = recordsProvider.countInFolder(folderId);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus folder?'),
      content: Text(
        jumlahSantri > 0
            ? 'Folder berisi laporan $jumlahSantri siswa. Semuanya '
                'akan terhapus permanen dan tidak bisa dikembalikan.'
            : 'Folder ini kosong dan akan dihapus.',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () async {
            await recordsProvider.deleteAllInFolder(folderId);
            if (!ctx.mounted) return;
            await context.read<FoldersProvider>().delete(folderId);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
}
