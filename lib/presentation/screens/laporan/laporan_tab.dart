import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/week_utils.dart';
import '../../../data/models/folder.dart';
import '../../../providers/records_provider.dart';
import '../../../providers/folders_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/santri_report_card.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/filter_sheet.dart';
import 'open_week_action.dart';
import '../folder/folder_detail_screen.dart';
import '../folder/folder_form_sheet.dart';
import '../folder/move_to_folder_sheet.dart';
import '../folder/orphaned_records_screen.dart';
import 'search_results_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Tab "Laporan" — pencarian, filter, section Folder, dan daftar kartu
/// santri
class LaporanTab extends StatefulWidget {
  final ValueChanged<bool>? onSelectionModeChanged;
  final ValueChanged<bool>? onFabVisibilityChanged;
  const LaporanTab({super.key, this.onSelectionModeChanged, this.onFabVisibilityChanged});

  @override
  State<LaporanTab> createState() => _LaporanTabState();
}

class _LaporanTabState extends State<LaporanTab> {
  final _searchCtrl = TextEditingController();

  // Mode pilih-banyak (centang)
  bool _selectionMode = false;
  final Set<String> _selected = {};

  // Accordion panel info pekan LINTAS-KARTU
  String? _expandedCardId;
  int? _expandedWeek;

  void _toggleCardWeek(String identityKey, int weekIndex) {
    setState(() {
      if (_expandedCardId == identityKey && _expandedWeek == weekIndex) {
        _expandedCardId = null;
        _expandedWeek = null;
      } else {
        _expandedCardId = identityKey;
        _expandedWeek = weekIndex;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selected.clear();
      _expandedCardId = null;
      _expandedWeek = null;
    });
    widget.onSelectionModeChanged?.call(_selectionMode);
  }

  void _startSelectingWith(String identityKey) {
    setState(() {
      _selectionMode = true;
      _selected.add(identityKey);
      _expandedCardId = null;
      _expandedWeek = null;
    });
    widget.onSelectionModeChanged?.call(true);
  }

  void _toggleSelect(String identityKey) {
    setState(() {
      _selected.contains(identityKey) ? _selected.remove(identityKey) : _selected.add(identityKey);
    });
  }

  void _setSelectAll(bool select, List<SantriCardInfo> cards) {
    setState(() {
      if (select) {
        _selected
          ..clear()
          ..addAll(cards.map((c) => c.identityKey));
      } else {
        _selected.clear();
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
    widget.onSelectionModeChanged?.call(false);
  }

  /// Jaga-jaga kartu yang lagi kecentang tiba-tiba "hilang" dari daftar ini
  /// (mis. baru saja di-drag/drop ke [FolderCard]
  void _autoCloseSelectionIfCardsGone(List<SantriCardInfo> cards) {
    if (!_selectionMode || _selected.isEmpty) return;
    final visibleKeys = cards.map((c) => c.identityKey).toSet();
    final masihAdaYangKeliatan = _selected.any(visibleKeys.contains);
    if (masihAdaYangKeliatan) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || !_selectionMode) return;
      _exitSelectionMode();
    });
  }

  Future<void> _hapusSelected() async {
    final provider = context.read<RecordsProvider>();
    final count = _selected.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $count kartu?'),
        content: const Text(
            'Semua laporan pekanan di dalamnya ikut terhapus. Data yang dihapus tidak dapat dikembalikan.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              for (final key in _selected.toList()) {
                final c = provider.cardByIdentityKey(key);
                if (c != null) await provider.deleteAllForSantri(c.nama, c.identityKey);
                if (!context.mounted) return;
              }
              _exitSelectionMode();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _pindahkanSelected() async {
    final provider = context.read<RecordsProvider>();
    final keys = _selected.toList();
    final itemCount = keys.fold<int>(0, (sum, key) {
      final c = provider.cardByIdentityKey(key);
      if (c == null) return sum;
      return sum + (c.hasAnyReport ? provider.recordsForSantri(c.nama).length : 1);
    });
    final target = await showFolderPickerSheet(context, itemCount: itemCount);
    if (target == null) return;
    if (!context.mounted) return;
    final count = keys.length;
    for (final key in keys) {
      final c = provider.cardByIdentityKey(key);
      if (c != null) await provider.moveIdentityToFolder(c, target.isEmpty ? null : target);
      if (!context.mounted) return;
    }
    if (!context.mounted) return;
    final ctx = context;
    _exitSelectionMode();
    showAppSnackbar(
      ctx,
      '$count kartu dipindahkan.',
      icon: LucideIcons.folderInput,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  /// Predikat pencocokan search + filter kelas/halaqoh/status/keterangan/
  /// tanggal untuk SATU kartu — dipisah dari [_filteredCards] supaya bisa
  /// dipakai ulang buat menghitung berapa kartu di DALAM sebuah folder
  /// yang cocok filter aktif (lihat [_matchingCountInFolder]), tanpa
  /// duplikat logic-nya.
  bool _cardMatchesFilters(
      SantriCardInfo c, RecordsProvider provider, DateTime thisMonth, String q) {
    if (q.isNotEmpty && !c.nama.toLowerCase().contains(q)) return false;
    if (provider.filterKelas != null && c.kelas != provider.filterKelas) return false;
    if (provider.filterHalaqoh != null && c.halaqoh != provider.filterHalaqoh) return false;
    if (provider.filterStatus != null ||
        provider.filterKeterangan != null ||
        provider.filterDate != null) {
      final recs = provider.recordsInMonth(thisMonth).where(
              (r) => r.namaAnak.trim().toLowerCase() == c.nama.trim().toLowerCase());
      final matches = recs.any((r) =>
      (provider.filterStatus == null || r.status == provider.filterStatus) &&
          (provider.filterKeterangan == null || r.keterangan == provider.filterKeterangan) &&
          (provider.filterDate == null ||
              (r.tanggal.year == provider.filterDate!.year &&
                  r.tanggal.month == provider.filterDate!.month &&
                  r.tanggal.day == provider.filterDate!.day)));
      if (!matches) return false;
    }
    return true;
  }

  /// Kartu santri yang cocok dengan pencarian & filter kelas/halaqoh aktif
  /// (dipakai bersama dengan Bottom Sheet Filter yang sudah ada).
  List<SantriCardInfo> _filteredCards(RecordsProvider provider) {
    final q = provider.searchQuery.trim().toLowerCase();
    final thisMonth = WeekUtils.ownerMonth(DateTime.now());
    return provider.laporanCards.where((c) {
      if (c.currentFolderId != null) return false;
      return _cardMatchesFilters(c, provider, thisMonth, q);
    }).toList();
  }

  /// Jumlah kartu DI DALAM folder [folderId] yang cocok filter/pencarian
  /// aktif saat ini — dipakai buat badge di [FolderCard] (lihat
  /// [_buildFolderSection]), supaya kartu yang "nyangkut" di dalam folder
  /// (dan karena itu tidak ikut ditampilkan sebagai kartu lepas oleh
  /// [_filteredCards]) tetap kelihatan ketauan ada yang cocok, tanpa harus
  /// membuka folder itu satu-satu.
  int _matchingCountInFolder(String folderId, RecordsProvider provider) {
    // Null kalau tidak ada filter/pencarian aktif sama sekali -- badge-nya
    // sengaja TIDAK ditampilkan dalam kondisi ini (lihat _buildFolderSection),
    // jadi hitungannya juga tidak perlu dikerjakan.
    if (!provider.hasActiveFilters) return 0;
    final q = provider.searchQuery.trim().toLowerCase();
    final thisMonth = WeekUtils.ownerMonth(DateTime.now());
    return provider.laporanCards
        .where((c) => c.currentFolderId == folderId)
        .where((c) => _cardMatchesFilters(c, provider, thisMonth, q))
        .length;
  }

  /// Buka form laporan untuk pekan [weekIndex] (dalam bulan berjalan) milik
  /// santri [card]
  void _openWeek(BuildContext context, SantriCardInfo card, int weekIndex) {
    openWeekForSantri(context, card, weekIndex, initialFolderId: card.emptyCardFolderId);
  }

  /// Pindahkan kartu [card] ke folder pilihan user
  Future<void> _pindahkanCard(BuildContext context, SantriCardInfo card,
      {String? langsungKeFolderId}) async {
    final provider = context.read<RecordsProvider>();
    final target = langsungKeFolderId ??
        await showFolderPickerSheet(
          context,
          itemCount: card.hasAnyReport ? provider.recordsForSantri(card.nama).length : 1,
        );
    if (target == null) return;
    if (!context.mounted) return;
    await provider.moveIdentityToFolder(card, target.isEmpty ? null : target);
    if (!context.mounted) return;
    showAppSnackbar(
      context,
      'Kartu "${card.nama}" dipindahkan.',
      icon: LucideIcons.folderInput,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  /// Hapus kartu [card] dari daftar kartu di sini.
  void _hapusCard(BuildContext context, SantriCardInfo card) {
    final hasReports = card.hasAnyReport;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasReports ? 'Hapus kartu "${card.nama}"?' : 'Hapus kartu ini?'),
        content: Text(
          hasReports
              ? 'Semua laporan pekanan santri ini akan ikut terhapus. Data yang dihapus tidak dapat dikembalikan.'
              : 'Belum ada laporan yang tersimpan untuk santri ini.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RecordsProvider>().deleteAllForSantri(card.nama, card.identityKey);
              showAppSnackbar(
                context,
                'Kartu "${card.nama}" dihapus.',
                icon: LucideIcons.trash2,
                onFabVisibilityChanged: widget.onFabVisibilityChanged,
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final foldersProvider = context.watch<FoldersProvider>();
    final cards = _filteredCards(provider);
    final folders = foldersProvider.all;
    final orphanedCount =
        provider.orphanedFolderCards(folders.map((f) => f.id).toSet()).length;

    _autoCloseSelectionIfCardsGone(cards);

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
                  toolbarHeight: 84,
                  titleSpacing: 20,
                  title: _buildTitle(context),
                  actions: cards.isEmpty
                      ? null
                      : [
                    IconButton(
                      onPressed: _toggleSelectionMode,
                      icon: Icon(
                        _selectionMode ? LucideIcons.circleX : LucideIcons.listChecks,
                      ),
                      tooltip: _selectionMode ? 'Batal pilih' : 'Pilih beberapa kartu',
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(76),
                    child: _buildSearchAndFilter(context, provider),
                  ),
                ),
                if (orphanedCount > 0)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _OrphanedRecordsBanner(
                        count: orphanedCount,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrphanedRecordsScreen(
                              onFabVisibilityChanged: widget.onFabVisibilityChanged,
                            ),
                          ),
                        ),
                      ),
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
                if (cards.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 24),
                    sliver: SliverToBoxAdapter(
                      child: EmptyState(
                        icon: provider.hasActiveFilters
                            ? LucideIcons.search
                            : LucideIcons.bookOpen,
                        title: provider.hasActiveFilters
                            ? 'Data tidak ditemukan'
                            : 'Belum ada laporan',
                        subtitle: provider.hasActiveFilters
                            ? 'Coba ubah kata kunci atau filter pencarian.'
                            : null,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, _selectionMode ? 110 : 100),
                    sliver: SliverList.separated(
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final c = cards[i];
                        return SantriReportCard(
                          info: c,
                          onTapWeek: (weekIndex) => _openWeek(context, c, weekIndex),
                          onPindahkanKeFolder: () => _pindahkanCard(context, c),
                          onHapus: () => _hapusCard(context, c),
                          selectionMode: _selectionMode,
                          selected: _selected.contains(c.identityKey),
                          onSelectToggle: () => _toggleSelect(c.identityKey),
                          selectedIds: _selected.toList(),
                          onLongPressStartSelect: () => _startSelectingWith(c.identityKey),
                          expandedWeek: _expandedCardId == c.identityKey ? _expandedWeek : null,
                          onToggleWeek: (weekIndex) => _toggleCardWeek(c.identityKey, weekIndex),
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
                totalCount: cards.length,
                onSelectAllChanged: (v) => _setSelectAll(v, cards),
                onCancel: _toggleSelectionMode,
                actions: [
                  SelectionAction(
                    icon: LucideIcons.trash2,
                    label: 'Hapus',
                    onTap: _selected.isEmpty ? null : _hapusSelected,
                    destructive: true,
                  ),
                  SelectionAction(
                    icon: LucideIcons.folderInput,
                    label: 'Pindahkan',
                    onTap: _selected.isEmpty ? null : _pindahkanSelected,
                    filled: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
                    matchingFilterCount: _matchingCountInFolder(f.id, provider),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FolderDetailScreen(
                          folderId: f.id,
                          onFabVisibilityChanged: widget.onFabVisibilityChanged,
                        ),
                      ),
                    ),
                    onRename: () => showFolderFormSheet(context, existing: f),
                    onDelete: () => _confirmDeleteFolder(context, f.id),
                    // Drop hasil drag SantriReportCard
                    onDropRecord: (identityKeys) async {
                      for (final key in identityKeys) {
                        if (!context.mounted) return;
                        final c = provider.cardByIdentityKey(key);
                        if (c != null) await _pindahkanCard(context, c, langsungKeFolderId: f.id);
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


  Widget _buildTitle(BuildContext context) {
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
            'Kelola kartu laporan hafalan santri',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Bug fix: dulu ada halaman "Hasil Pencarian" ([SearchResultsScreen])
  /// yang nyari ke SEMUA kartu santri.
  void _openSearchResults(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchResultsScreen()),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context, RecordsProvider provider) {
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
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama santri...',
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

  void _confirmDeleteFolder(BuildContext context, String folderId) {
    final recordsProvider = context.read<RecordsProvider>();
    final jumlahSantri = recordsProvider.countInFolder(folderId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus folder?'),
        content: Text(
          jumlahSantri > 0
              ? 'Folder ini berisi laporan $jumlahSantri santri. Semua laporan di '
                  'dalamnya akan ikut TERHAPUS PERMANEN dan tidak bisa dikembalikan.'
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
}
/// Banner peringatan yang tampil di tab Laporan begitu ada kartu santri
/// yang folder tujuannya sudah tidak ada lagi (lihat
/// [RecordsProvider.orphanedFolderCards] dan [OrphanedRecordsScreen]).
class _OrphanedRecordsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _OrphanedRecordsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SoftIconBox(icon: LucideIcons.folderMinus, color: cs.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count kartu folder-nya hilang',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: cs.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Laporannya masih aman. Tekan untuk pindahkan ke folder lain.',
                      style: TextStyle(fontSize: 11.5, color: cs.onErrorContainer.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: cs.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
