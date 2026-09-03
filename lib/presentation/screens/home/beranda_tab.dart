import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';

import '../../../data/models/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_notes_provider.dart'; // <-- BARU
import '../../../providers/records_provider.dart';
import '../../widgets/avatar_image_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/filter_sheet.dart';
import '../profile/profile_screen.dart';
import '../laporan/buat_laporan_sheet.dart';
import '../export/export_sheet.dart';
import '../notifications/notifications_screen.dart';

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
                    'Kelola laporan Tahsin & Tahfizh santri dengan mudah dan terstruktur.',
                actions: Row(
                  children: [
                    Expanded(
                      child: HeroActionItem(
                        label: 'Tambah\nLaporan',
                        icon: Icons.add_rounded,
                        onTap: () => showBuatLaporanSheet(context),
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
                            onTap: () => goToFiltered(HafalanStatus.tahfizh),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CategoryTile(
                            label: 'Tahsin',
                            icon: Icons.menu_book_rounded,
                            color: AppColors.tahsinOn(context),
                            active: provider.filterStatus == HafalanStatus.tahsin,
                            onTap: () => goToFiltered(HafalanStatus.tahsin),
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

  void _openProfile(BuildContext context) {
    // Satu titik navigasi ke Profile.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.watch<AuthProvider>().currentUser;
    final nama = user?.displayName ?? 'Pengelola Laporan';
    final initial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';
    final photoPath = user?.photoPath;

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _openProfile(context),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              backgroundImage: resolveAvatarImage(photoPath),
              child: photoPath == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _openProfile(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assalamu\'alaikum 👋', style: TextStyle(fontSize: 13)),
                Text(
                  nama,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        // <-- BERUBAH: bell sekarang nampilin badge titik merah kalau ada
        // catatan orang tua yang belum dibaca — sebelumnya cuma ikon
        // statis tanpa indikator apapun.
        Builder(builder: (context) {
          final unread = context.watch<ParentNotesProvider>().unreadCount;
          return Material(
            color: Theme.of(context).cardTheme.color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      unread > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_none_rounded,
                      size: 22,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).cardTheme.color ??
                                  Theme.of(context).scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
