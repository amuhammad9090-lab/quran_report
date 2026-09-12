import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/settings_screen.dart';
import '../laporan/laporan_tab.dart';
import '../laporan/buat_laporan_sheet.dart';
import '../statistik/statistik_tab.dart';
import '../folder/folder_form_sheet.dart';
import '../../widgets/speed_dial_fab.dart';
import 'beranda_tab.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Shell utama aplikasi — bottom navigation 4 tab (Beranda, Laporan,
/// Statistik, Pengaturan). Semua tab reuse screen/logic yang sudah ada,
/// cuma disusun ulang navigasinya.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _laporanSelecting = false;
  int _snackbarHidingFab = 0;
  final _fabController = SpeedDialController();

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _index) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _fabController.close();
    setState(() => _index = index);
  }

  void _goToLaporan() => _switchTab(1);

  void _setFabVisible(bool visible) {
    if (!visible) _fabController.close();
    setState(() {
      _snackbarHidingFab = (visible ? _snackbarHidingFab - 1 : _snackbarHidingFab + 1)
          .clamp(0, 1 << 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF181F26),
        systemNavigationBarIconBrightness: Brightness.light,
      )
          : SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      // Fix: MainShell ini root route-nya app (nggak ada Navigator di
      // atasnya).
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _switchTab(0);
        },
        child: Scaffold(
          body: ListenableBuilder(
            listenable: _fabController,
            builder: (context, child) => Stack(
              children: [
                child!,
                if (_fabController.isOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _fabController.close,
                    ),
                  ),
              ],
            ),
            child: IndexedStack(
              index: _index,
              children: [
                BerandaTab(onLihatLaporan: _goToLaporan),
                LaporanTab(
                  onSelectionModeChanged: (v) {
                    if (v) _fabController.close();
                    setState(() => _laporanSelecting = v);
                  },
                  onFabVisibilityChanged: _setFabVisible,
                ),
                const StatistikTab(),
                const SettingsScreen(),
              ],
            ),
          ),
          // Tab Laporan: FAB cuma "+", ditekan nyembul jadi 2 pilihan
          // (Buat Folder / Buat Laporan).
          floatingActionButton: _index == 1 && !_laporanSelecting && _snackbarHidingFab == 0
              ? SpeedDialFab(
            controller: _fabController,
            onBuatFolder: () => showFolderFormSheet(context),
            onBuatLaporan: () => showBuatLaporanSheet(context, onFabVisibilityChanged: _setFabVisible),
          )
              : null,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _switchTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(LucideIcons.house),
                    selectedIcon: Icon(LucideIcons.house),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(LucideIcons.calendarDays),
                    selectedIcon: Icon(LucideIcons.calendarDays),
                    label: 'Laporan',
                  ),
                  NavigationDestination(
                    icon: Icon(LucideIcons.chartColumn),
                    selectedIcon: Icon(LucideIcons.chartColumn),
                    label: 'Statistik',
                  ),
                  NavigationDestination(
                    icon: Icon(LucideIcons.settings),
                    selectedIcon: Icon(LucideIcons.settings),
                    label: 'Pengaturan',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}