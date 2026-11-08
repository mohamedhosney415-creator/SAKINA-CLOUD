import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/prayer_service.dart';

/// رسومات متجهية مرسومة بالكود (بدون ملفات صور)، فتتبع لون التطبيق
/// والوضع الداكن وتبقى حادة على كل أحجام الشاشات.

/// مسار هلال.
Path crescentPath(Offset c, double r) {
  final outer = Path()..addOval(Rect.fromCircle(center: c, radius: r));
  final cut = Path()
    ..addOval(Rect.fromCircle(
        center: c.translate(r * .42, -r * .12), radius: r * .86));
  return Path.combine(PathOperation.difference, outer, cut);
}

/// مسار نجمة متعددة الأضلاع (ثمانية افتراضيًا — الشكل الإسلامي الكلاسيكي).
Path starPath(Offset c, double outer,
    {int points = 8, double inner = .62, double rotation = -math.pi / 2}) {
  final path = Path();
  final n = points * 2;
  for (int i = 0; i < n; i++) {
    final r = i.isEven ? outer : outer * inner;
    final a = rotation + math.pi * i / points;
    final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  return path..close();
}

/// خط سماء مسجد: قبة مركزية ومئذنتان وقبتان جانبيتان.
class SkylinePainter extends CustomPainter {
  final Color color;
  const SkylinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = color;

    void dome(double cx, double r, double baseY) {
      final path = Path()
        ..moveTo(cx - r, baseY)
        ..arcTo(Rect.fromCircle(center: Offset(cx, baseY), radius: r), math.pi,
            math.pi, false)
        ..close();
      canvas.drawPath(path, fill);
      final tip = baseY - r;
      canvas.drawRect(Rect.fromLTWH(cx - 1, tip - r * .38, 2, r * .38), fill);
      canvas.drawCircle(Offset(cx, tip - r * .42), r * .09, fill);
    }

    void minaret(double cx, double width, double top) {
      canvas.drawRect(Rect.fromLTWH(cx - width / 2, top, width, h - top), fill);
      canvas.drawRect(
          Rect.fromLTWH(cx - width * .85, top + (h - top) * .2, width * 1.7, 3),
          fill);
      final cap = Path()
        ..moveTo(cx - width * .8, top)
        ..quadraticBezierTo(cx, top - width * 2.8, cx + width * .8, top)
        ..close();
      canvas.drawPath(cap, fill);
    }

    final cx = w * .5;
    final r = h * .36;
    final centerBase = h * .6;
    // الجسم الرئيسي والقبة المركزية
    canvas.drawRect(
        Rect.fromLTWH(cx - r * 1.05, centerBase, r * 2.1, h - centerBase), fill);
    dome(cx, r, centerBase);
    // القبتان الجانبيتان
    final r2 = r * .52;
    final sideBase = h * .76;
    for (final dx in [-1.0, 1.0]) {
      final sx = cx + dx * r * 1.6;
      canvas.drawRect(
          Rect.fromLTWH(sx - r2, sideBase, r2 * 2, h - sideBase), fill);
      dome(sx, r2, sideBase);
    }
    // المئذنتان
    final mw = math.max(4.0, w * .018);
    minaret(cx - w * .3, mw, h * .22);
    minaret(cx + w * .3, mw, h * .22);
    // الأرض
    canvas.drawRect(Rect.fromLTWH(0, h * .92, w, h * .08), fill);
  }

  @override
  bool shouldRepaint(covariant SkylinePainter old) => old.color != color;
}

/// نجوم متناثرة بشكل ثابت (نفس الموضع في كل رسم).
class StarsPainter extends CustomPainter {
  final Color color;
  final int count;
  const StarsPainter({required this.color, this.count = 36});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (int i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = .6 + rnd.nextDouble() * 1.4;
      final a = 40 + rnd.nextInt(160);
      canvas.drawCircle(Offset(x, y), r, Paint()..color = color.withAlpha(a));
    }
  }

  @override
  bool shouldRepaint(covariant StarsPainter old) =>
      old.color != color || old.count != count;
}

/// زخرفة هندسية خفيفة من نجوم ثمانية متراصة كالطوب.
class GeoPatternPainter extends CustomPainter {
  final Color color;
  final double cell;
  const GeoPatternPainter({required this.color, this.cell = 46});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    int row = 0;
    for (double y = 0; y < size.height + cell; y += cell * .8) {
      final shift = row.isEven ? 0.0 : cell / 2;
      for (double x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + shift, y);
        canvas.drawPath(starPath(c, cell * .34), p);
        canvas.drawCircle(c, cell * .07, p);
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant GeoPatternPainter old) =>
      old.color != color || old.cell != cell;
}

/// شارة نجمة ثمانية بداخلها رقم أو نص (أرقام السور مثلًا).
class StarBadge extends StatelessWidget {
  final String label;
  final double size;
  final Color? color;
  const StarBadge(
      {super.key, required this.label, this.size = 44, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarBadgePainter(tint),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: size * .3,
                  fontWeight: FontWeight.w800,
                  color: tint)),
        ),
      ),
    );
  }
}

class _StarBadgePainter extends CustomPainter {
  final Color color;
  _StarBadgePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = starPath(c, size.width / 2 - 1, inner: .78);
    canvas.drawPath(path, Paint()..color = color.withAlpha(24));
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _StarBadgePainter old) => old.color != color;
}

/// أيقونة مرسومة لكل صلاة (فجر، شروق، ظهر، عصر، مغرب، عشاء).
class PrayerGlyph extends StatelessWidget {
  final Prayer prayer;
  final double size;
  final Color? color;
  const PrayerGlyph(
      {super.key, required this.prayer, this.size = 26, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(prayer, tint),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final Prayer prayer;
  final Color color;
  _GlyphPainter(this.prayer, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .075
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;

    void rays(Offset o, double r1, double r2, double start, double sweep,
        int count) {
      for (int i = 0; i < count; i++) {
        final a = count == 1 ? start : start + sweep * i / (count - 1);
        canvas.drawLine(
            Offset(o.dx + r1 * math.cos(a), o.dy + r1 * math.sin(a)),
            Offset(o.dx + r2 * math.cos(a), o.dy + r2 * math.sin(a)),
            line);
      }
    }

    void halfSun(Offset o, double r) {
      final path = Path()
        ..moveTo(o.dx - r, o.dy)
        ..arcTo(Rect.fromCircle(center: o, radius: r), math.pi, math.pi, false)
        ..close();
      canvas.drawPath(path, fill);
    }

    void horizon(double y, [double from = .12, double to = .88]) =>
        canvas.drawLine(Offset(s * from, y), Offset(s * to, y), line);

    switch (prayer) {
      case Prayer.fajr:
        final o = Offset(s * .5, s * .68);
        halfSun(o, s * .2);
        rays(o, s * .29, s * .39, math.pi * 1.15, math.pi * .7, 5);
        horizon(s * .68);
        canvas.drawPath(
            starPath(Offset(s * .2, s * .22), s * .08, points: 4, inner: .4),
            fill);
        break;
      case Prayer.sunrise:
        final o = Offset(s * .5, s * .66);
        halfSun(o, s * .25);
        rays(o, s * .34, s * .45, math.pi * 1.1, math.pi * .8, 7);
        horizon(s * .66);
        break;
      case Prayer.dhuhr:
        final o = Offset(s * .5, s * .5);
        canvas.drawCircle(o, s * .17, fill);
        rays(o, s * .28, s * .4, 0, math.pi * 2 * 7 / 8, 8);
        break;
      case Prayer.asr:
        final o = Offset(s * .62, s * .36);
        canvas.drawCircle(o, s * .14, fill);
        rays(o, s * .23, s * .33, 0, math.pi * 2 * 7 / 8, 8);
        final cloud = Paint()..color = color.withAlpha(170);
        canvas.drawCircle(Offset(s * .3, s * .7), s * .12, cloud);
        canvas.drawCircle(Offset(s * .46, s * .64), s * .16, cloud);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTRB(s * .18, s * .7, s * .66, s * .82),
                Radius.circular(s * .06)),
            cloud);
        break;
      case Prayer.maghrib:
        final o = Offset(s * .5, s * .6);
        halfSun(o, s * .22);
        rays(o, s * .3, s * .4, math.pi * 1.2, math.pi * .6, 3);
        horizon(s * .6);
        canvas.drawLine(Offset(s * .26, s * .74), Offset(s * .74, s * .74), line);
        canvas.drawLine(Offset(s * .38, s * .86), Offset(s * .62, s * .86), line);
        break;
      case Prayer.isha:
        canvas.drawPath(crescentPath(Offset(s * .46, s * .52), s * .3), fill);
        canvas.drawPath(
            starPath(Offset(s * .76, s * .3), s * .1, points: 4, inner: .4),
            fill);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.prayer != prayer || old.color != color;
}
