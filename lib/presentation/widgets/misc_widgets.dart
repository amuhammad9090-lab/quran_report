import 'package:flutter/material.dart';

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
                fontSize: 12.5,
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

/// Field gabungan dropdown + ketik bebas (pakai [DropdownMenu]) — dipakai
/// buat Kelas/Halaqoh/Nama Santri: bisa pilih dari daftar, atau ketik baru.
/// Diskin biar senada sama [fieldDecoration]: ikon dalam kotak warna,
/// menu popup rounded matching card, bukan tampilan default Material.
class DropdownTypeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final List<String> options;
  final String? errorText;
  final Color? accent;

  const DropdownTypeField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.options,
    this.hint,
    this.errorText,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accent ?? cs.primary;
    return DropdownMenu<String>(
      controller: controller,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      leadingIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: FieldIcon(icon: icon, color: color, size: 34),
      ),
      trailingIcon: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
      selectedTrailingIcon:
          Icon(Icons.expand_less_rounded, color: cs.onSurfaceVariant),
      // Nggak pakai `label:` (itu yang bikin teksnya "terbang" ke atas pas
      // di-tap) — pakai hintText aja, tetap kelihatan selama kolom kosong.
      hintText: hint != null ? '$label ($hint)' : label,
      errorText: errorText,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      inputDecorationTheme: fieldDecorationTheme(context, accent: color),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Theme.of(context).cardTheme.color),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      dropdownMenuEntries:
          options.map((o) => DropdownMenuEntry(value: o, label: o)).toList(),
      onSelected: (_) {},
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
