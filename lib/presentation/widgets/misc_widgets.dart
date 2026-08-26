import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Kotak ikon bertinta lembut — satu-satunya sumber gaya "ikon dalam kotak
/// warna soft" yang dipakai di SELURUH aplikasi (Home, form laporan,
/// pengaturan, tentang aplikasi). Jangan bikin versi manual lain di file
/// screen, biar seragam.
class SoftIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final double padding;
  final double radius;

  const SoftIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = 20,
    this.padding = 9,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.1,
                color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontSize: 11.5,
                height: 1.1,
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Ikon di dalam kotak bulat bertinta warna — dipakai sebagai leading/prefix
/// yang seragam di semua kolom form (tanggal, dropdown, input teks) biar
/// "satu bahasa desain" dari atas sampai bawah.
class FieldIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const FieldIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Dekorasi input seragam untuk semua kolom form (TextFormField &
/// DropdownButtonFormField): ikon dalam kotak warna sebagai prefix, isian
/// rounded-16 tanpa border, dengan aksen warna saat fokus/error.
InputDecoration fieldDecoration(
    BuildContext context, {
      required IconData icon,
      required String label,
      String? hint,
      String? errorText,
      Color? accent,
    }) {
  final cs = Theme.of(context).colorScheme;
  final color = accent ?? cs.primary;
  final fill = Theme.of(context).inputDecorationTheme.fillColor;
  return InputDecoration(
    // Nggak pakai labelText (itu yang bikin teks "terbang" ke atas pas
    // kolom di-tap) — pakai hintText aja, tetap kelihatan selama kosong,
    // baru ilang begitu user isi.
    hintText: hint != null ? '$label ($hint)' : label,
    errorText: errorText,
    filled: true,
    fillColor: fill,
    prefixIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: FieldIcon(icon: icon, color: color, size: 34),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 34),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.6),
    ),
  );
}

/// Versi [InputDecorationTheme] dari [fieldDecoration] — dipakai widget yang
/// minta tema, bukan instance dekorasi langsung (mis. [DropdownMenu]).
InputDecorationTheme fieldDecorationTheme(
    BuildContext context, {
      required Color accent,
    }) {
  final cs = Theme.of(context).colorScheme;
  final fill = Theme.of(context).inputDecorationTheme.fillColor;
  return InputDecorationTheme(
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    ),
  );
}

/// Field pilih-SAJA (tanpa ketik bebas sama sekali) — dipakai buat
/// Kelas/Halaqoh/Nama Santri: nilai HARUS salah satu dari [options],
/// nggak ada cara buat user mengetik teks bebas ke luar daftar itu.
/// Dipakai [DropdownButtonFormField] (bukan [DropdownMenu]) karena
/// widget itu memang murni pilih dari [items], nggak punya text-input
/// sama sekali. Diskin biar senada sama [fieldDecoration]: ikon dalam
/// kotak warna, rounded-16.
///
/// [value] dipakai sebagai `initialValue` — [DropdownButtonFormField]
/// modern nggak otomatis re-render pas [value] berubah dari luar (mis.
/// direset programatis karena kelas/halaqoh ganti). Makanya widget ini
/// SELALU dikasih `key: ValueKey(value)` oleh pemanggil (lihat
/// `record_form_sheet.dart`) biar widget-nya dibikin ulang & nilainya
/// ikut ke-refresh tiap kali value berubah dari luar.
class SelectField extends StatelessWidget {
  final String? value;
  final String label;
  final String? hint;
  final IconData icon;
  final List<String> options;
  final String? errorText;
  final Color? accent;
  final bool enabled;
  final ValueChanged<String?>? onChanged;

  const SelectField({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.options,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.accent,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accent ?? cs.primary;
    // Kalau value sekarang bukan bagian dari options (mis. kelas/halaqoh
    // baru dipilih & santri lama nggak termasuk di halaqoh itu lagi),
    // jangan kirim value asing ke DropdownButtonFormField — bisa assert
    // error. Tampilkan kosong aja (biarkan hintText yang muncul).
    final safeValue = (value != null && options.contains(value)) ? value : null;
    final isUsable = enabled && options.isNotEmpty;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      icon: Icon(Icons.expand_more_rounded,
          color: isUsable ? cs.onSurfaceVariant : cs.onSurfaceVariant.withValues(alpha: 0.4)),
      decoration: fieldDecoration(
        context,
        icon: icon,
        label: label,
        hint: hint,
        errorText: errorText,
        accent: color,
      ),
      disabledHint: hint != null
          ? Text(hint!,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
              overflow: TextOverflow.ellipsis)
          : null,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: isUsable ? onChanged : null,
    );
  }
}

/// Kartu section form (Tanggal, Identitas Santri, Status Capaian,
/// Keterangan, dst) — judul kecil + ikon di atas, konten di bawah, dibungkus
/// card senada dengan card lain di aplikasi (bukan cuma label polos).
class FormSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const FormSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Pakai Card resmi (dari cardTheme) — konsisten sama SectionCard di
    // Home dan semua card lain, bukan bikin shadow/border manual sendiri.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 7),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Kartu sambutan hijau tua di puncak Home — identitas utama halaman.
/// Opsional menampung baris aksi cepat (mis. Tambah Laporan/Ekspor Data)
/// dipisah garis tipis, meniru layout referensi desain.
class WelcomeHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? actions;
  const WelcomeHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B2E), Color(0xFF0E5C46)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            top: -6,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (actions != null) ...[
                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
                const SizedBox(height: 18),
                actions!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Item aksi cepat di dalam [WelcomeHeroCard] (mis. "Tambah Laporan").
class HeroActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const HeroActionItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoftIconBox(
                icon: icon,
                color: Colors.white,
                background: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu putih dengan judul + tautan "Lihat Semua" — bungkus untuk section
/// seperti "Ringkasan Hari Ini" dan "Kategori Cepat".
class SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Pakai widget Card resmi (dari cardTheme) — bukan Container manual —
    // biar shadow/radius-nya 100% sama dengan semua card lain di aplikasi.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                  ),
                ),
                if (onSeeAll != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSeeAll,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'Lihat Semua',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Satu item statistik polos (ikon + angka + label), dipakai berjajar
/// dengan garis pemisah tipis di dalam [SectionCard].
class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SoftIconBox(icon: icon, color: color),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Garis vertikal tipis pemisah antar [StatItem].
class VDivider extends StatelessWidget {
  const VDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 56,
      color: Theme.of(context).dividerTheme.color,
    );
  }
}

/// Kartu ringkas untuk baris "Ringkasan Hari Ini" — 3 kartu sejajar.
class SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const SummaryStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Tile grid "Kategori Cepat" — pintasan filter yang sudah didukung provider.
class CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? color : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              SoftIconBox(icon: icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu kelompok per tanggal — dipakai di halaman Detail Santri,
/// Kehadiran, dan Rekap Bulanan (Statistik). Header tanggal + jumlah item,
/// lalu baris-baris [rows] dipisah garis tipis, semuanya digabung jadi
/// SATU card per tanggal (biar "digabung" senada gaya Home, bukan card
/// bertumpuk per item).
class DateGroupCard extends StatelessWidget {
  final DateTime date;
  final List<Widget> rows;

  const DateGroupCard({super.key, required this.date, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIconBox(
                  icon: Icons.calendar_today_rounded,
                  color: cs.primary,
                  size: 14,
                  padding: 7,
                  radius: 10,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
              ],
            ),
            for (final row in rows) ...[
              Divider(height: 22, color: Theme.of(context).dividerTheme.color),
              row,
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Baris ringkas laporan tahfizh/tahsin di dalam [DateGroupCard] — dipakai
/// di halaman Detail Santri. Cukup status + capaian + keterangan, tanpa
/// nama (karena sudah dalam konteks 1 santri) dan tanpa tanggal (sudah
/// jadi header grup).
class RecordSummaryRow extends StatelessWidget {
  final IconData statusIcon;
  final Color statusColor;
  final String statusLabel;
  final String capaianText;
  final Widget keteranganChip;
  final VoidCallback? onTap;

  const RecordSummaryRow({
    super.key,
    required this.statusIcon,
    required this.statusColor,
    required this.statusLabel,
    required this.capaianText,
    required this.keteranganChip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            SoftIconBox(icon: statusIcon, color: statusColor, size: 15, padding: 7, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    capaianText,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            keteranganChip,
          ],
        ),
      ),
    );
  }
}

/// Baris ringkas 1 santri di dalam [DateGroupCard] — dipakai di halaman
/// Kehadiran (siapa hadir/izin/alpa per tanggal).
class SantriAttendanceRow extends StatelessWidget {
  final String nama;
  final String kelas;
  final String halaqoh;
  final Widget keteranganChip;
  final VoidCallback? onTap;

  const SantriAttendanceRow({
    super.key,
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    required this.keteranganChip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: cs.primaryContainer,
              child: Text(
                nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Kelas $kelas • Halaqoh $halaqoh',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            keteranganChip,
          ],
        ),
      ),
    );
  }
}

/// Header pinned seragam untuk halaman non-Home yang dibuka lewat push
/// (Daftar Santri, Detail Santri, Kehadiran, Rekap Bulanan) — tombol
/// kembali + judul + subjudul opsional, nempel di atas pas discroll,
/// senada gaya SliverAppBar pinned di Home.
class PushedPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double titleFontSize;

  const PushedPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleFontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10,
      ),
      toolbarHeight: subtitle != null ? 68 : 56,
      titleSpacing: 4,
      title: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Satu tombol aksi di dalam [SelectionActionBar] — kalau [filled] true jadi
/// tombol solid warna [destructive] error / primary, kalau enggak jadi
/// outline. Selalu dibungkus Expanded sama parent-nya biar label sepanjang
/// apapun ("Keluarkan dari Folder") nggak pernah kepotong.
class SelectionAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool filled;

  const SelectionAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.filled = false,
  });
}

class _SelectionActionButton extends StatelessWidget {
  final SelectionAction action;
  const _SelectionActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = action.destructive ? cs.error : cs.primary;
    if (action.filled) {
      return FilledButton.icon(
        onPressed: action.onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(action.icon, size: 17),
        label: Text(action.label, overflow: TextOverflow.ellipsis, maxLines: 1),
      );
    }
    return OutlinedButton.icon(
      onPressed: action.onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.4),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(action.icon, size: 17),
      label: Text(action.label, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }
}

/// Bar aksi mode pilih-banyak (centang) — dipakai di halaman Laporan &
/// Folder. Disusun 2 baris niru pola Google Photos/Files: baris atas
/// checkbox "pilih semua" + jumlah terpilih + tombol tutup (X), baris bawah
/// tombol-tombol aksi (Expanded rata) biar labelnya selalu muat, seberapa
/// pun banyak aksinya — beda dari versi lama yang semua ditumpuk 1 baris
/// sampai kepotong ("1 dipi...").
class SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final ValueChanged<bool> onSelectAllChanged;
  final VoidCallback onCancel;
  final List<SelectionAction> actions;

  const SelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAllChanged,
    required this.onCancel,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSelected = totalCount > 0 && selectedCount == totalCount;

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.18),
      color: Theme.of(context).cardTheme.color ?? cs.surface,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged: totalCount == 0 ? null : (v) => onSelectAllChanged(v ?? false),
                ),
                Expanded(
                  child: Text(
                    selectedCount == 0 ? 'Pilih Semua' : '$selectedCount dipilih',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Batal',
                  visualDensity: VisualDensity.compact,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 2),
                child: Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _SelectionActionButton(action: actions[i])),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Snackbar seragam (ikon + pesan, rounded) dipakai di seluruh app — ganti
/// [SnackBar] polos bawaan. Selalu nempel rapat (16px) di atas apapun yang
/// ada di bawahnya. Kalau layar itu punya FAB yang lagi tampil, jangan cuma
/// dikasih jarak ekstra (bikin ngambang aneh di atas FAB) — sembunyikan dulu
/// FAB-nya lewat [onFabVisibilityChanged] selama snackbar tampil, baru
/// muncul lagi begitu snackbar-nya hilang.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackbar(
    BuildContext context,
    String message, {
      IconData icon = Icons.check_circle_rounded,
      ValueChanged<bool>? onFabVisibilityChanged,
    }) {
  final cs = Theme.of(context).colorScheme;
  onFabVisibilityChanged?.call(false);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: cs.primary),
          const SizedBox(width: 10),
          Flexible(child: Text(message)),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ),
  );
  controller.closed.then((_) => onFabVisibilityChanged?.call(true));
  return controller;
}

/// Mixin buat nampilin pesan singkat (pengganti SnackBar) sebagai BAGIAN
/// dari Column konten sheet sendiri, bukan lewat ScaffoldMessenger —
/// dipakai di bottom sheet yang gak punya Scaffold sendiri (mis. export
/// sheet). `ScaffoldMessenger.of(context)` dari dalam sheet modal begitu
/// bakal nemu Scaffold HALAMAN DI BALIK sheet, jadi SnackBar-nya kegambar
/// di belakang sheet — ketutup, gak kelihatan user. Solusinya: tampilkan
/// sebagai [InlineMessageBanner] biasa, jadi bagian layout Column sheet
/// itu sendiri (otomatis selalu di depan & otomatis nggak nyisain ruang
/// kosong kalau lagi gak ada pesan, karena ukurannya ngikutin isi
/// teksnya doang — pola ini sudah kebukti jalan lebih dulu di
/// ExportSheet, lihat catatan panjang di sana). Cara pakai: campur
/// `with InlineMessageMixin<TWidget>` di State, panggil
/// [showInlineMessage], render `if (inlineMessage != null)
/// InlineMessageBanner(message: inlineMessage!)` di build().
mixin InlineMessageMixin<T extends StatefulWidget> on State<T> {
  String? inlineMessage;
  Timer? _inlineMessageTimer;

  void showInlineMessage(String message) {
    _inlineMessageTimer?.cancel();
    setState(() => inlineMessage = message);
    _inlineMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => inlineMessage = null);
    });
  }

  @override
  void dispose() {
    _inlineMessageTimer?.cancel();
    super.dispose();
  }
}

/// Banner pesan singkat inline — lihat [InlineMessageMixin].
class InlineMessageBanner extends StatelessWidget {
  final String message;
  const InlineMessageBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: cs.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// Logo SMPIT Al Madinah — ukurannya SELALU persegi (1:1) di semua
/// tempat biar konsisten. Defaultnya dibungkus kartu putih (logo aslinya
/// berwarna-warni di atas kanvas transparan, jadi butuh alas solid biar
/// kebaca di background apa pun) — kecuali [withBackground] dimatikan,
/// dipakai khusus di Splash yang background-nya sendiri sudah gradient
/// hijau dan sengaja TIDAK mau logo dikasih kotak putih lagi.
class SmpitLogoBadge extends StatelessWidget {
  final double size;
  final bool withBackground;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const SmpitLogoBadge({
    super.key,
    this.size = 56,
    this.withBackground = true,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset('assets/images/logo_smpit.png', fit: BoxFit.contain);

    if (!withBackground) {
      return SizedBox(width: size, height: size, child: logo);
    }

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: logo,
    );
  }
}

/// Icon app (mark hijau berbentuk buku + kubah masjid) — asetnya sendiri
/// sudah berupa kotak membulat (squircle) dengan sudut transparan, jadi
/// cukup ditampilkan langsung pakai [ClipRRect] tanpa dus tambahan.
class AppIconMark extends StatelessWidget {
  final double size;
  final double borderRadius;
  const AppIconMark({super.key, this.size = 84, this.borderRadius = 22});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset('assets/images/app_icon.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}

/// Satu opsi format export (PDF/Word/Excel) di bottom sheet export —
/// dipakai [ExportSheet] & [GenerateRekapBulananScreen] (dulu ke-copy
/// identik di dua tempat, sekarang cukup satu sumber di sini).
class ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const ExportOptionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris distribusi keterangan (mis. "Hadir • 12 laporan • 80%" +
/// bar progres) — dipakai [StatistikTab] & [RekapBulananScreen] (dulu
/// ke-copy identik di dua tempat, sekarang cukup satu sumber di sini).
class DistribusiRow extends StatelessWidget {
  final String label;
  final int count;
  final double ratio;
  final Color color;

  const DistribusiRow({
    super.key,
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text(
              '$count laporan • ${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}