import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../providers/folders_provider.dart';
import '../../../providers/records_provider.dart';
import '../../sheets/folder/move_to_folder_sheet.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/motion_widgets.dart';
import '../../widgets/common/section_label.dart';
import '../../widgets/common/selection_action_bar.dart';
import '../../widgets/santri_report_card.dart';
import '../folder/orphaned_records_screen.dart';
import 'laporan_banners.dart';
import 'laporan_filters.dart';
import 'laporan_sections.dart';
import 'open_week_action.dart';

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
            'Semua laporan di dalamnya ikut terhapus dan tidak bisa dikembalikan.'),
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
              ? 'Semua laporan siswa ini ikut terhapus dan tidak bisa dikembalikan.'
              : 'Belum ada laporan yang tersimpan untuk siswa ini.',
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
    final cards = filteredCards(provider);
    // <-- BARU: folder di-scope pakai AccessScope yang sama dengan santri
    // record (RecordsProvider.scope) -- mode guru cuma lihat folder
    // buatannya sendiri, mode admin lihat semua. Kalau scope belum ada
    // (mis. sedang restore session) fallback ke semua folder apa adanya.
    final scope = provider.scope;
    final folders = scope == null ? foldersProvider.all : scope.scopeFolders(foldersProvider.all);
    final orphanedCount =
        provider.orphanedFolderCards(folders.map((f) => f.id).toSet()).length;

    _autoCloseSelectionIfCardsGone(cards);

    if (_searchCtrl.text != provider.searchQuery) {
      _searchCtrl.value = _searchCtrl.value.copyWith(
        text: provider.searchQuery,
        selection: TextSelection.collapsed(offset: provider.searchQuery.length),
      );
    }

    // BUG FIX: di web (khususnya PWA di iPhone -- Safari & Chrome iOS
    // sama-sama pakai engine WebKit), RefreshIndicator taruh gesture
    // recognizer drag-vertikal persis di scroll offset 0, yaitu tepat di
    // area kartu/banner pertama di bawah SliverAppBar pinned (mis. banner
    // "folder-nya hilang"). Ini bentrok sama native rubber-band scroll
    // punya WebKit di titik yang sama, jadi tap di elemen paling atas
    // kadang "ditelan" gesture arena-nya dan gak ke-trigger sama sekali.
    // Di app native (Android/iOS) gak kena karena gak ada native page
    // scroll yang ikut berebut. Solusinya: pull-to-refresh cuma aktif di
    // non-web; datanya sendiri sudah auto ke-refresh lewat notifyListeners
    // provider begitu ada perubahan, jadi fitur ini murni kenyamanan tarik
    // manual dan aman dimatikan khusus di web.
    final scrollView = CustomScrollView(
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
                  title: const LaporanTitle(),
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
                    child: LaporanSearchBar(controller: _searchCtrl, provider: provider),
                  ),
                ),
                if (provider.filterDate != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: DateFilterBanner(
                        date: provider.filterDate!,
                        onClear: () => provider.setFilterDate(null),
                      ),
                    ),
                  ),
                if (orphanedCount > 0)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: OrphanedRecordsBanner(
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
                    child: LaporanFolderSection(
                      folders: folders,
                      provider: provider,
                      onFabVisibilityChanged: widget.onFabVisibilityChanged,
                      onMoveCard: (ctx, c, folderId) => _pindahkanCard(ctx, c, langsungKeFolderId: folderId),
                    ),
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
                        return StaggerItem(
                          index: i,
                          child: SantriReportCard(
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
                        ),
                        );
                      },
                    ),
                  ),
              ],
            );

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          kIsWeb
              ? scrollView
              : RefreshIndicator(
                  onRefresh: provider.load,
                  child: scrollView,
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

}

