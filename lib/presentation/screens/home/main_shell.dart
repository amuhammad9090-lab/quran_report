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

  // Kontrol buka/tutup SpeedDialFab dari luar widgetnya sendiri (lihat
  // SpeedDialController) -- dibutuhkan buat barrier transparan di bawah
  // ini, biar tap di sembarang tempat langsung nutup dial-nya (bug fix:
  // sebelumnya cuma bisa ditutup lewat tombol "+" itu sendiri).
  final _fabController = SpeedDialController();

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _index) return;
    // Snackbar (mis. dari bell notifikasi di Home) numpang di satu
    // Scaffold yang sama antar-tab (IndexedStack) — kalau nggak di-hide
    // dulu, dia bisa "nyasar" nongol di tab lain waktu pindah tab.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Dial-nya cuma relevan di tab Laporan -- kalau lagi kebuka terus user
    // pindah tab, tutup dulu biar barrier-nya nggak nyangkut di tab lain.
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
        // Body dibungkus Stack + barrier transparan (lewat ListenableBuilder
        // yang dengerin _fabController): pas SpeedDialFab lagi kebuka, tap
        // di MANA AJA di body ini langsung nutup dial-nya. FAB sendiri
        // (tombol "+" & 2 mini action-nya) dirender lewat slot
        // `floatingActionButton` Scaffold, yang otomatis digambar DI ATAS
        // body -- jadi barrier ini nggak nutupin/nge-block tap ke FAB atau
        // mini action-nya sendiri, cuma nangkep tap di area lain.
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
                  // Mode pilih-banyak aktif -> FAB-nya ikut disembunyikan
                  // (lihat floatingActionButton di bawah), jadi dial-nya
                  // juga harus ketutup, bukan cuma widget FAB-nya hilang.
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
        // (Buat Folder / Buat Laporan). Tab lain: FAB disembunyikan lagi
        // seperti semula. Pas mode pilih-banyak aktif ATAU snackbar
        // "dipindahkan/dikeluarkan" lagi tampil, FAB ikut disembunyikan
        // juga — biar snackbar bisa nempel rapi di atas bottom nav tanpa
        // numpuk/ngambang di atas ikon FAB.
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