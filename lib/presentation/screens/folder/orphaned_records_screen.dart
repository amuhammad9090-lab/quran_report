import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/folders_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/santri_report_card.dart';
import '../laporan/open_week_action.dart';
import 'move_to_folder_sheet.dart';

/// Halaman "penyelamatan" kartu santri yang folder tujuannya sudah tidak
/// ada lagi (lihat [RecordsProvider.orphanedFolderCards]) — laporannya
/// SENDIRI masih aman tersimpan, cuma `folderId`-nya menunjuk ke folder
/// yang sudah tidak ada, jadi kartunya ketutupan dari tab Laporan (dianggap
/// "sudah di dalam folder") maupun dari section Folder (folder tujuannya
/// sendiri tidak ada buat ditampilkan). Di sini user bisa pindahkan tiap
/// kartu ke folder yang masih ada, atau keluarkan dari folder supaya balik
/// muncul di daftar "Laporan" biasa.
class OrphanedRecordsScreen extends StatefulWidget {
  final ValueChanged<bool>? onFabVisibilityChanged;
  const OrphanedRecordsScreen({super.key, this.onFabVisibilityChanged});

  @override
  State<OrphanedRecordsScreen> createState() => _OrphanedRecordsScreenState();
}

class _OrphanedRecordsScreenState extends State<OrphanedRecordsScreen> {
  bool _selectionMode = false;
  final Set<String> _selected = {};

  // Accordion panel info pekan LINTAS-KARTU — pola sama seperti
  // laporan_tab.dart & folder_detail_screen.dart.
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

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selected.clear();
      _expandedCardId = null;
      _expandedWeek = null;
    });
  }

  void _startSelectingWith(String identityKey) {
    setState(() {
      _selectionMode = true;
      _selected.add(identityKey);
      _expandedCardId = null;
      _expandedWeek = null;
    });
  }

  void _toggleSelect(String identityKey) {
    setState(() {
      _selected.contains(identityKey) ? _selected.remove(identityKey) : _selected.add(identityKey);
    });
  }

  void _setSelectAll(bool select, List<SantriCardInfo> cards) {
    setState(() {
      if (select) {
        _selected
          ..clear()
          ..addAll(cards.map((c) => c.identityKey));
      } else {
        _selected.clear();
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _openWeek(BuildContext context, SantriCardInfo card, int weekIndex) {
    openWeekForSantri(context, card, weekIndex, initialFolderId: card.currentFolderId);
  }

  Future<void> _pindahkanCard(BuildContext context, SantriCardInfo card) async {
    final provider = context.read<RecordsProvider>();
    final target = await showFolderPickerSheet(
      context,
      currentFolderId: card.currentFolderId,
      itemCount: card.hasAnyReport ? provider.recordsForSantri(card.nama).length : 1,
    );
    if (target == null) return;
    if (!context.mounted) return;
    await provider.moveIdentityToFolder(card, target.isEmpty ? null : target);
    if (!context.mounted) return;
    showAppSnackbar(
      context,
      target.isEmpty
          ? 'Kartu "${card.nama}" dikeluarkan dari folder.'
          : 'Kartu "${card.nama}" dipindahkan.',
      icon: Icons.drive_file_move_outline,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  Future<void> _pindahkanSelected(List<SantriCardInfo> cards) async {
    final provider = context.read<RecordsProvider>();
    final keys = _selected.toList();
    final itemCount = keys.fold<int>(0, (sum, key) {
      final c = provider.cardByIdentityKey(key);
      if (c == null) return sum;
      return sum + (c.hasAnyReport ? provider.recordsForSantri(c.nama).length : 1);
    });
    final target = await showFolderPickerSheet(context, itemCount: itemCount);
    if (target == null) return;
    if (!context.mounted) return;
    final count = keys.length;
    for (final key in keys) {
      final c = provider.cardByIdentityKey(key);
      if (c != null) await provider.moveIdentityToFolder(c, target.isEmpty ? null : target);
      if (!context.mounted) return;
    }
    if (!context.mounted) return;
    final ctx = context;
    _exitSelectionMode();
    showAppSnackbar(
      ctx,
      '$count kartu dipindahkan.',
      icon: Icons.drive_file_move_outline,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  Future<void> _keluarkanSelected() async {
    final provider = context.read<RecordsProvider>();
    final count = _selected.length;
    for (final key in _selected.toList()) {
      final c = provider.cardByIdentityKey(key);
      if (c != null) await provider.moveIdentityToFolder(c, null);
      if (!context.mounted) return;
    }
    if (!context.mounted) return;
    final ctx = context;
    _exitSelectionMode();
    showAppSnackbar(
      ctx,
      '$count kartu dikeluarkan dari folder.',
      icon: Icons.folder_off_outlined,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  Future<void> _hapusCard(BuildContext context, SantriCardInfo card) async {
    final hasReports = card.hasAnyReport;
    final confirmed = await showDialog<bool>(
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await context.read<RecordsProvider>().deleteAllForSantri(card.nama, card.identityKey);
    if (!context.mounted) return;
    showAppSnackbar(
      context,
      'Kartu "${card.nama}" dihapus.',
      icon: Icons.delete_outline_rounded,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersProvider = context.watch<FoldersProvider>();
    final recordsProvider = context.watch<RecordsProvider>();
    final validFolderIds = foldersProvider.all.map((f) => f.id).toSet();
    final cards = recordsProvider.orphanedFolderCards(validFolderIds);

    // Begitu semua kartu sudah "diselamatkan" (dipindah/dikeluarkan), tidak
    // ada lagi yang perlu ditampilkan di sini -> otomatis balik ke layar
    // sebelumnya.
    if (cards.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                PushedPageHeader(
                  title: 'Laporan Folder Hilang',
                  subtitle: '${cards.length} kartu perlu dipindahkan',
                  trailing: cards.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _toggleSelectionMode,
                          icon: Icon(
                            _selectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                          ),
                          tooltip: _selectionMode ? 'Batal pilih' : 'Pilih beberapa kartu',
                        ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 20, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Laporan kartu-kartu ini masih aman tersimpan, tapi folder '
                              'tujuannya sudah tidak ada lagi. Pindahkan ke folder lain, '
                              'atau keluarkan dari folder supaya muncul lagi di daftar Laporan.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (cards.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Semua sudah diselamatkan',
                      subtitle: 'Tidak ada lagi kartu dengan folder yang hilang.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, _selectionMode ? 110 : 24),
                    sliver: SliverList.separated(
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final c = cards[i];
                        return SantriReportCard(
                          info: c,
                          onTapWeek: (weekIndex) => _openWeek(context, c, weekIndex),
                          onPindahkanKeFolder: () => _pindahkanCard(context, c),
                          onHapus: () => _hapusCard(context, c),
                          selectionMode: _selectionMode,
                          selected: _selected.contains(c.identityKey),
                          onSelectToggle: () => _toggleSelect(c.identityKey),
                          selectedIds: _selected.toList(),
                          onLongPressStartSelect: () => _startSelectingWith(c.identityKey),
                          expandedWeek: _expandedCardId == c.identityKey ? _expandedWeek : null,
                          onToggleWeek: (weekIndex) => _toggleCardWeek(c.identityKey, weekIndex),
                        );
                      },
                    ),
                  ),
              ],
            ),
            if (_selectionMode)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SelectionActionBar(
                  selectedCount: _selected.length,
                  totalCount: cards.length,
                  onSelectAllChanged: (v) => _setSelectAll(v, cards),
                  onCancel: _toggleSelectionMode,
                  actions: [
                    SelectionAction(
                      icon: Icons.folder_off_outlined,
                      label: 'Keluarkan',
                      onTap: _selected.isEmpty ? null : _keluarkanSelected,
                      destructive: true,
                    ),
                    SelectionAction(
                      icon: Icons.drive_file_move_outline,
                      label: 'Pindahkan',
                      onTap: _selected.isEmpty ? null : () => _pindahkanSelected(cards),
                      filled: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
