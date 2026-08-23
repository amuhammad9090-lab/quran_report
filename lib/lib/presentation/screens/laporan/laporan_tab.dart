import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/folder.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import '../../../providers/folders_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/record_card.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/filter_sheet.dart';
import '../record_form/record_form_sheet.dart';
import '../folder/folder_detail_screen.dart';
import '../folder/folder_form_sheet.dart';
import '../folder/move_to_folder_sheet.dart';
import 'search_results_screen.dart';

/// Tab "Laporan" — pencarian, filter, section Folder, dan daftar laporan
/// (yang belum masuk folder mana pun) santri.
class LaporanTab extends StatefulWidget {
  final ValueChanged<bool>? onSelectionModeChanged;
  final ValueChanged<bool>? onFabVisibilityChanged;
  const LaporanTab({super.key, this.onSelectionModeChanged, this.onFabVisibilityChanged});

  @override
  State<LaporanTab> createState() => _LaporanTabState();
}

class _LaporanTabState extends State<LaporanTab> {
  final _searchCtrl = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selected.clear();
    });
    widget.onSelectionModeChanged?.call(_selectionMode);
  }

  /// Dipicu dari tahan-lama kartu (saat belum mode pilih) — langsung
  /// masuk mode pilih-banyak DAN centang kartu yang ditahan itu.
  void _startSelectingWith(String recordId) {
    setState(() {
      _selectionMode = true;
      _selected.add(recordId);
    });
    widget.onSelectionModeChanged?.call(true);
  }

  void _toggleSelect(String id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  Future<void> _moveSelected() async {
    final result = await showFolderPickerSheet(context, itemCount: _selected.length);
    if (result == null || !mounted) return;
    final provider = context.read<RecordsProvider>();
    final count = _selected.length;
    await provider.moveManyToFolder(_selected, result.isEmpty ? null : result);
    if (!mounted) return;
    _exitSelectionMode();
    _showMovedSnackBar(count);
  }

  /// Dipicu saat kartu (atau beberapa kartu kecentang sekaligus) di-drag
  /// lalu dilepas ke atas sebuah folder.
  Future<void> _dropRecordsToFolder(List<String> ids, ReportFolder folder) async {
    final provider = context.read<RecordsProvider>();
    await provider.moveManyToFolder(ids, folder.id);
    if (!mounted) return;
    if (_selectionMode) _exitSelectionMode();
    _showMovedSnackBar(ids.length, folderName: folder.nama);
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
    widget.onSelectionModeChanged?.call(false);
  }

  void _showMovedSnackBar(int count, {String? folderName}) {
    showAppSnackbar(
      context,
      folderName != null
          ? '$count laporan dipindahkan ke "$folderName"'
          : '$count laporan dipindahkan',
      icon: Icons.drive_file_move_outline,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  void _setSelectAll(bool select, List<SantriRecord> records) {
    setState(() {
      if (select) {
        _selected
          ..clear()
          ..addAll(records.map((r) => r.id));
      } else {
        _selected.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final foldersProvider = context.watch<FoldersProvider>();
    final records = provider.filteredRoot;
    final folders = foldersProvider.all;
    final matchesInFolders = provider.searchQuery.isEmpty
        ? 0
        : provider.filtered.where((r) => r.folderId != null).length;

    if (_searchCtrl.text != provider.searchQuery) {
      _searchCtrl.value = _searchCtrl.value.copyWith(
        text: provider.searchQuery,
        selection: TextSelection.collapsed(offset: provider.searchQuery.length),
      );
    }

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: provider.load,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  toolbarHeight: 68,
                  titleSpacing: 20,
                  title: _buildTitle(context),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(76),
                    child: _buildSearchAndFilter(context, provider),
                  ),
                ),
                if (matchesInFolders > 0)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildSearchAllFoldersBanner(context, matchesInFolders),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: _buildFolderSection(context, folders, provider),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(child: SectionLabel('Laporan')),
                ),
                if (records.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 24),
                    sliver: SliverToBoxAdapter(
                      child: EmptyState(
                        icon: provider.hasActiveFilters
                            ? Icons.search_off_rounded
                            : Icons.auto_stories_rounded,
                        title: provider.hasActiveFilters
                            ? 'Data tidak ditemukan'
                            : 'Belum ada laporan',
                        subtitle: provider.hasActiveFilters
                            ? 'Coba ubah kata kunci atau filter pencarian.'
                            : 'Tambahkan laporan capaian hafalan atau tahsin santri pertama.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, _selectionMode ? 110 : 100),
                    sliver: SliverList.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final r = records[i];
                        return RecordCard(
                          record: r,
                          onEdit: () => showRecordFormSheet(context, existing: r),
                          onDelete: () => _confirmDelete(context, r.id),
                          onPindahkanKeFolder: () => _moveSingle(context, r.id),
                          selectionMode: _selectionMode,
                          selected: _selected.contains(r.id),
                          onSelectToggle: () => _toggleSelect(r.id),
                          selectedIds: _selected.toList(),
                          onLongPressStartSelect: () => _startSelectingWith(r.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_selectionMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SelectionActionBar(
                selectedCount: _selected.length,
                totalCount: records.length,
                onSelectAllChanged: (v) => _setSelectAll(v, records),
                onCancel: _toggleSelectionMode,
                actions: [
                  SelectionAction(
                    icon: Icons.drive_file_move_outline,
                    label: 'Pindahkan',
                    onTap: _selected.isEmpty ? null : _moveSelected,
                    filled: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _moveSingle(BuildContext context, String recordId) async {
    final provider = context.read<RecordsProvider>();
    final result = await showFolderPickerSheet(context);
    if (result == null || !context.mounted) return;
    await provider.moveToFolder(recordId, result.isEmpty ? null : result);
  }

  Widget _buildFolderSection(
      BuildContext context, List<ReportFolder> folders, RecordsProvider provider) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Folder',
          trailing: IconButton(
            onPressed: () => showFolderFormSheet(context),
            icon: const Icon(Icons.add_rounded, size: 20),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => FolderDetailScreen(folderId: f.id)),
                    ),
                    onRename: () => showFolderFormSheet(context, existing: f),
                    onDelete: () => _confirmDeleteFolder(context, f.id),
                    onDropRecord: (ids) => _dropRecordsToFolder(ids, f),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }


  Widget _buildSearchAllFoldersBanner(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchResultsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.travel_explore_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count laporan lagi cocok di dalam folder',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: cs.primary),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
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
          'Rekap capaian tahsin & tahfizh santri',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter(BuildContext context, RecordsProvider provider) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: provider.setSearch,
              decoration: InputDecoration(
                hintText: 'Cari nama santri...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    provider.setSearch('');
                  },
                )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton.filledTonal(
                onPressed: () => showFilterSheet(context),
                icon: const Icon(Icons.tune_rounded),
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

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus laporan?'),
        content: const Text('Data yang dihapus tidak dapat dikembalikan.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              context.read<RecordsProvider>().delete(id);
              Navigator.pop(ctx);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, String folderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus folder?'),
        content: const Text('Laporan di dalamnya tidak ikut terhapus, hanya dikeluarkan dari folder.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              context.read<FoldersProvider>().delete(folderId);
              Navigator.pop(ctx);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}