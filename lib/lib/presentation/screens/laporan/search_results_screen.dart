import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/santri_record.dart';
import '../../../providers/folders_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/filter_sheet.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/record_card.dart';
import '../folder/move_to_folder_sheet.dart';
import '../record_form/record_form_sheet.dart';

/// Halaman "Hasil Pencarian" — beda dari list utama di tab Laporan yang
/// cuma nyari laporan yang BELUM masuk folder mana pun, halaman ini nyari
/// ke SEMUA laporan (termasuk yang sudah ada di dalam folder), dikelompokkan
/// per folder biar user tetap tahu asalnya.
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _moveSingle(BuildContext context, SantriRecord r) async {
    final provider = context.read<RecordsProvider>();
    final result = await showFolderPickerSheet(context, currentFolderId: r.folderId);
    if (result == null || !context.mounted) return;
    await provider.moveToFolder(r.id, result.isEmpty ? null : result);
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

  Widget _buildRecordCard(BuildContext context, SantriRecord r) {
    return RecordCard(
      record: r,
      onEdit: () => showRecordFormSheet(context, existing: r),
      onDelete: () => _confirmDelete(context, r.id),
      onPindahkanKeFolder: () => _moveSingle(context, r),
      pindahkanLabel: r.folderId == null ? 'Pindahkan ke Folder' : 'Pindahkan ke Folder Lain',
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

    final results = List<SantriRecord>.from(provider.filtered)
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    // Kelompokkan per folder (null = tanpa folder / langsung di tab
    // Laporan), diurut nama folder biar rapi, "Tanpa Folder" ditaruh
    // paling akhir.
    final Map<String?, List<SantriRecord>> grouped = {};
    for (final r in results) {
      grouped.putIfAbsent(r.folderId, () => []).add(r);
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
              subtitle: '${results.length} laporan ditemukan • semua folder',
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
                    itemBuilder: (context, i) => _buildRecordCard(context, grouped[fid]![i]),
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
                    itemBuilder: (context, i) => _buildRecordCard(context, tanpaFolder[i]),
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