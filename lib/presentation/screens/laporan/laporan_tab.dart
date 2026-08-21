import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/record_card.dart';
import '../../widgets/filter_sheet.dart';
import '../record_form/record_form_sheet.dart';

/// Tab "Laporan" — pencarian, filter, dan daftar lengkap laporan santri.
/// Header + search bar dibikin pinned (nempel atas), list scroll di
/// belakangnya.
class LaporanTab extends StatefulWidget {
  const LaporanTab({super.key});

  @override
  State<LaporanTab> createState() => _LaporanTabState();
}

class _LaporanTabState extends State<LaporanTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final records = provider.filtered;

    // Sinkronin controller lokal ke provider — biar kalau search di-reset
    // dari luar (mis. tombol Reset di Filter, atau tile "Semua Santri" di
    // Home), kolom pencarian ikut kekosongin, bukan cuma state provider-nya.
    if (_searchCtrl.text != provider.searchQuery) {
      _searchCtrl.value = _searchCtrl.value.copyWith(
        text: provider.searchQuery,
        selection: TextSelection.collapsed(offset: provider.searchQuery.length),
      );
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
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
            if (records.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
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
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                sliver: SliverList.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = records[i];
                    return RecordCard(
                      record: r,
                      onEdit: () => showRecordFormSheet(context, existing: r),
                      onDelete: () => _confirmDelete(context, r.id),
                    );
                  },
                ),
              ),
          ],
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
}
