import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/settings_screen.dart';
import '../laporan/laporan_tab.dart';
import '../laporan/buat_laporan_sheet.dart';
import '../statistik/statistik_tab.dart';
import '../folder/folder_form_sheet.dart';
import '../../widgets/speed_dial_fab.dart';
import 'beranda_tab.dart';

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
  // Counter, bukan bool — biar aman kalau ada 2 snackbar nyaris bebarengan
  // (mis. drag-drop cepat 2x): FAB baru muncul lagi kalau semua "pemegang"
  // sudah selesai (count balik ke 0), gak ada yang keburu nge-reset ke true
  // duluan padahal snackbar lain masih tampil.
  int _snackbarHidingFab = 0;

  void _switchTab(int index) {
    if (index == _index) return;
    // Snackbar (mis. dari bell notifikasi di Home) numpang di satu
    // Scaffold yang sama antar-tab (IndexedStack) — kalau nggak di-hide
    // dulu, dia bisa "nyasar" nongol di tab lain waktu pindah tab.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _index = index);
  }

  void _goToLaporan() => _switchTab(1);

  void _setFabVisible(bool visible) {
    setState(() {
      _snackbarHidingFab = (visible ? _snackbarHidingFab - 1 : _snackbarHidingFab + 1)
          .clamp(0, 1 << 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fix: tanpa ini, ikon status bar (jam/baterai/sinyal) nggak ikut
    // kontras tema — bisa "ketutup"/nyaris invisible di light theme
    // karena warnanya nggak di-set sama sekali secara default.
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
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            BerandaTab(onLihatLaporan: _goToLaporan),
            LaporanTab(
              onSelectionModeChanged: (v) => setState(() => _laporanSelecting = v),
              onFabVisibilityChanged: _setFabVisible,
            ),
            const StatistikTab(),
            const SettingsScreen(),
          ],
        ),
        // Tab Laporan: FAB cuma "+", ditekan nyembul jadi 2 pilihan
        // (Buat Folder / Buat Laporan). Tab lain: FAB disembunyikan lagi
        // seperti semula. Pas mode pilih-banyak aktif ATAU snackbar
        // "dipindahkan/dikeluarkan" lagi tampil, FAB ikut disembunyikan
        // juga — biar snackbar bisa nempel rapi di atas bottom nav tanpa
        // numpuk/ngambang di atas ikon FAB.
        floatingActionButton: _index == 1 && !_laporanSelecting && _snackbarHidingFab == 0
            ? SpeedDialFab(
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
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: 'Laporan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Statistik',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Pengaturan',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}