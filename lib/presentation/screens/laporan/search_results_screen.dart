import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/week_utils.dart';
import '../../../providers/folders_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/filter_sheet.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/santri_report_card.dart';
import '../folder/move_to_folder_sheet.dart';
import '../record_form/record_form_sheet.dart';

/// Halaman "Hasil Pencarian" — beda dari list utama di tab Laporan yang
/// cuma nyari kartu santri yang BELUM masuk folder mana pun, halaman ini
/// nyari ke SEMUA kartu santri (termasuk yang sudah ada di dalam folder),
/// dikelompokkan per folder biar user tetap tahu asalnya. Satu kartu =
/// satu santri (sama seperti tab Laporan), lihat [SantriReportCard] &
/// [SantriCardInfo.currentFolderId].
///
/// Search query & filter di-share langsung dari [RecordsProvider] yang
/// sama dengan tab Laporan — jadi begitu dibuka langsung nunjukin hasil
/// query yang lagi diketik di sana, dan kolom pencarian di sini tetap bisa
/// diketik ulang buat mempertajam tanpa balik dulu ke tab Laporan.
class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _searchCtrl =
  TextEditingController(text: context.read<RecordsProvider>().searchQuery);

  // Accordion panel info pekan LINTAS-KARTU (termasuk lintas grup folder
  // di halaman ini) — lihat catatan yang sama di laporan_tab.dart.
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

  /// Kartu yang cocok dengan pencarian & filter kelas/halaqoh aktif — sama
  /// persis pola filternya dengan `LaporanTab._filteredCards`, cuma di sini
  /// TIDAK dibatasi ke kartu tanpa folder saja (lihat dok kelas di atas).
  List<SantriCardInfo> _filteredCards(RecordsProvider provider) {
    final q = provider.searchQuery.trim().toLowerCase();
    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month);
    return provider.laporanCards.where((c) {
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

  void _openWeek(BuildContext context, SantriCardInfo card, int weekIndex) {
    final provider = context.read<RecordsProvider>();
    final now = DateTime.now();
    // Bulan PEMILIK pekan hari ini (bisa beda dari now.month di 1-2 hari
    // ujung bulan) — lihat WeekUtils.ownerMonth.
    final thisMonth = WeekUtils.ownerMonth(now);
    final currentWeek = WeekUtils.weekOfMonth(now);

    final range = WeekUtils.monthWeekRange(thisMonth, weekIndex);
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentWeek = weekIndex == currentWeek &&
        !today.isBefore(range.start) &&
        !today.isAfter(range.end);
    final presetDate = isCurrentWeek ? today : range.start;

    // Dicek per-HARI PERSIS di semua pekan (current maupun lewat) —
    // konsisten dengan Rekap Harian. Lihat catatan lengkap di
    // laporan_tab.dart (_openWeek) & RecordsProvider.recordForSantriOnDate.
    final existing = provider.recordForSantriOnDate(card.nama, presetDate);
    if (existing != null) {
      // lockIdentity: true -> samain kek buka form laporan baru dari kartu,
      // identitas santri udah jelas dari kartunya, nggak perlu ditampilin lagi.
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

  Future<void> _pindahkanCard(BuildContext context, SantriCardInfo card) async {
    final provider = context.read<RecordsProvider>();
    final result = await showFolderPickerSheet(context, currentFolderId: card.currentFolderId);
    if (result == null || !context.mounted) return;
    await provider.moveIdentityToFolder(card, result.isEmpty ? null : result);
  }

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
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, SantriCardInfo c) {
    return SantriReportCard(
      info: c,
      onTapWeek: (weekIndex) => _openWeek(context, c, weekIndex),
      onPindahkanKeFolder: () => _pindahkanCard(context, c),
      onHapus: () => _hapusCard(context, c),
      expandedWeek: _expandedCardId == c.identityKey ? _expandedWeek : null,
      onToggleWeek: (weekIndex) => _toggleCardWeek(c.identityKey, weekIndex),
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
                style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final foldersProvider = context.watch<FoldersProvider>();

    // Sinkronin controller lokal ke provider (dua arah dengan tab Laporan —
    // search box di sini & di sana pakai searchQuery yang sama persis).
    if (_searchCtrl.text != provider.searchQuery) {
      _searchCtrl.value = _searchCtrl.value.copyWith(
        text: provider.searchQuery,
        selection: TextSelection.collapsed(offset: provider.searchQuery.length),
      );
    }

    final results = _filteredCards(provider)
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));

    // Kelompokkan per folder (null = tanpa folder / langsung di tab
    // Laporan), diurut nama folder biar rapi, "Tanpa Folder" ditaruh
    // paling akhir.
    final Map<String?, List<SantriCardInfo>> grouped = {};
    for (final c in results) {
      grouped.putIfAbsent(c.currentFolderId, () => []).add(c);
    }
    final folderIds = grouped.keys.whereType<String>().toList()
      ..sort((a, b) {
        final na = foldersProvider.byId(a)?.nama ?? '';
        final nb = foldersProvider.byId(b)?.nama ?? '';
        return na.toLowerCase().compareTo(nb.toLowerCase());
      });
    final tanpaFolder = grouped[null] ?? const [];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Hasil Pencarian',
              subtitle: '${results.length} kartu santri ditemukan • semua folder',
            ),
            SliverToBoxAdapter(child: _buildSearchAndFilter(context, provider)),
            if (results.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.only(top: 24),
                sliver: SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Data tidak ditemukan',
                    subtitle: 'Coba ubah kata kunci atau filter pencarian.',
                  ),
                ),
              )
            else ...[
              for (final fid in folderIds) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: SectionLabel(
                      '📁 ${foldersProvider.byId(fid)?.nama ?? 'Folder'}',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  sliver: SliverList.separated(
                    itemCount: grouped[fid]!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _buildCard(context, grouped[fid]![i]),
                  ),
                ),
              ],
              if (tanpaFolder.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: SectionLabel(folderIds.isEmpty ? 'Laporan' : 'Tanpa Folder'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: tanpaFolder.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _buildCard(context, tanpaFolder[i]),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
