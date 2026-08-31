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
import '../record_form/record_form_sheet.dart';
import '../folder/folder_detail_screen.dart';
import '../folder/folder_form_sheet.dart';
import '../folder/move_to_folder_sheet.dart';
import 'search_results_screen.dart';

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

  // Accordion panel info pekan LINTAS-KARTU — cuma 1 (identityKey +
  // weekIndex) yang boleh expand sekaligus di SELURUH daftar santri.
  // Sebelumnya expand-state disimpen sendiri2 di tiap SantriReportCard,
  // jadi bisa kebuka bareng di banyak kartu santri berbeda; sekarang
  // dinaikin ke sini biar buka panel di 1 santri otomatis nutup punya
  // santri lain (sama pola kayak accordion Pekan di Rekap Bulanan).
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
    _exitSelectionMode();
    showAppSnackbar(
      context,
      '$count kartu dipindahkan.',
      icon: Icons.drive_file_move_outline,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  /// Kartu santri yang cocok dengan pencarian & filter kelas/halaqoh aktif
  /// (dipakai bersama dengan Bottom Sheet Filter yang sudah ada).
  List<SantriCardInfo> _filteredCards(RecordsProvider provider) {
    final q = provider.searchQuery.trim().toLowerCase();
    // BUG FIX: dulu kalender murni — beda definisi "bulan ini" sama
    // recordsInMonth() (yang sekarang berbasis kepemilikan pekan), jadi
    // filter status/keterangan bisa salah nge-cover laporan di 1-2 hari
    // ujung bulan. Disamain ke WeekUtils.ownerMonth kayak di tempat lain.
    final thisMonth = WeekUtils.ownerMonth(DateTime.now());
    return provider.laporanCards.where((c) {
      if (c.currentFolderId != null) return false;
      if (q.isNotEmpty && !c.nama.toLowerCase().contains(q)) return false;
      if (provider.filterKelas != null && c.kelas != provider.filterKelas) return false;
      if (provider.filterHalaqoh != null && c.halaqoh != provider.filterHalaqoh) return false;
      if (provider.filterStatus != null || provider.filterKeterangan != null) {
        final recs = provider.recordsInMonth(thisMonth).where(
                (r) => r.namaAnak.trim().toLowerCase() == c.nama.trim().toLowerCase());
        final matches = recs.any((r) =>
        (provider.filterStatus == null || r.status == provider.filterStatus) &&
            (provider.filterKeterangan == null || r.keterangan == provider.filterKeterangan));
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  /// Buka form laporan untuk pekan [weekIndex] (dalam bulan berjalan) milik
  /// santri [card]
  void _openWeek(BuildContext context, SantriCardInfo card, int weekIndex) {
    final provider = context.read<RecordsProvider>();
    final now = DateTime.now();
    final thisMonth = WeekUtils.ownerMonth(now);
    final currentWeek = WeekUtils.weekOfMonth(now);

    final range = WeekUtils.monthWeekRange(thisMonth, weekIndex);
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentWeek = weekIndex == currentWeek &&
        !today.isBefore(range.start) &&
        !today.isAfter(range.end);
    final presetDate = isCurrentWeek ? today : range.start;

    // Dicek per-HARI PERSIS (presetDate), baik pekan berjalan MAUPUN
    // pekan yang sudah lewat — konsisten dengan Rekap Harian yang juga
    // per-hari. Sebelumnya pekan lewat dicek per-PEKAN (ambil laporan
    // TERBARU di pekan itu buat dibuka sebagai edit), tapi itu logic
    // yang sama persis yang bikin laporan Senin ke-timpa/pindah tanggal
    // waktu guru sebenarnya mau isi hari lain di pekan yang sama (lihat
    // catatan lengkap di RecordsProvider.recordForSantriOnDate) — cuma
    // dulu cuma dibenerin buat pekan berjalan, sekarang berlaku di semua
    // pekan. Efeknya: tap kartu pekan LAMA sekarang default ngarah ke
    // hari Senin pekan itu (range.start) — buat lihat/isi hari lain yang
    // spesifik di pekan lama, lewat Rekap Harian (tap hari itu di Rekap
    // Pekan), bukan dari tombol kartu pekan ini.
    final existing = provider.recordForSantriOnDate(card.nama, presetDate);
    if (existing != null) {
      // lockIdentity: true -> samain kek buka form laporan baru dari kartu
      // santri ini (section "Identitas Santri" ikut disembunyikan, karena
      // identitasnya sudah jelas dari konteks kartu yang di-tap).
      showRecordFormSheet(context, existing: existing, lockIdentity: true);
      return;
    }

    showRecordFormSheet(
      context,
      presetKelas: card.kelas,
      presetHalaqoh: card.halaqoh,
      presetNama: card.nama,
      presetTanggal: presetDate,
      lockIdentity: true,
      initialFolderId: card.emptyCardFolderId,
    );
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
      icon: Icons.drive_file_move_outline,
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
                icon: Icons.delete_outline_rounded,
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
                  toolbarHeight: 68,
                  titleSpacing: 20,
                  title: _buildTitle(context),
                  actions: cards.isEmpty
                      ? null
                      : [
                    IconButton(
                      onPressed: _toggleSelectionMode,
                      icon: Icon(
                        _selectionMode ? Icons.close_rounded : Icons.checklist_rounded,
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
                            ? Icons.search_off_rounded
                            : Icons.auto_stories_rounded,
                        title: provider.hasActiveFilters
                            ? 'Data tidak ditemukan'
                            : 'Belum ada laporan',
                        subtitle: provider.hasActiveFilters
                            ? 'Coba ubah kata kunci atau filter pencarian.'
                            : 'Tekan tombol "+" lalu "Buat Laporan" untuk santri pertama.',
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
                    icon: Icons.delete_outline_rounded,
                    label: 'Hapus',
                    onTap: _selected.isEmpty ? null : _hapusSelected,
                    destructive: true,
                  ),
                  SelectionAction(
                    icon: Icons.drive_file_move_outline,
                    // Sebelumnya 'Pindahkan ke Folder' -> kepanjangan buat
                    // Expanded selebar setengah bar di layar HP (apalagi
                    // berdampingan sama tombol "Hapus"), jadinya numpuk 2
                    // baris / kepotong nggak rapi. Dipendekin, konsisten
                    // sama gaya label singkat tombol "Hapus" di sebelahnya.
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

  /// Bug fix: dulu ada halaman "Hasil Pencarian" ([SearchResultsScreen])
  /// yang nyari ke SEMUA kartu santri termasuk yang sudah masuk folder
  /// (bukan cuma yang tanpa folder kayak list di tab ini) -- tapi nggak ada
  /// satupun tempat yang manggil halaman itu lagi, jadi fiturnya
  /// "hilang" dari user meskipun kodenya masih ada. Sekalian ngebenerin
  /// itu: field pencarian di tab ini sekarang jadi pintu masuk ke sana.
  void _openSearchResults(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchResultsScreen()),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context, RecordsProvider provider) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Expanded(
            // Bug fix: field ini sebelumnya TextField biasa yang langsung
            // bisa diketik di tempat -- pas di-tap, dia dapet fokus &
            // nampilin kursor, tapi ketikannya cuma nyaring kartu yang
            // TANPA folder (lihat _filteredCards di atas), jadi hasil
            // pencarian yang ada di dalam folder nggak pernah kelihatan
            // dari sini, dan kursornya nggak pernah "ilang" karena field-nya
            // emang tetap fokus/aktif nungguin ketikan lanjutan.
            // Sekarang field ini cuma TAMPILAN (AbsorbPointer -- nggak bisa
            // difokus/diketik, jadi nggak akan pernah nampilin kursor sama
            // sekali), tap di mana aja langsung buka SearchResultsScreen,
            // yang punya field pencarian sungguhan (bisa diketik & ada
            // kursor di sana) DAN nyari sampai ke dalam folder.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSearchResults(context),
              child: AbsorbPointer(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama santri...',
                    prefixIcon: Icon(Icons.search_rounded),
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