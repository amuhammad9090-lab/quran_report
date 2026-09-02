import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/folder.dart';
import '../../../providers/folders_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/santri_report_card.dart';
import '../laporan/buat_laporan_sheet.dart';
import '../laporan/open_week_action.dart';
import 'add_recent_records_sheet.dart';
import 'folder_form_sheet.dart';

/// Halaman isi satu folder — daftar KARTU SANTRI di dalamnya (satu kartu =
/// satu santri, sama seperti tab Laporan, BUKAN satu kartu per laporan
/// pekanan lagi
class FolderDetailScreen extends StatefulWidget {
  final String folderId;

  /// Diteruskan dari [MainShell] lewat [LaporanTab] — dipakai buat
  /// nyembunyiin FAB tab Laporan selama snackbar aksi (keluarkan/hapus) di
  /// layar ini masih tampil.
  final ValueChanged<bool>? onFabVisibilityChanged;

  const FolderDetailScreen({super.key, required this.folderId, this.onFabVisibilityChanged});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  bool _selectionMode = false;
  final Set<String> _selected = {};

  // Accordion panel info pekan LINTAS-KARTU — lihat catatan yang sama di
  // laporan_tab.dart.
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

  Future<void> _keluarkanSelected() async {
    final provider = context.read<RecordsProvider>();
    final count = _selected.length;
    for (final key in _selected.toList()) {
      final c = provider.cardByIdentityKey(key);
      if (c != null) await provider.moveIdentityToFolder(c, null);
      if (!context.mounted) return;
    }
    if (!context.mounted) return;
    _exitSelectionMode();
    showAppSnackbar(
      context,
      '$count kartu dikeluarkan dari folder',
      icon: Icons.folder_off_outlined,
      onFabVisibilityChanged: widget.onFabVisibilityChanged,
    );
  }

  Future<void> _confirmDeleteSelected() async {
    final provider = context.read<RecordsProvider>();
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $count kartu?'),
        content: const Text('Semua laporan pekanan di dalamnya ikut terhapus. Data yang dihapus tidak dapat dikembalikan.'),
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
    for (final key in _selected.toList()) {
      final c = provider.cardByIdentityKey(key);
      if (c != null) await provider.deleteAllForSantri(c.nama, c.identityKey);
      if (!context.mounted) return;
    }
    _exitSelectionMode();
  }

  /// Buka form laporan untuk pekan [weekIndex] milik kartu [card]
  void _openWeek(BuildContext context, SantriCardInfo card, int weekIndex) {
    openWeekForSantri(context, card, weekIndex, initialFolderId: widget.folderId);
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
    final folder = foldersProvider.byId(widget.folderId);

    if (folder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final recordsProvider = context.watch<RecordsProvider>();
    final cards = recordsProvider.cardsInFolder(widget.folderId);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                PushedPageHeader(
                  title: folder.nama,
                  subtitle: '${cards.length} kartu santri',
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: _ActionButtonsRow(
                      folder: folder,
                      onFabVisibilityChanged: widget.onFabVisibilityChanged,
                    ),
                  ),
                ),
                if (cards.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: 'Folder ini masih kosong',
                      subtitle: 'Buat laporan baru atau tambahkan kartu yang sudah ada.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, _selectionMode ? 110 : 24),
                    sliver: SliverList.separated(
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final c = cards[i];
                        return SantriReportCard(
                          info: c,
                          onTapWeek: (weekIndex) => _openWeek(context, c, weekIndex),
                          onPindahkanKeFolder: () => recordsProvider.moveIdentityToFolder(c, null),
                          isInsideFolder: true,
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
                      icon: Icons.delete_outline_rounded,
                      label: 'Hapus',
                      onTap: _selected.isEmpty ? null : _confirmDeleteSelected,
                      destructive: true,
                    ),
                    SelectionAction(
                      icon: Icons.folder_off_outlined,
                      label: 'Keluarkan',
                      onTap: _selected.isEmpty ? null : _keluarkanSelected,
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

class _ActionButtonsRow extends StatelessWidget {
  final ReportFolder folder;
  final ValueChanged<bool>? onFabVisibilityChanged;
  const _ActionButtonsRow({required this.folder, this.onFabVisibilityChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ActionChip(
            icon: Icons.note_add_outlined,
            label: 'Buat Laporan',
            onTap: () => showBuatLaporanSheet(
              context,
              folderId: folder.id,
              onFabVisibilityChanged: onFabVisibilityChanged,
            ),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.playlist_add_rounded,
            label: 'Tambah Laporan',
            onTap: () => showAddRecentRecordsSheet(context, folderId: folder.id),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.drive_file_rename_outline_rounded,
            label: 'Ubah Nama',
            onTap: () => showFolderFormSheet(context, existing: folder),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: cs.primary),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
