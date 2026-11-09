import 'dart:async';
import 'package:flutter/material.dart';
import '../core/art.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/noor_service.dart';
import '../services/prayer_service.dart';
import '../services/activity_service.dart';
import '../services/audio_controller.dart';
import '../services/khatma_store.dart';
import '../data/surahs.dart';
import 'prayer_page.dart';
import 'quran_game/services/quran_game_service.dart';
import 'adhan_settings_page.dart';
import 'azkar_page.dart';
import 'calendar_page.dart';
import 'city_picker.dart';
import 'khatma_page.dart';
import 'noor_page.dart';
import 'permission_banner.dart';
import 'qibla_page.dart';
import 'tasbeeh_page.dart';
import 'quran_page.dart';
import 'daily_assistant_page.dart';
import 'more_page.dart';
import 'quran_game/pages/quran_game_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _t;
  static const _shortcutIds = [
    'quran',
    'azkar',
    'tasbeeh',
    'qibla',
    'khatma',
    'calendar',
    'prayer',
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _greeting(DateTime now) {
    final n = Settings.i.userName.trim();
    final g = now.hour < 12
        ? 'صباح الخير'
        : (now.hour < 17 ? 'نهارك سعيد' : 'مساء الخير');
    return n.isEmpty ? '$g، السلام عليكم' : '$g يا $n';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.i,
      builder: (context, _) {
        final now = cairoNow();
        final today = DateTime(now.year, now.month, now.day);
        final day = PrayerService.forDate(today);
        final next = PrayerService.next(now);
        final cur = PrayerService.current(now);
        final s = Settings.i;
        final adhanOn = s.adhanOn && s.notificationsOn;
        final noor = NoorService.forDay(today);
        final journey = ActivityService.journey;
        final storedRead = Store.json('lastread');
        final lastReadSurah = journey['lastSurah'] is num
            ? (journey['lastSurah'] as num).toInt()
            : (storedRead is Map && storedRead['s'] is num
                ? (storedRead['s'] as num).toInt()
                : null);
        final lastReadAyah = journey['lastAyah'] is num
            ? (journey['lastAyah'] as num).toInt()
            : (storedRead is Map && storedRead['ayah'] is num
                ? (storedRead['ayah'] as num).toInt()
                : null);
        final listeningSurah = AudioCtl.i.surah.value;
        final khatmaPlan = KhatmaStore.plan();
        final completedWird = [
          ActivityService.completed('quran'),
          ActivityService.completed('azkar'),
          ActivityService.tasbeehGoalReached(),
        ].where((done) => done).length;

        final cs = Theme.of(context).colorScheme;
        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const PermissionBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Panel(
              onTap: () => go(context, const QuranGamePage()),
              color: Color.alphaBlend(
                  gold.withAlpha(28), Theme.of(context).colorScheme.surface),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                          colors: [Color(0xFFB98B45), Color(0xFFE6C77A)])),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Color(0xFF173A36), size: 27),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('أكمل الآية',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15.5)),
                      SizedBox(height: 3),
                      Text(
                          QuranGameService.dailyDone
                              ? 'تحدي اليوم مكتمل • ${ar(QuranGameService.dailyChallenges)} تحديًا إجمالًا'
                              : 'تحدي اليوم متاح • ${ar(QuranGameService.dailyChallenges)} تحديًا مكتملًا',
                          style: TextStyle(fontSize: 12.5)),
                    ])),
                const Icon(Icons.chevron_left_rounded, color: goldDeep),
              ]),
            ),
          ),
          HeroCard(
            skyline: true,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(_greeting(now),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                _GlassChip(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: gold,
                  label: '${ar(ActivityService.currentStreak)} يوم',
                  onTap: () => go(context, const DailyAssistantPage()),
                ),
              ]),
              const SizedBox(height: 4),
              Text('${fmtHijri(today)}  •  ${fmtDate(today)}',
                  style: TextStyle(
                      color: Colors.white.withAlpha(215), fontSize: 12.5)),
              const SizedBox(height: 18),
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(30),
                      border: Border.all(color: Colors.white.withAlpha(46))),
                  child: Center(
                      child: PrayerGlyph(
                          prayer: next.prayer, size: 28, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      cur == null
                          ? 'لا توجد صلاة حالية'
                          : 'الصلاة الحالية: ${prayerAr[cur]!}',
                      style: TextStyle(
                          color: Colors.white.withAlpha(200), fontSize: 12.5)),
                  Text(prayerAr[next.prayer]!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ]),
              ]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtDur(next.at.difference(now)),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('عند ${fmtTime(next.at)}',
                      style: const TextStyle(
                          color: gold, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _GlassChip(
                  icon: Icons.location_on_rounded,
                  iconColor: gold,
                  label: s.cityName,
                  onTap: () => go(context, const CityPickerPage()),
                ),
                _GlassChip(
                  icon: adhanOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  label: adhanOn ? 'الأذان مفعّل' : 'الأذان متوقف',
                  onTap: () => go(context, const AdhanSettingsPage()),
                ),
              ]),
              const SizedBox(height: 58),
            ]),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Panel(
                  onTap: () => go(context, const DailyAssistantPage()),
                  color: Color.alphaBlend(gold.withAlpha(30),
                      Theme.of(context).colorScheme.surface),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: gold.withAlpha(46)),
                      child: const Icon(Icons.local_fire_department_rounded,
                          color: goldDeep, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('رحلتك مع سكينة',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15.5)),
                          const SizedBox(height: 2),
                          Text(
                              'سلسلة ${ar(ActivityService.currentStreak)} يوم • افتح برنامجك اليومي',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurface.withAlpha(165)))
                        ])),
                    Icon(Icons.chevron_left_rounded, color: goldDeep)
                  ]))),
          const SectionTitle('مواقيت اليوم'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Panel(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(children: [
                for (final p in Prayer.values)
                  _row(context, p, day.t[p]!, p == next.prayer, p == cur),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Panel(
              color: Color.alphaBlend(cs.primary.withAlpha(18),
                  Theme.of(context).colorScheme.surface),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      SakinaIconBadge(
                          icon: Icons.auto_awesome_rounded,
                          color: cs.primary,
                          size: 42,
                          iconSize: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('وردك اليوم',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                      Text('اليوم',
                          style: TextStyle(
                              color: cs.onSurface.withAlpha(135),
                              fontSize: 12)),
                    ]),
                    const SizedBox(height: 14),
                    Text('${ar(completedWird)} من ٣ مهام مسجلة'),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: completedWird / 3, minHeight: 8),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      _WirdItem(
                          icon: Icons.menu_book_rounded,
                          label: 'القرآن',
                          done: ActivityService.completed('quran')),
                      _WirdItem(
                          icon: Icons.wb_sunny_outlined,
                          label: 'الأذكار',
                          done: ActivityService.completed('azkar')),
                      _WirdItem(
                          icon: Icons.touch_app_rounded,
                          label: 'التسبيح',
                          done: ActivityService.tasbeehGoalReached()),
                    ]),
                    const SizedBox(height: 12),
                    if (lastReadSurah != null &&
                        lastReadSurah >= 1 &&
                        lastReadSurah <= surahs.length)
                      _HomeInfoTile(
                        icon: Icons.history_edu_rounded,
                        text:
                            'آخر قراءة: ${surahs[lastReadSurah - 1].name}${lastReadAyah == null ? '' : ' • آية ${ar(lastReadAyah)}'}',
                        onTap: () =>
                            go(context, const QuranPage(standalone: true)),
                      ),
                    if (listeningSurah != null &&
                        listeningSurah >= 1 &&
                        listeningSurah <= surahs.length)
                      _HomeInfoTile(
                        icon: Icons.headphones_rounded,
                        text:
                            'آخر سورة استمعت إليها: ${surahs[listeningSurah - 1].name}',
                        onTap: () =>
                            go(context, const QuranPage(standalone: true)),
                      ),
                    if (khatmaPlan != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.flag_rounded, size: 18),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(
                                'تقدم الختمة: ${ar(KhatmaStore.pagesRead(khatmaPlan))} من ${ar(604)} صفحة',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        Text(
                            '${KhatmaStore.pagesRead(khatmaPlan) * 100 ~/ 604}%'),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                              value: KhatmaStore.pagesRead(khatmaPlan) / 604,
                              minHeight: 7)),
                    ],
                  ]),
            ),
          ),
          SectionTitle(
            'وصول سريع',
            trailing: Wrap(children: [
              IconButton(
                tooltip: 'ترتيب الاختصارات',
                onPressed: _customizeShortcuts,
                icon: const Icon(Icons.tune_rounded),
              ),
              TextButton(
                onPressed: () => go(context, const MorePage()),
                child: const Text('كل الأدوات'),
              ),
            ]),
          ),
          _shortcuts(context),
          const SectionTitle('نور يومك'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Panel(
              onTap: () => go(context, const NoorPage()),
              padding: EdgeInsets.zero,
              child: Stack(children: [
                Positioned(
                  left: -18,
                  bottom: -18,
                  child: Opacity(
                    opacity: .10,
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(painter: _SolidStarPainter(gold)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          SakinaIconBadge(
                              icon: Icons.wb_twilight_rounded,
                              color: tintGold,
                              size: 34,
                              iconSize: 19),
                          const SizedBox(width: 8),
                          Text(noor.label,
                              style: const TextStyle(
                                  color: goldDeep,
                                  fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 12),
                        Text(noor.text,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17,
                                height: 1.9,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(noor.sourceLine,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurface.withAlpha(150))),
                        ContentActions(
                            type: noor.favType,
                            id: noor.id,
                            text: noor.text,
                            source: noor.sourceLine),
                      ]),
                ),
              ]),
            ),
          ),
          const DeveloperSignature(),
        ]);
      },
    );
  }

  Widget _row(
      BuildContext context, Prayer p, DateTime t, bool isNext, bool isCur) {
    final cs = Theme.of(context).colorScheme;
    final s = Settings.i;
    final isFard = p != Prayer.sunrise;
    final fg = isNext ? Colors.white : null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isNext
            ? cs.primary
            : (isCur ? cs.primary.withAlpha(20) : Colors.transparent),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color:
                isNext ? Colors.white.withAlpha(36) : cs.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
              child: PrayerGlyph(
                  prayer: p,
                  size: 26,
                  color: isNext ? Colors.white : cs.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(prayerAr[p]!,
                style: TextStyle(
                    fontSize: 16,
                    color: fg,
                    fontWeight:
                        isNext || isCur ? FontWeight.w900 : FontWeight.w700))),
        Text(fmtTime(t),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 4),
        if (isFard)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'تشغيل/إيقاف الأذان',
            icon: Icon(
                s.adhanFor(p.name)
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                size: 21,
                color: isNext
                    ? Colors.white
                    : (s.adhanFor(p.name)
                        ? cs.primary
                        : cs.onSurface.withAlpha(90))),
            onPressed: () => s.set('adhan_${p.name}', !s.adhanFor(p.name)),
          )
        else
          const SizedBox(width: 40),
      ]),
    );
  }

  Widget _shortcuts(BuildContext context) {
    final byId = <String, (String, IconData, Widget, Color)>{
      'quran': (
        'القرآن',
        Icons.menu_book_rounded,
        const QuranPage(standalone: true),
        tintGreen
      ),
      'azkar': (
        'الأذكار',
        Icons.auto_awesome_rounded,
        const AzkarPage(standalone: true),
        tintOrange
      ),
      'tasbeeh': (
        'المسبحة',
        Icons.touch_app_rounded,
        const TasbeehPage(),
        tintPurple
      ),
      'qibla': ('القبلة', Icons.explore_rounded, const QiblaPage(), tintBlue),
      'khatma': ('الختمة', Icons.flag_rounded, const KhatmaPage(), tintRose),
      'calendar': (
        'التقويم',
        Icons.calendar_month_rounded,
        const CalendarPage(),
        tintGold
      ),
      'prayer': ('الصلاة', Icons.mosque_rounded, const PrayerPage(), tintBlue),
    };
    final saved = Store.json('home_shortcut_order', _shortcutIds);
    final order = saved is List
        ? saved.map((id) => '$id').where(byId.containsKey).toList()
        : <String>[];
    for (final id in _shortcutIds) {
      if (!order.contains(id)) order.add(id);
    }
    final items = order.map((id) => byId[id]!).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
        children: [
          for (final it in items)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => go(context, it.$3),
              child: Panel(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SakinaIconBadge(
                          icon: it.$2,
                          color: it.$4,
                          size: 52,
                          iconSize: 26,
                          semanticLabel: it.$1),
                      const SizedBox(height: 9),
                      Text(it.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _customizeShortcuts() async {
    final saved = Store.json('home_shortcut_order', _shortcutIds);
    final order = saved is List
        ? saved.map((id) => '$id').where(_shortcutIds.contains).toList()
        : <String>[];
    for (final id in _shortcutIds) {
      if (!order.contains(id)) order.add(id);
    }
    final labels = <String, String>{
      'quran': 'القرآن',
      'azkar': 'الأذكار',
      'tasbeeh': 'المسبحة',
      'qibla': 'القبلة',
      'khatma': 'الختمة',
      'calendar': 'التقويم',
      'prayer': 'الصلاة',
    };
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('ترتيب اختصارات الرئيسية'),
          content: SizedBox(
            width: 360,
            height: 380,
            child: ReorderableListView(
              onReorderItem: (oldIndex, newIndex) => refresh(() {
                final item = order.removeAt(oldIndex);
                order.insert(newIndex, item);
              }),
              children: [
                for (final id in order)
                  ListTile(
                    key: ValueKey(id),
                    leading: const Icon(Icons.drag_handle_rounded),
                    title: Text(labels[id]!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, _shortcutIds),
                child: const Text('الترتيب الافتراضي')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, order),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (result == null) return;
    await Store.setJson('home_shortcut_order', result);
    if (mounted) setState(() {});
  }
}

class _WirdItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  const _WirdItem(
      {required this.icon, required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(done ? Icons.check_circle_rounded : icon,
              size: 18, color: done ? cs.primary : cs.onSurface.withAlpha(120)),
          const SizedBox(width: 5),
          Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withAlpha(done ? 210 : 150)))),
        ]),
        Text(done ? 'تم تسجيله' : 'لم يُسجّل',
            style: TextStyle(fontSize: 10, color: cs.onSurface.withAlpha(140))),
      ]),
    );
  }
}

class _HomeInfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _HomeInfoTile(
      {required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      );
}

/// شريحة زجاجية شفافة فوق الهيرو.
class _GlassChip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;
  const _GlassChip(
      {required this.icon,
      this.iconColor,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(30),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withAlpha(42))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: iconColor ?? Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _SolidStarPainter extends CustomPainter {
  final Color color;
  const _SolidStarPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(starPath(size.center(Offset.zero), size.width / 2),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SolidStarPainter old) => old.color != color;
}
