import 'package:flutter/material.dart';

import '../../widgets/misc_widgets.dart';

/// Halaman Notifikasi. Sebelumnya bell di Home cuma nampilin snackbar
/// "Belum ada notifikasi baru" — sekarang dikasih halaman sungguhan biar
/// ada tempat nampung notifikasi beneran nanti (mis. pengingat laporan
/// belum diisi, santri baru ditambahkan, dst).
///
/// BELUM ada sumber data notifikasi asli (backend/local) — makanya di
/// sini masih statis (list kosong). Rencana ke depan: notifikasi untuk
/// user/guru bakal muncul juga sebagai push notification di app bar HP
/// (status bar), bukan cuma di halaman ini — begitu itu diimplementasi,
/// tinggal isi `_notifications` dari provider/service yang sesuai, UI
/// halaman ini tidak perlu berubah.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Placeholder — ganti dengan data asli begitu ada provider notifikasi.
  static const List<Never> _notifications = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(title: 'Notifikasi'),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              sliver: SliverList.list(
                children: [
                  if (_notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Belum Ada Notifikasi',
                        subtitle:
                            'Notifikasi seperti pengingat laporan atau pembaruan santri akan tampil di sini.',
                      ),
                    ),
                  const SizedBox(height: 24),
                  _InfoBanner(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu info kecil di bawah empty state, jelasin bahwa push notification
/// (notifikasi HP di luar app) untuk guru/admin bakal segera hadir —
/// biar user tahu ini bukan fitur mati, cuma belum ada isinya.
class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Segera hadir: notifikasi otomatis untuk guru & admin yang juga muncul langsung di status bar HP.',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
