import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'art.dart';
import 'theme.dart';
import '../services/favorites.dart';

/// Rounded, accessible icon treatment shared by feature shortcuts and menus.
class SakinaIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double iconSize;
  final String? semanticLabel;
  const SakinaIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 48,
    this.iconSize = 23,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [tint.withAlpha(40), tint.withAlpha(16)],
          ),
          borderRadius: BorderRadius.circular(size * .36),
          border: Border.all(color: tint.withAlpha(34)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: tint, size: iconSize),
      ),
    );
  }
}

/// بطاقة موحّدة بظل ناعم وحواف مريحة.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(radiusCard);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                    color: const Color(0xFF3A2E12).withAlpha(14),
                    blurRadius: 18,
                    offset: const Offset(0, 6)),
              ],
      ),
      child: Material(
        color: color ?? cs.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                  color: dark
                      ? Colors.white.withAlpha(18)
                      : const Color(0xFFEADFC6).withAlpha(150)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        child: Row(children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CustomPaint(painter: _MiniStarPainter())),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

class _MiniStarPainter extends CustomPainter {
  const _MiniStarPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(starPath(size.center(Offset.zero), size.width / 2),
        Paint()..color = gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// رأس صفحة بتدرج لوني وزخرفة هندسية، ومئذنة اختيارية في الأسفل.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final bool skyline;
  const HeroCard(
      {super.key,
      required this.child,
      this.skyline = false,
      this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 0)});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusLarge),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.lerp(cs.primary, Colors.white, .06)!,
            Color.lerp(cs.primary, Colors.black, .5)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: cs.primary.withAlpha(80),
              blurRadius: 24,
              offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusLarge),
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(
                painter: GeoPatternPainter(color: Colors.white.withAlpha(13))),
          ),
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: gold.withAlpha(26)),
            ),
          ),
          if (skyline)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 92,
              child: CustomPaint(
                  painter: SkylinePainter(color: Colors.white.withAlpha(30))),
            ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ]),
      ),
    );
  }
}

/// تبويبات حبوب (سورة / صفحة / جزء …) بنفس روح المراجع.
class PillTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const PillTabs(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? Colors.white.withAlpha(16) : cs.primary.withAlpha(22);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration:
          BoxDecoration(color: track, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        for (int i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              label: labels[i],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: i == index
                              ? cs.onPrimary
                              : cs.onSurface.withAlpha(170))),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class SakinaNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const SakinaNavItem(this.label, this.icon, this.activeIcon);
}

/// شريط تنقل سفلي بحواف علوية دائرية وعنصر نشط على شكل حبة.
class SakinaNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<SakinaNavItem> items;
  const SakinaNavBar(
      {super.key,
      required this.index,
      required this.onTap,
      required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF16221E) : creamCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(dark ? 70 : 18),
              blurRadius: 22,
              offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: i == index
                            ? cs.primary.withAlpha(dark ? 60 : 30)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                i == index
                                    ? items[i].activeIcon
                                    : items[i].icon,
                                size: 25,
                                color: i == index
                                    ? cs.primary
                                    : cs.onSurface.withAlpha(140)),
                            const SizedBox(height: 3),
                            Text(items[i].label,
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: i == index
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: i == index
                                        ? cs.primary
                                        : cs.onSurface.withAlpha(140))),
                          ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: gold.withAlpha(180)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    height: 1.7,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
          ]),
        ),
      );
}

/// توقيع المطور (خط صغير ورفيع).
class DeveloperSignature extends StatelessWidget {
  const DeveloperSignature({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Text('تطوير حُسْنِي',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
        ),
      );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// زر مفضلة موحّد.
class FavButton extends StatefulWidget {
  final String type, id, title, text, source;
  const FavButton({
    super.key,
    required this.type,
    required this.id,
    required this.text,
    this.title = '',
    this.source = '',
  });

  @override
  State<FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<FavButton> {
  @override
  Widget build(BuildContext context) {
    final on = Favorites.i.has(widget.type, widget.id);
    return IconButton(
      tooltip: on ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
      icon: Icon(on ? Icons.favorite : Icons.favorite_border,
          color: on ? Colors.redAccent : null),
      onPressed: () async {
        await Favorites.i.toggle(widget.type, widget.id,
            title: widget.title, text: widget.text, source: widget.source);
        if (mounted) setState(() {});
      },
    );
  }
}

Future<void> shareText(BuildContext context, String text) async {
  try {
    await Share.share('$text\n\n— تطبيق سكينة');
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) toast(context, 'تم نسخ النص');
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'تم النسخ');
}

/// صف إجراءات (نسخ / مشاركة / مفضلة) للمحتوى النصي.
class ContentActions extends StatelessWidget {
  final String type, id, text, title, source;
  const ContentActions({
    super.key,
    required this.type,
    required this.id,
    required this.text,
    this.title = '',
    this.source = '',
  });

  @override
  Widget build(BuildContext context) {
    final full = source.isEmpty ? text : '$text\n\n$source';
    return Row(children: [
      FavButton(type: type, id: id, text: text, title: title, source: source),
      IconButton(
          tooltip: 'نسخ',
          onPressed: () => copyText(context, full),
          icon: const Icon(Icons.copy_rounded)),
      IconButton(
          tooltip: 'مشاركة',
          onPressed: () => shareText(context, full),
          icon: const Icon(Icons.share_rounded)),
    ]);
  }
}

void go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// يلفّ الصفحة بـ Scaffold عند فتحها كصفحة مستقلة (وليس كتبويب).
class Standalone extends StatelessWidget {
  final bool on;
  final String title;
  final Widget child;
  const Standalone(
      {super.key, required this.on, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}
