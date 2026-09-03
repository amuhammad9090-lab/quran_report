import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/parent_note.dart';
import '../../../providers/parent_notes_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Halaman Notifikasi. Menampilkan Catatan dari Orang Tua yang dikirim
/// lewat Portal Ortu secara live lewat [ParentNotesProvider], dan
/// menandainya "sudah dibaca" begitu guru membuka/tap catatan itu.
///
/// Swipe satu catatan atau tombol "Hapus semua" di header cuma nandain
/// field `dismissed` di Firestore (lihat dokumentasi lengkap di
/// ParentNote.dismissed soal kenapa bukan delete dokumen beneran) --
/// persis notification tray Android: swipe
/// notif cuma bersihkan tray, chat aslinya tetap ada.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  void _dismissWithUndo(BuildContext context, ParentNote note) {
    context.read<ParentNotesProvider>().dismissNote(note.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Catatan dari ${note.namaAnak} disembunyikan.'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () => context.read<ParentNotesProvider>().undismissNote(note.id),
          ),
        ),
      );
  }

  void _confirmDismissAll(BuildContext context, int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus semua notifikasi?'),
        content: Text(
          '$count catatan akan disembunyikan dari daftar ini. Catatan asli dari '
          'orang tua tetap tersimpan, tidak terhapus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              context.read<ParentNotesProvider>().dismissAll();
              Navigator.pop(ctx);
            },
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParentNotesProvider>();
    final notes = provider.notes;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Notifikasi',
              trailing: notes.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => _confirmDismissAll(context, notes.length),
                      child: const Text('Hapus semua'),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              sliver: SliverList.list(
                children: [
                  if (provider.hasError && notes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Gagal Memuat Notifikasi',
                        subtitle:
                            'Periksa koneksi internet, lalu coba lagi. Data laporan lain tidak terpengaruh.',
                      ),
                    )
                  else if (notes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Belum Ada Notifikasi',
                        subtitle:
                            'Catatan yang dikirim orang tua lewat Portal Ortu akan tampil di sini.',
                      ),
                    )
                  else
                    ...notes.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey(n.id),
                            direction: DismissDirection.horizontal,
                            background: _SwipeBackground(alignment: Alignment.centerLeft),
                            secondaryBackground: _SwipeBackground(alignment: Alignment.centerRight),
                            onDismissed: (_) => _dismissWithUndo(context, n),
                            child: _ParentNoteTile(note: n),
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Alignment alignment;
  const _SwipeBackground({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(Icons.notifications_off_rounded, color: cs.onErrorContainer, size: 20),
    );
  }
}

class _ParentNoteTile extends StatelessWidget {
  final ParentNote note;
  const _ParentNoteTile({required this.note});

  String get _initial => note.namaAnak.isNotEmpty ? note.namaAnak[0].toUpperCase() : '?';

  String _waktu(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay
        ? 'Hari ini, ${DateFormat('HH:mm', 'id_ID').format(t)}'
        : DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = !note.isRead;

    return Material(
      color: unread ? cs.primary.withValues(alpha: 0.06) : Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.read<ParentNotesProvider>().markAsRead(note);
          showDialog(context: context, builder: (_) => _ParentNoteDialog(note: note));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: unread ? cs.primary : cs.primaryContainer,
                child: Text(
                  _initial,
                  style: TextStyle(
                    color: unread ? cs.onPrimary : cs.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.namaAnak,
                            style: TextStyle(
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _waktu(note.createdAt),
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${note.kelas} • ${note.halaqoh}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog detail satu catatan orang tua — dibikin custom (bukan
/// [AlertDialog] polos) supaya pesannya tampil sebagai bubble catatan,
/// bukan cuma teks lepas di tengah dialog.
class _ParentNoteDialog extends StatelessWidget {
  final ParentNote note;
  const _ParentNoteDialog({required this.note});

  String get _initial => note.namaAnak.isNotEmpty ? note.namaAnak[0].toUpperCase() : '?';

  String get _waktuLengkap {
    final t = note.createdAt;
    if (t == null) return '';
    return DateFormat('EEEE, d MMMM yyyy • HH:mm', 'id_ID').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    _initial,
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catatan dari Orang Tua',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        note.namaAnak,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${note.kelas} • ${note.halaqoh}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                note.message,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ),
            if (_waktuLengkap.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _waktuLengkap,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
