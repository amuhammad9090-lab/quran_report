import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/folder.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/folders_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/record_card.dart';
import '../export/export_sheet.dart';
import '../record_form/record_form_sheet.dart';
import 'add_recent_records_sheet.dart';
import 'folder_form_sheet.dart';

/// Halaman isi satu folder — daftar laporan di dalamnya (bisa diedit/dihapus
/// seperti biasa), plus tombol buat laporan baru langsung dalam folder ini,
/// tambah laporan yang sudah ada, ubah nama, dan ekspor.
class FolderDetailScreen extends StatelessWidget {
  final String folderId;
  const FolderDetailScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context) {
    final foldersProvider = context.watch<FoldersProvider>();
    final folder = foldersProvider.byId(folderId);

    // Folder bisa saja baru saja dihapus dari sheet aksi lain — kalau
    // sudah tidak ada, tutup halaman ini otomatis.
    if (folder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final recordsProvider = context.watch<RecordsProvider>();
    final records = recordsProvider.recordsInFolder(folderId);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(title: folder.nama, subtitle: '${records.length} laporan'),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _ActionButtonsRow(folder: folder, records: records),
              ),
            ),
            if (records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: 'Folder ini masih kosong',
                  subtitle: 'Buat laporan baru atau tambahkan laporan yang sudah ada.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                sliver: SliverList.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = records[i];
                    return RecordCard(
                      record: r,
                      onEdit: () => showRecordFormSheet(context, existing: r),
                      onDelete: () => _confirmDelete(context, r.id),
                      onPindahkanKeFolder: () => recordsProvider.moveToFolder(r.id, null),
                      pindahkanLabel: 'Keluarkan dari Folder',
                      pindahkanIcon: Icons.folder_off_outlined,
                    );
                  },
                ),
              ),
          ],
        ),
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

class _ActionButtonsRow extends StatelessWidget {
  final ReportFolder folder;
  final List<SantriRecord> records;
  const _ActionButtonsRow({required this.folder, required this.records});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ActionChip(
            icon: Icons.note_add_rounded,
            label: 'Buat Laporan',
            onTap: () => showRecordFormSheet(context, initialFolderId: folder.id),
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
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.ios_share_rounded,
            label: 'Ekspor',
            onTap: () => showExportSheet(
              context,
              records: records,
              judul: folder.nama,
            ),
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
