import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/parent_notes_provider.dart';
import '../../../providers/records_provider.dart';
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _laporanSelecting = false;
  int _snackbarHidingFab = 0;
  final _fabController = SpeedDialController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // BUG FIX: guru yang assignment kelas/halaqoh-nya diubah admin lewat
    // "Kelola Akun Guru" TIDAK LANGSUNG ke-refresh di device guru itu
    // sendiri -- `AuthProvider.reloadAccounts()` sebelumnya CUMA dipanggil
    // dari sisi admin (buat nyegerin cache admin sendiri kalau akunnya
    // sendiri yang diedit), jadi kalau si guru lagi login di device/tab
    // LAIN pas assignment-nya diubah, `currentUser.assignments`-nya di
    // situ tetap versi LAMA sampai session-nya bener2 di-restart (logout
    // + login lagi) -- makanya daftar santri kelas yang baru
    // ditambahkan/diaktifkan lagi jadi kelihatan tapi TIDAK BISA di-tap
    // (AccessScope.canAccessStudent masih ngecek assignment lama).
    //
    // Ini KHUSUS kerasa parah di versi WEB, karena tab browser bisa
    // dibiarkan terbuka berjam-jam tanpa pernah "restart" app sama sekali
    // (beda sama app mobile yang lebih sering ke-kill/dibuka ulang secara
    // alami). Sekarang: begitu tab/app ini balik ke foreground
    // (`resumed` -- Flutter Web juga sudah lapor state ini lewat Page
    // Visibility API), assignment guru itu di-refresh ulang dari
    // Firestore/cache, dan scope yang udah kepakai di RecordsProvider/
    // ParentNotesProvider ikut di-sync ulang -- TANPA perlu logout-login
    // manual lagi.
    if (state == AppLifecycleState.resumed) {
      _refreshAssignmentsIfLoggedIn();
    }
  }

  Future<void> _refreshAssignmentsIfLoggedIn() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;
    await auth.reloadAccounts();
    if (!mounted) return;
    context.read<RecordsProvider>().updateScope(auth.scope);
    context.read<ParentNotesProvider>().updateScope(auth.scope);
  }

  void _switchTab(int index) {
    if (index == _index) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
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