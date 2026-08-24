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

/// Tab "Laporan" — pencarian, filter, section Folder, dan daftar kartu
/// santri (1 kartu = 1 santri, BUKAN 1 kartu per laporan pekanan lagi —
/// lihat spesifikasi perubahan Laporan & Statistik). Data mingguan tiap
/// santri diakses lewat kartunya (buka Bottom Sheet laporan pekan yang
/// relevan) atau lewat Statistik → Rekap Bulanan → Pekan.
class LaporanTab extends StatefulWidget {
  final ValueChanged<bool>? onSelectionModeChanged;
  final ValueChanged<bool>? onFabVisibilityChanged;
  const LaporanTab({super.key, this.onSelectionModeChanged, this.onFabVisibilityChanged});

  @override
  State<LaporanTab> createState() => _LaporanTabState();
}

class _LaporanTabState extends State<LaporanTab> {
  final _searchCtrl = TextEditingController();

  // Mode pilih-banyak (centang) — pola & implementasi PERSIS sama seperti
  // [FolderDetailScreen] (dulu dipakai [RecordCard] lama juga), lihat
  // catatan lengkap di sana. Bedanya di sini aksi bulk-nya "Hapus" &
  // "Pindahkan ke Folder" (bukan "Keluarkan", karena kartu yang tampil di
  // sini sudah pasti TIDAK sedang di folder mana pun — lihat _filteredCards).
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

  void _startSelectingWith(String identityKey) {
    setState(() {
      _selectionMode = true;
      _selected.add(identityKey);
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
  /// (mis. baru saja di-drag/drop ke [FolderCard] — lihat [_buildFolderSection]
  /// -> [onDropRecord] — bukan lewat tombol "Pindahkan ke Folder" di
  /// [SelectionActionBar] yang sudah nutup mode pilih sendiri). Tanpa ini,
  /// bar pilih nyangkut nongol terus di halaman Laporan walau kartu yang
  /// dipilih sudah pindah rumah ke sebuah folder. Dipanggil tiap build
  /// dengan [cards] TERBARU (hasil filter, yang otomatis nggak lagi memuat
  /// kartu yang sudah masuk folder — lihat _filteredCards). Tutup langsung
  /// tanpa snackbar tambahan — snackbar "kartu dipindahkan" dari
  /// [_pindahkanCard]/[_pindahkanSelected] sudah cukup ngasih tau usernya.
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $count kartu?'),
        content: const Text(
            'Semua laporan pekanan di dalamnya ikut terhapus. Data yang dihapus tidak dapat dikembalikan.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    for (final key in _selected.toList()) {
      final c = provider.cardByIdentityKey(key);
      if (c != null) await provider.deleteAllForSantri(c.nama, c.identityKey);
    }
    if (!context.mounted) return;
    _exitSelectionMode();
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
    if (target == null || !context.mounted) return;
    final count = keys.length;
    for (final key in keys) {
      final c = provider.cardByIdentityKey(key);
      if (c != null) await provider.moveIdentityToFolder(c, target.isEmpty ? null : target);
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
  /// (dipakai bersama dengan Bottom Sheet Filter yang sudah ada). Filter
  /// Status/Keterangan (yang tadinya per-laporan) sekarang diartikan
  /// sebagai "santri yang punya minimal satu laporan bulan ini dengan
  /// status/keterangan tsb" — karena satu kartu di sini mewakili banyak
  /// laporan pekanan sekaligus, bukan satu laporan tunggal.
  List<SantriCardInfo> _filteredCards(RecordsProvider provider) {
    final q = provider.searchQuery.trim().toLowerCase();
    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month);
    return provider.laporanCards.where((c) {
      // Kartu yang "rumahnya" sekarang sebuah folder TIDAK ditampilkan lagi
      // di sini — dia cuma tinggal di dalam folder itu (buka lewat
      // FolderDetailScreen), biar tidak dobel muncul di 2 tempat sekaligus
      // (section Folder & section Laporan bersamaan).
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
  /// santri [card] — dipanggil dari tap kolom pekan di [SantriReportCard].
  /// Card keseluruhan tidak lagi jadi shortcut tap.
  ///
  /// Sengaja TIDAK lagi "menebak" pekan mana yang mau dibuka (itu sumber
  /// bug lama: kartu di-tap pas pekan berjalan sudah keisi, otomatis
  /// lompat ke pekan awal bulan yang masih kosong — presetTanggal jadinya
  /// tanggal 1 padahal user tidak minta pekan itu, jadi kelihatan
  /// "ngebug"). Sekarang user selalu tau & pilih sendiri pekan mana yang
  /// mau dibuka lewat tap kolomnya langsung.
  void _openWeek(BuildContext context, SantriCardInfo card, int weekIndex) {
    final provider = context.read<RecordsProvider>();
    final now = DateTime.now();
    // Bulan PEMILIK pekan hari ini (bisa beda dari now.month di 1-2 hari
    // ujung bulan) — lihat WeekUtils.ownerMonth.
    final thisMonth = WeekUtils.ownerMonth(now);
    final currentWeek = WeekUtils.weekOfMonth(now);

    final existing = provider.recordForSantriInWeek(card.nama, thisMonth, weekIndex);
    if (existing != null) {
      // Pekan ini sudah ada laporannya -> buka mode edit, otomatis
      // menampilkan capaian yang sudah diisi minggu itu.
      showRecordFormSheet(context, existing: existing);
      return;
    }

    final range = WeekUtils.monthWeekRange(thisMonth, weekIndex);
    // Pekan yang dibuka = pekan berjalan & hari ini masih dalam rentang
    // pekan itu -> tanggal default realistis-nya ya HARI INI. Pekan lain
    // (sudah lewat, lagi disusulkan) -> Senin pertama pekan itu.
    final presetDate = (weekIndex == currentWeek &&
            !now.isBefore(range.start) &&
            !now.isAfter(range.end))
        ? now
        : range.start;

    showRecordFormSheet(
      context,
      presetKelas: card.kelas,
      presetHalaqoh: card.halaqoh,
      presetNama: card.nama,
      presetTanggal: presetDate,
      lockIdentity: true,
      // Kartu ini masih kosong TAPI sudah pernah dipindah ke sebuah folder
      // (drag/tap Pindahkan waktu masih kosong) -> laporan pertamanya
      // otomatis ikut masuk folder yang sama, bukan nangkring di luar.
      initialFolderId: card.emptyCardFolderId,
    );
  }

  /// Pindahkan kartu [card] ke folder pilihan user — dipanggil dari sheet
  /// aksi (tap kartu) ATAU drag kartu ke [FolderCard] di
  /// [SantriReportCard]. Berlaku juga buat kartu yang MASIH KOSONG (belum
  /// ada laporan sama sekali) — lihat [RecordsProvider.moveIdentityToFolder].
  Future<void> _pindahkanCard(BuildContext context, SantriCardInfo card,
      {String? langsungKeFolderId}) async {
    final provider = context.read<RecordsProvider>();
    final target = langsungKeFolderId ??
        await showFolderPickerSheet(
          context,
          itemCount: card.hasAnyReport ? provider.recordsForSantri(card.nama).length : 1,
        );
    if (target == null || !context.mounted) return;
    await provider.moveIdentityToFolder(card, target.isEmpty ? null : target);
    if (!context.mounted) return;
    showAppSnackbar(
      context,
      'Kartu "${card.nama}" dipindahkan.',
      icon: Icons.drive_file_move_outline,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  /// Hapus kartu [card] — kartu kosong (belum ada laporan) cuma lepas
  /// identitasnya, kartu yang sudah ada laporannya ikut menghapus SEMUA
  /// laporan pekanan di dalamnya. Selalu minta konfirmasi dulu karena
  /// untuk kartu berisi ini SEKARANG bisa dipicu juga lewat geser-kanan
  /// (swipe), bukan cuma lewat sheet aksi.
  Future<void> _hapusCard(BuildContext context, SantriCardInfo card) async {
    final hasReports = card.hasAnyReport;
    final confirmed = await showDialog<bool>(
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await context.read<RecordsProvider>().deleteAllForSantri(card.nama, card.identityKey);
    if (!context.mounted) return;
    showAppSnackbar(
      context,
      'Kartu "${card.nama}" dihapus.',
      icon: Icons.delete_outline_rounded,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
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
                    label: 'Pindahkan ke Folder',
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
                    // Drop hasil drag SantriReportCard (payload = daftar
                    // identityKey, lihat SantriReportCard) -> pindahkan tiap
                    // kartu yang di-drag ke folder ini langsung, tanpa buka
                    // sheet pilih folder lagi (folder tujuannya kan sudah
                    // jelas dari mana dia dilepas).
                    onDropRecord: (identityKeys) async {
                      for (final key in identityKeys) {
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