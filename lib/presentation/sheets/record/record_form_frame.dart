import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../widgets/forms/field_decoration.dart';

/// Kerangka visual sheet laporan: ScaffoldMessenger LOKAL (snackbar tampil DI DALAM sheet, di depan),
/// tinggi sheet 90% layar, [header] tetap di atas, dan [children] di ListView yang ikut naik saat
/// keyboard muncul. Tanpa state/logic form — semua isi dikirim dari [RecordFormSheet].
class RecordFormFrame extends StatelessWidget {
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final GlobalKey<FormState> formKey;
  final Widget header;
  final List<Widget> children;

  const RecordFormFrame({
    super.key,
    required this.messengerKey,
    required this.formKey,
    required this.header,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ScaffoldMessenger(
      key: messengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // WAJIB false: tinggi sheet dan padding bawah ListView sudah dihitung manual dengan
        // mq.viewInsets.bottom; kalau default (true), tinggi keyboard terhitung 2x sehingga muncul
        // celah kosong raksasa di bawah tombol Simpan saat keyboard muncul & di-scroll.
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          // Pendekatan manual (bukan DraggableScrollableSheet, yang menghitung tinggi relatif safe area
          // dan bisa menyisakan celah di bawah): tinggi sheet dihitung dari `constraints` Scaffold ini
          // (= tinggi layar penuh berkat useRootNavigator:true), jadi presisi menempel ke y=0 sampai bawah.
          builder: (context, constraints) {
            final sheetHeight = constraints.maxHeight * 0.9;
            return Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: sheetHeight,
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).bottomSheetTheme.backgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      header,
                      Expanded(
                        // Padding bawah di SINI (bukan di padding konten ListView) sengaja mengecilkan viewport saat
                        // keyboard muncul agar field terfokus ter-scroll ke atas keyboard (Scrollable.ensureVisible).
                        // Tak bentrok dengan resizeToAvoidBottomInset=false: hanya satu tempat ini yang mengurangi viewInsets.
                        child: Padding(
                          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
                          child: Form(
                            key: formKey,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              children: children,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Kolom tanggal laporan: skin senada kolom lain (fieldDecoration), tap membuka date picker.
class RecordDateField extends StatelessWidget {
  final DateTime tanggal;
  final VoidCallback onTap;

  const RecordDateField({super.key, required this.tanggal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: fieldDecoration(
          context,
          icon: LucideIcons.calendarDays,
          label: 'Tanggal Laporan',
          accent: cs.primary,
        ).copyWith(
          suffixIcon: Icon(LucideIcons.chevronDown, color: cs.onSurfaceVariant),
        ),
        child: Text(
          DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(tanggal),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }
}
