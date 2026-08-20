import 'package:flutter/material.dart';

import '../record_form/record_form_sheet.dart';
import '../settings/settings_screen.dart';
import '../laporan/laporan_tab.dart';
import '../statistik/statistik_tab.dart';
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

  void _goToLaporan() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          BerandaTab(onLihatLaporan: _goToLaporan),
          const LaporanTab(),
          const StatistikTab(),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => showRecordFormSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Laporan Baru'),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
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
    );
  }
}
