import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/prayer_achievements_service.dart';
import '../services/prayer_log.dart';
import '../services/prayer_service.dart';

/// A standalone follow-up dashboard that consumes the existing prayer journal.
class PrayerAchievementsPage extends StatefulWidget {
  const PrayerAchievementsPage({super.key});

  @override
  State<PrayerAchievementsPage> createState() => _PrayerAchievementsPageState();
}

class _PrayerAchievementsPageState extends State<PrayerAchievementsPage> {
  int _shift = 0;
  int get _weeklyGoal =>
      Store.integer('prayer_weekly_goal', 25).clamp(5, 35).toInt();

  Future<void> _editGoal() async {
    final controller = TextEditingController(text: '$_weeklyGoal');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الهدف الأسبوعي'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'عدد الصلوات المسجلة (٥–٣٥)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, int.tryParse(controller.text)),
              child: const Text('حفظ')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (value < 5 || value > 35) {
      if (mounted) toast(context, 'اختر هدفًا من ٥ إلى ٣٥ صلاة أسبوعيًا');
      return;
    }
    await Store.setInt('prayer_weekly_goal', value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final displayed = DateTime(today.year, today.month, today.day + _shift);
    final week = PrayerAchievementsService.summary(today, 7);
    final month = PrayerAchievementsService.summary(today, 30);
    final yearDays = DateTime(today.year, today.month, today.day)
            .difference(DateTime(today.year, 1, 1))
            .inDays +
        1;
    final year = PrayerAchievementsService.summary(today, yearDays);
    final badges = PrayerAchievementsService.badges(today);
    final cs = Theme.of(context).colorScheme;

    Widget stat(String title, Map<String, dynamic> data) => Expanded(
          child: Column(children: [
            Text('${ar(((data['rate'] as double) * 100).round())}%',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: cs.primary)),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
                '${ar(data['prayers'] as int)}/${ar(data['possible'] as int)} صلاة',
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withAlpha(150))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الصلاة والإنجازات')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Text('تسجيل الصلوات الخمس',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              Row(children: [
                IconButton(
                    onPressed: () => setState(() => _shift--),
                    icon: const Icon(Icons.chevron_right)),
                Expanded(
                    child: Text(_shift == 0 ? 'اليوم' : fmtDate(displayed),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed:
                        _shift >= 0 ? null : () => setState(() => _shift++),
                    icon: const Icon(Icons.chevron_left)),
              ]),
              for (final prayer in fardPrayers)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(prayerAr[prayer]!),
                  value: PrayerLog.done(displayed, prayer),
                  onChanged: _shift > 0
                      ? null
                      : (_) async {
                          await PrayerLog.toggle(displayed, prayer);
                          if (mounted) setState(() {});
                        },
                ),
            ])),
        const SectionTitle('إحصاءات الالتزام'),
        Panel(
            child: Row(children: [
          stat('آخر ٧ أيام', week),
          stat('آخر ٣٠ يومًا', month)
        ])),
        const SizedBox(height: 10),
        Panel(child: Row(children: [stat('من بداية السنة', year)])),
        const SizedBox(height: 10),
        Panel(
            child: Column(children: [
          Row(children: [
            Expanded(
                child: Text('الهدف الأسبوعي: ${ar(_weeklyGoal)} صلاة',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
                tooltip: 'تعديل الهدف',
                onPressed: _editGoal,
                icon: const Icon(Icons.edit_outlined)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: ((week['prayers'] as int) / _weeklyGoal)
                  .clamp(0.0, 1.0)
                  .toDouble()),
          const SizedBox(height: 8),
          Text(
              '${ar(week['activeDays'] as int)} أيام موثقة • ${ar(week['completeDays'] as int)} أيام اكتملت فيها الصلوات الخمس'),
          const SizedBox(height: 8),
          Text('سلسلة الالتزام الكامل: ${ar(PrayerLog.streak(today))} يوم',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ])),
        const SectionTitle('الشارات المكتسبة'),
        Panel(
            child: badges.isEmpty
                ? const Text('ابدأ بتسجيل صلواتك لتظهر هنا إنجازاتك.',
                    textAlign: TextAlign.center)
                : Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final badge in badges)
                      Chip(
                          avatar: const Icon(Icons.verified_rounded,
                              color: gold, size: 18),
                          label: Text(badge)),
                  ])),
        const SizedBox(height: 8),
        Text(
            'الإحصاءات والشارات مشتقة من سجل الصلاة المحلي فقط؛ التسبيح لا يُحتسب ضمن streak الصلاة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: cs.onSurface.withAlpha(145))),
      ]),
    );
  }
}
