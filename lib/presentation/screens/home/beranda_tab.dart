import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';

import '../../../data/models/enums.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/filter_sheet.dart';
import '../record_form/record_form_sheet.dart';
import '../export/export_sheet.dart';

/// Tab "Home" — dashboard ringkasan. Daftar laporan penuh ada di tab
/// "Laporan"; tile kategori di sini cuma set filter lalu pindah ke sana.
class BerandaTab extends StatelessWidget {
  final VoidCallback onLihatLaporan;
  const BerandaTab({super.key, required this.onLihatLaporan});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final cs = Theme.of(context).colorScheme;

    void goToFiltered(HafalanStatus? status) {
      provider.setFilterStatus(status);
      onLihatLaporan();
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      // CustomScrollView + SliverAppBar pinned: sapaan "Assalamu'alaikum"
      // nempel di atas (batas header persis di atas banner hijau), konten
      // di bawahnya (mulai dari banner) scroll lewat di belakangnya.
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 3,
            shadowColor: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10),
            toolbarHeight: 76,
            titleSpacing: 20,
            title: _buildHeader(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            sliver: SliverList.list(
              children: [
                WelcomeHeroCard(
                title: 'Selamat datang di\nAplikasi Laporan Al Quran!',
                subtitle:
                    'Kelola laporan tahsin & tahfizh santri dengan mudah dan terstruktur.',
                actions: Row(
                  children: [
                    Expanded(
                      child: HeroActionItem(
                        label: 'Tambah\nLaporan',
                        icon: Icons.add_rounded,
                        onTap: () => showRecordFormSheet(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HeroActionItem(
                        label: 'Ekspor\nData',
                        icon: Icons.ios_share_rounded,
                        onTap: () => showExportSheet(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Ringkasan Hari Ini',
                onSeeAll: onLihatLaporan,
                child: Row(
                  children: [
                    Expanded(
                      child: StatItem(
                        label: 'Laporan Baru',
                        value: '${provider.laporanBaruHariIni}',
                        icon: Icons.post_add_rounded,
                        color: cs.primary,
                      ),
                    ),
                    const VDivider(),
                    Expanded(
                      child: StatItem(
                        label: 'Total Baris',
                        value: '${provider.totalBarisHariIni}',
                        icon: Icons.format_list_numbered_rounded,
                        color: AppColors.purpleOn(context),
                      ),
                    ),
                    const VDivider(),
                    Expanded(
                      child: StatItem(
                        label: 'Santri Aktif',
                        value: '${provider.santriAktifHariIni}',
                        icon: Icons.groups_2_rounded,
                        color: AppColors.tahsinOn(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Kategori Cepat',
                onSeeAll: onLihatLaporan,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CategoryTile(
                            label: 'Tahfizh',
                            icon: Icons.auto_stories_rounded,
                            color: AppColors.tahfizhOn(context),
                            active: provider.filterStatus == HafalanStatus.tahfizh,
                            onTap: () => goToFiltered(
                              provider.filterStatus == HafalanStatus.tahfizh
                                  ? null
                                  : HafalanStatus.tahfizh,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CategoryTile(
                            label: 'Tahsin',
                            icon: Icons.menu_book_rounded,
                            color: AppColors.tahsinOn(context),
                            active: provider.filterStatus == HafalanStatus.tahsin,
                            onTap: () => goToFiltered(
                              provider.filterStatus == HafalanStatus.tahsin
                                  ? null
                                  : HafalanStatus.tahsin,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CategoryTile(
                            label: 'Semua Santri',
                            icon: Icons.groups_2_rounded,
                            color: cs.primary,
                            active: !provider.hasActiveFilters,
                            onTap: () {
                              provider.clearFilters();
                              onLihatLaporan();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CategoryTile(
                            label: 'Filter Lainnya',
                            icon: Icons.tune_rounded,
                            color: AppColors.redOn(context),
                            onTap: () {
                              onLihatLaporan();
                              showFilterSheet(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.person_rounded, color: cs.onPrimaryContainer, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assalamu\'alaikum 👋', style: TextStyle(fontSize: 13)),
              Text(
                'Pengelola Laporan',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Material(
          color: Theme.of(context).cardTheme.color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Belum ada notifikasi baru')),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 22),
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.greenOn(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardTheme.color ?? Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
