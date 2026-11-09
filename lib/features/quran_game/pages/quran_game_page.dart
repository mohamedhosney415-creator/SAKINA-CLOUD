import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../services/audio_controller.dart';
import '../../../services/quran_service.dart';
import '../models/quran_game_question.dart';
import '../services/quran_game_service.dart';
import 'quran_game_aux_pages.dart';

/// الواجهة المستقلة للعبة: جلسة ليلية، XP، أهداف، مسار ومحطات وتنقل داخلي.
class QuranGamePage extends StatefulWidget {
  final bool embedded;
  const QuranGamePage({super.key, this.embedded = false});
  @override
  State<QuranGamePage> createState() => _QuranGamePageState();
}

class _QuranGamePageState extends State<QuranGamePage> {
  int tab = 0;
  String get selectedTheme => QuranGameService.activeTheme;
  bool get dark =>
      selectedTheme == 'night' ||
      selectedTheme == 'default' && QuranGameService.darkMode;
  Color get ink => dark
      ? const Color(0xFFF5F1E4)
      : selectedTheme == 'gold'
          ? const Color(0xFF4D3916)
          : selectedTheme == 'ramadan'
              ? const Color(0xFF173D37)
              : const Color(0xFF193B36);
  Color get muted => dark
      ? const Color(0xFFB8D2C6)
      : selectedTheme == 'gold'
          ? const Color(0xFF927443)
          : const Color(0xFF6F8980);
  Color get surface => dark
      ? const Color(0xFF1B4540)
      : selectedTheme == 'gold'
          ? const Color(0xFFFFF9E8)
          : selectedTheme == 'mushaf'
              ? const Color(0xFFFFFCF1)
              : Colors.white;
  Color get background => dark
      ? const Color(0xFF102B29)
      : selectedTheme == 'gold'
          ? const Color(0xFFF7F0DF)
          : selectedTheme == 'ramadan'
              ? const Color(0xFFECF4EE)
              : selectedTheme == 'mushaf'
                  ? const Color(0xFFF4F0E3)
                  : const Color(0xFFF6F8F5);
  List<Color> get heroColors => selectedTheme == 'gold'
      ? const [Color(0xFF5B4720), Color(0xFF9A7535)]
      : selectedTheme == 'ramadan'
          ? const [Color(0xFF14352F), Color(0xFF477A56)]
          : selectedTheme == 'mushaf'
              ? const [Color(0xFF4C3C2B), Color(0xFF7D6946)]
              : const [Color(0xFF143B36), Color(0xFF236257)];
  void open(Widget page) => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => page))
          .then((_) {
        if (mounted) setState(() {});
      });

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: background,
          colorScheme: Theme.of(context).colorScheme.copyWith(
                brightness: dark ? Brightness.dark : Brightness.light,
                surface: surface,
                onSurface: ink,
              ),
        ),
        child: Scaffold(
          backgroundColor: background,
          body: Column(
            children: [
              if (widget.embedded) _embeddedTabs(),
              Expanded(child: SafeArea(child: _body())),
            ],
          ),
          bottomNavigationBar: widget.embedded ? null : _bottomNav(),
        ),
      );

  Widget _body() {
    if (tab == 1) return _pathPage();
    if (tab == 2) return _achievementsPreview();
    if (tab == 3) return _accountPage();
    return _homePage();
  }

  Widget _homePage() => ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(),
          _dailyGoal(),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 10, 17, 0),
            child: Panel(
              onTap: QuranGameService.dailyDone
                  ? null
                  : () => open(const QuranGameQuizPage(daily: true)),
              child: Row(
                children: [
                  const Icon(Icons.today_rounded, color: goldDeep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      QuranGameService.dailyDone
                          ? 'اكتمل تحدي اليوم'
                          : 'ابدأ تحدي اليوم المستقل',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    QuranGameService.dailyDone
                        ? 'مكتمل ✓'
                        : '+${QuranGameConfig.dailyBonus} نور ✨',
                  ),
                ],
              ),
            ),
          ),
          _sectionTitle(
            'سلسلتك الأسبوعية',
            '🔥 ${QuranGameService.streak} أيام متتالية',
          ),
          _weeklyStreak(),
          _sectionTitle('خريطة المستويات', 'المستوى ${QuranGameService.level} من ${QuranGameService.maximumAvailableLevel}'),
          _mapCard(compact: true),
          _sectionTitle('وصول سريع', 'كل أدواتك'),
          _quickTools(),
          const SizedBox(height: 20),
        ],
      );

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 23),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: heroColors,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gold.withAlpha(210),
                  ),
                  child: const Center(
                    child: Text('📖', style: TextStyle(fontSize: 21)),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مساء النور، يا بطل',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      'مسابقة سكينة الإسلامية',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _headerIcon(Icons.notifications_none_rounded),
                const SizedBox(width: 7),
                _headerIcon(
                  dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                  onTap: () async {
                    await QuranGameService.setDarkMode(!dark);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'جاهز لجولة جديدة؟',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أكمل ${QuranGameService.currentLevelQuestionCount} أسئلة في المستوى لتحصل على النجوم.',
                        style: TextStyle(
                          color: Colors.white.withAlpha(205),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 78,
                  height: 78,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: .42,
                        strokeWidth: 8,
                        backgroundColor: Colors.white24,
                        color: const Color(0xFFFFD166),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${QuranGameService.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const Text(
                            'المستوى',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _headerIcon(IconData icon, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      );

  Widget _dailyGoal() => Padding(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7DF), Color(0xFFFFFDF7)],
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE8CB83)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD166),
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      color: Color(0xFF76551F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'هدفك اليوم',
                          style: TextStyle(
                            color: Color(0xFF76551F),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'أجب عن 3 أسئلة لتحافظ على السلسلة',
                          style: TextStyle(
                            color: Color(0xFF463A24),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${QuranGameService.questionsAnsweredInCurrentLevel % 3}/3',
                    style: const TextStyle(
                      color: Color(0xFF76551F),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value:
                      (QuranGameService.questionsAnsweredInCurrentLevel % 3) /
                          3,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEEDFB5),
                  color: const Color(0xFFB98B45),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title, String trailing) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 9),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              trailing,
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _weeklyStreak() => SizedBox(
        height: 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (_, i) {
            final active = i < (QuranGameService.streak.clamp(0, 6));
            return Container(
              width: 45,
              decoration: BoxDecoration(
                color: active
                    ? (dark ? const Color(0xFF1B554B) : const Color(0xFFE0F2E8))
                    : surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? const Color(0xFF58B88C) : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    active ? '✓' : '—',
                    style: TextStyle(
                      color: active ? const Color(0xFF58B88C) : muted,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'][i],
                    style: TextStyle(
                      color: muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

  Widget _mapCard({bool compact = false}) {
    final current = QuranGameService.level;
    final maxLevel = QuranGameService.maximumAvailableLevel;
    final first = max(1, current - (compact ? 1 : 2)).toInt();
    final last = min(maxLevel, current + (compact ? 2 : 4)).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(23),
          boxShadow: dark ? null : [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            for (var value = first; value <= last; value++) _levelNode(value),
            if (last < maxLevel)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('يتبقى ${maxLevel - last} مستوى في الرحلة', style: TextStyle(color: muted, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _levelNode(int value) {
    final isCurrent = value == QuranGameService.level;
    final completed = QuranGameService.isLevelCompleted(value);
    final unlocked = value <= QuranGameService.level;
    final stars = QuranGameService.starsForLevel(value);
    final subtitle = completed
        ? 'مكتمل • ${stars} من 3 نجوم'
        : isCurrent
            ? '${QuranGameService.questionsAnsweredInCurrentLevel} من ${QuranGameService.currentLevelQuestionCount} أسئلة'
            : 'أكمل المستوى السابق لفتحه';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: isCurrent ? () => open(const QuranGameQuizPage()) : null,
        borderRadius: BorderRadius.circular(15),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent
                    ? const Color(0xFF58B88C)
                    : completed
                        ? (dark ? const Color(0xFF23564D) : const Color(0xFFE0F1E9))
                        : (dark ? const Color(0xFF263F3C) : const Color(0xFFF0F2EF)),
                border: Border.all(color: isCurrent ? const Color(0xFFFFD166) : completed ? const Color(0xFF3C8D76) : Colors.grey.shade400, width: isCurrent ? 3 : 1),
              ),
              child: Icon(completed ? Icons.check_rounded : unlocked ? Icons.menu_book_rounded : Icons.lock_rounded, color: isCurrent ? Colors.white : completed ? const Color(0xFF3C8D76) : muted, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المستوى $value', style: TextStyle(color: isCurrent ? const Color(0xFF58B88C) : ink, fontSize: 13, fontWeight: FontWeight.w900)),
                  Text(subtitle, style: TextStyle(color: muted, fontSize: 10)),
                ],
              ),
            ),
            if (completed)
              Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => Icon(Icons.star_rounded, size: 15, color: i < stars ? const Color(0xFFFFC83D) : Colors.grey.shade400)))
            else if (isCurrent)
              const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF58B88C))
            else
              Icon(Icons.lock_outline_rounded, color: muted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _chapter(
    int n,
    IconData icon,
    String title,
    String sub,
    bool unlocked, {
    bool current = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current
                    ? const Color(0xFF58B88C)
                    : unlocked
                        ? (dark
                            ? const Color(0xFF23564D)
                            : const Color(0xFFE0F1E9))
                        : (dark
                            ? const Color(0xFF263F3C)
                            : const Color(0xFFF0F2EF)),
                border: Border.all(
                  color: current
                      ? const Color(0xFFFFD166)
                      : unlocked
                          ? const Color(0xFF3C8D76)
                          : Colors.grey.shade400,
                  width: current ? 3 : 2,
                ),
                boxShadow: current
                    ? [
                        BoxShadow(
                          color: const Color(0xFF58B88C).withAlpha(75),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: current
                    ? Colors.white
                    : unlocked
                        ? const Color(0xFF3C8D76)
                        : muted,
                size: 23,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المحطة $n',
                    style: TextStyle(
                      color: current ? const Color(0xFF58B88C) : muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(sub, style: TextStyle(color: muted, fontSize: 10)),
                ],
              ),
            ),
            if (current)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'متابعة',
                  style: TextStyle(
                    color: Color(0xFF76551F),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else if (unlocked)
              Text(
                '✓',
                style: TextStyle(
                  color: const Color(0xFF58B88C),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      );
  Widget _mapLine() => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: 4,
          height: 20,
          margin: const EdgeInsetsDirectional.only(start: 25),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF4A776D) : const Color(0xFFB8DDCC),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  Widget _quickTools() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: Row(
          children: [
            _tool(
              Icons.emoji_events_rounded,
              'الإنجازات',
              () => open(const QuranGameAchievementsPage()),
            ),
            _tool(
              Icons.auto_awesome_rounded,
              'متجر النور',
              () => open(const QuranGameStorePage()),
            ),
            _tool(
              Icons.insights_rounded,
              'إحصائيات',
              () => open(const QuranGameStatsPage()),
            ),
            _tool(Icons.nightlight_round, 'الوضع الليلي', () async {
              await QuranGameService.setDarkMode(!dark);
              setState(() {});
            }),
          ],
        ),
      );
  Widget _tool(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(15),
                boxShadow: dark
                    ? null
                    : [
                        BoxShadow(
                            color: Colors.black.withAlpha(10), blurRadius: 8)
                      ],
              ),
              child: Column(
                children: [
                  Icon(icon, color: const Color(0xFFB98B45), size: 22),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _pathPage() => ListView(
        children: [
          _sectionTitle('خريطة المستويات كاملة', '${QuranGameService.maximumAvailableLevel} مستوى'),
          const SizedBox(height: 3),
          _mapCard(),
          _rewardsCard(),
        ],
      );

  Widget _rewardsCard() => Padding(
        padding: const EdgeInsets.fromLTRB(17, 19, 17, 25),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(21),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مكافآت اليوم',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              _reward('إجابة صحيحة', '+10 ✨'),
              _reward('إنهاء المستوى', '+25 ✨'),
              _reward('مستوى مثالي', '+50 ✨'),
            ],
          ),
        ),
      );
  Widget _reward(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: const Color(0xFFB98B45),
              size: 19,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFB98B45),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
  Widget _achievementsPreview() => ListView(
        padding: const EdgeInsets.all(17),
        children: [
          Text(
            'إنجازاتك',
            style: TextStyle(
                color: ink, fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'كل خطوة في الرحلة تستحق الاحتفال.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          _achievement(
            '🌱',
            'أول خطوة',
            'أجب إجابة صحيحة',
            QuranGameService.correctAnswers >= 1,
          ),
          _achievement(
            '🔥',
            'Combo Master',
            'حقق Combo ×10',
            QuranGameService.bestCombo >= 10,
          ),
          _achievement(
            '🎯',
            'Daily Player',
            'أكمل 7 تحديات يومية',
            QuranGameService.dailyChallenges >= 7,
          ),
          _achievement(
            '👑',
            'الحافظ',
            'الوصول للمستوى 50',
            QuranGameService.level >= 50,
          ),
        ],
      );
  Widget _achievement(String icon, String title, String sub, bool open) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Text(
                icon,
                style: TextStyle(
                  fontSize: 29,
                  color: open ? null : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                    ),
                    Text(sub, style: TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(
                open ? Icons.check_circle : Icons.lock_outline,
                color: open ? const Color(0xFF58B88C) : muted,
              ),
            ],
          ),
        ),
      );
  Widget _accountPage() => ListView(
        padding: const EdgeInsets.all(17),
        children: [
          Text(
            'ملفك في أكمل الآية',
            style: TextStyle(
                color: ink, fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFFFD166),
                  child: Text('📖', style: TextStyle(fontSize: 25)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رحّالة القرآن',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${QuranGameService.xp} XP • ${QuranGameService.noor} نور',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (QuranGameService.owned('frame_gold'))
            _statLine(
              'إطار الملف',
              QuranGameService.enabled('frame_gold')
                  ? 'ذهبي • مفعّل'
                  : 'ذهبي • غير مفعّل',
            ),
          if (QuranGameService.owned('badge_skilled'))
            _statLine('الشارة', 'الماهر 🏅'),
          if (QuranGameService.owned('title_reader'))
            _statLine('اللقب', 'قارئ القرآن'),
          _statLine(
            'الدقة',
            '${QuranGameService.totalQuestions == 0 ? 0 : (QuranGameService.correctAnswers * 100 / QuranGameService.totalQuestions).round()}%',
          ),
          _statLine('إجمالي النجوم', '${QuranGameService.totalStars} ⭐'),
          _statLine('أفضل Combo', '${QuranGameService.bestCombo}'),
          _statLine('أطول سلسلة', '${QuranGameService.longestStreak} يوم'),
          const SizedBox(height: 12),
          Panel(
            onTap: () => open(const QuranGameSettingsPage()),
            child: const Row(
              children: [
                Icon(Icons.settings_rounded),
                SizedBox(width: 10),
                Text(
                  'إعدادات اللعبة',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      );
  Widget _statLine(String a, String b) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(
                a,
                style: TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                b,
                style: const TextStyle(
                  color: Color(0xFFB98B45),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _embeddedTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        child: Row(
          children: [
            _embeddedTab('الرئيسية', Icons.home_rounded, 0),
            _embeddedTab('المسار', Icons.map_rounded, 1),
            _embeddedTab('الإنجازات', Icons.emoji_events_rounded, 2),
            _embeddedTab('حسابي', Icons.person_rounded, 3),
          ],
        ),
      );

  Widget _embeddedTab(String label, IconData icon, int value) => Expanded(
        child: InkWell(
          onTap: () => setState(() => tab = value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 19, color: tab == value ? const Color(0xFF58B88C) : muted),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: tab == value ? const Color(0xFF58B88C) : muted)),
            ]),
          ),
        ),
      );

  Widget _bottomNav() => Container(
        color: dark ? const Color(0xFF102B29) : background,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(Icons.home_rounded, 'الرئيسية', 0),
            _nav(Icons.map_rounded, 'المسار', 1),
            GestureDetector(
              onTap: () => open(const QuranGameQuizPage()),
              child: Container(
                width: 57,
                height: 57,
                margin: const EdgeInsets.only(top: -20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      dark ? const Color(0xFFD7AE57) : const Color(0xFF58B88C),
                  border: Border.all(color: background, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF58B88C).withAlpha(80),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: dark ? const Color(0xFF173F3A) : Colors.white,
                  size: 29,
                ),
              ),
            ),
            _nav(Icons.emoji_events_rounded, 'الإنجازات', 2),
            _nav(Icons.person_rounded, 'حسابي', 3),
          ],
        ),
      );
  Widget _nav(IconData icon, String label, int value) => InkWell(
        onTap: () => setState(() => tab = value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: tab == value ? const Color(0xFF58B88C) : muted,
                size: 21,
              ),
              Text(
                label,
                style: TextStyle(
                  color: tab == value ? const Color(0xFF58B88C) : muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

class QuranGameQuizPage extends StatefulWidget {
  final bool daily;
  const QuranGameQuizPage({super.key, this.daily = false});
  @override
  State<QuranGameQuizPage> createState() => _QuranGameQuizPageState();
}

class _QuranGameQuizPageState extends State<QuranGameQuizPage> {
  late QuranGameQuestion q;
  bool showLevelResults = false;
  String? verseContext;
  String? selected;
  bool? correct;
  bool loading = false;
  bool showHint = false;
  List<String>? choices;
  bool hasSecondChance = false;
  @override
  void initState() {
    super.initState();
    if (!widget.daily && QuranGameService.levelCompleted) {
      showLevelResults = true;
      q = QuranGameService.questions.first;
    } else {
      q = QuranGameService.nextQuestion(requestedLevel: QuranGameService.level);
      _loadVerseContext();
    }
  }

  Future<void> _loadVerseContext() async {
    if (q.isIslamicKnowledge || q.surahNumber < 1 || q.ayahNumber < 1) {
      if (mounted) setState(() => verseContext = null);
      return;
    }
    try {
      final ayahs = await QuranService.text(q.surahNumber);
      final currentIndex = ayahs.indexWhere((a) => a.n == q.ayahNumber);
      if (currentIndex < 0) return;
      final words = q.fullAyah.trim().split(RegExp(r'\s+'));
      String context;
      if (words.length <= 12) {
        final parts = <String>[];
        if (currentIndex > 0) parts.add(ayahs[currentIndex - 1].text);
        parts.add(q.maskedAyah);
        if (currentIndex + 1 < ayahs.length) parts.add(ayahs[currentIndex + 1].text);
        context = parts.join(' ۞ ');
      } else {
        final target = words.indexWhere((word) => word.contains(q.hiddenWord));
        if (target < 0) {
          context = q.maskedAyah;
        } else {
          final start = max(0, target - 4).toInt();
          final end = min(words.length, target + 5).toInt();
          final excerpt = words.sublist(start, end);
          excerpt[target - start] = excerpt[target - start].replaceFirst(q.hiddenWord, 'ـــــــ');
          context = excerpt.join(' ');
        }
      }
      if (mounted) setState(() => verseContext = context);
    } catch (_) {
      if (mounted) setState(() => verseContext = q.contextText.isEmpty ? q.maskedAyah : q.contextText);
    }
  }

  @override
  void dispose() {
    AudioCtl.i.stop();
    super.dispose();
  }

  Future<void> choose(String option) async {
    if (selected != null || loading) return;
    setState(() {
      selected = option;
      correct = option == q.correctOption;
      loading = true;
    });
    try {
      final beforeAchievements = QuranGameService.achievementCount;
      await QuranGameService.answer(
        q,
        correct!,
        daily: widget.daily,
        retry: hasSecondChance,
      );
      if (mounted && QuranGameService.achievementCount > beforeAchievements) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🏆 إنجاز جديد! أضيفت مكافأته إلى نور اللعبة ✨')),
        );
      }
      if (widget.daily && correct!) {
        final reward = await QuranGameService.completeDaily();
        if (mounted && reward > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('🎉 أحسنت! +$reward نور اللعبة ✨ • تحدي اليوم اكتمل')),
          );
        }
      }
      if (!widget.daily) {
        final beforePerfect = QuranGameService.perfectLevels;
        final completed = await QuranGameService.completeLevelIfReady();
        if (mounted && completed) {
          final perfect = QuranGameService.perfectLevels > beforePerfect;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(perfect
                    ? '${QuranGameService.enabled('effect_perfect') ? '✨🎆 ' : ''}💯 PERFECT! أُكمل المستوى بلا أخطاء • +${QuranGameConfig.levelBonus + QuranGameConfig.perfectBonus} نور اللعبة ✨'
                    : '${QuranGameService.enabled('effect_level') ? '🎉✨ ' : '🎉 '}اكتمل المستوى! +${QuranGameConfig.levelBonus} نور اللعبة ✨')),
          );
        }
      }
      if (correct! &&
          QuranGameService.autoRecite &&
          q.globalAyahNumber != null) {
        await AudioCtl.i.playAyah(q.globalAyahNumber!);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إكمال العملية. تحقق من الاتصال أو رصيد نور اللعبة.',
            ),
          ),
        );
    }
    if (mounted) setState(() => loading = false);
  }

  void next() {
    AudioCtl.i.stop();
    setState(() {
      q = QuranGameService.nextQuestion(requestedLevel: QuranGameService.level);
      selected = null;
      correct = null;
      showHint = false;
      choices = null;
      hasSecondChance = false;
      verseContext = null;
    });
    _loadVerseContext();
  }

  Future<void> _advanceLevel() async {
    final advanced = await QuranGameService.advanceToNextLevel();
    if (!mounted) return;
    if (!advanced) {
      _message('وصلت إلى نهاية الأسئلة المتاحة حاليًا.');
      return;
    }
    setState(() => showLevelResults = false);
    next();
  }

  Future<void> _hint() async {
    if (!await QuranGameService.useBooster('hint')) {
      _message('لا يوجد تلميح. اشترِه من متجر نور اللعبة.');
      return;
    }
    setState(() => showHint = true);
  }

  Future<void> _removeTwo() async {
    if (!await QuranGameService.useBooster('remove_two')) {
      _message('لا يوجد معزز إزالة اختيارين.');
      return;
    }
    final remaining = await QuranGameService.removeTwoWrongOptions(q);
    if (mounted) setState(() => choices = remaining);
  }

  Future<void> _secondChance() async {
    if (correct == true || !await QuranGameService.activateSecondChance(q.id)) {
      _message('لا يوجد معزز محاولة ثانية.');
      return;
    }
    setState(() {
      selected = null;
      correct = null;
      hasSecondChance = true;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (showLevelResults) {
      return Scaffold(
        appBar: AppBar(title: Text('نتيجة المستوى ${QuranGameService.level}')),
        body: Center(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: _levelResultCard()))),
      );
    }
    final answered = selected != null;
    final count = widget.daily
        ? (QuranGameService.dailyDone ? 1 : 0)
        : QuranGameService.questionsAnsweredInCurrentLevel;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.daily ? 'تحدي اليوم' : 'المستوى ${QuranGameService.level}',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                'نور اللعبة ✨ ${QuranGameService.noor}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.daily
                    ? (QuranGameService.dailyDone
                        ? 'اكتمل تحدي اليوم'
                        : 'تحدي مستقل • مرة واحدة يوميًا')
                    : 'سؤال ${min(count + (answered ? 0 : 1), QuranGameService.currentLevelQuestionCount)} من ${QuranGameService.currentLevelQuestionCount}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '🔥 Combo ×${QuranGameService.combo}',
                style: const TextStyle(
                  color: goldDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: widget.daily
                ? (QuranGameService.dailyDone ? 1 : 0)
                : count / QuranGameService.currentLevelQuestionCount,
          ),
          const SizedBox(height: 24),
          Panel(
            color: Theme.of(context).colorScheme.primary.withAlpha(14),
            child: Column(
              children: [
                if (q.isIslamicKnowledge) ...[
                  const Text('ثقافة إسلامية', style: TextStyle(fontWeight: FontWeight.w900, color: goldDeep)),
                  const SizedBox(height: 14),
                  Text(
                    q.questionText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 21, height: 1.7, fontWeight: FontWeight.w900),
                  ),
                  if (q.explanation?.isNotEmpty == true && answered) ...[
                    const SizedBox(height: 12),
                    Text(q.explanation!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(190))),
                  ],
                  if (q.sourceName.isNotEmpty && answered) ...[
                    const SizedBox(height: 8),
                    Text('المصدر: ${q.sourceName} • ${q.sourceReference}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(145))),
                  ],
                ] else ...[
                  Text(
                    'سورة ${q.surahName} • آية ${q.ayahNumber}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    answered ? q.fullAyah : (verseContext ?? (q.contextText.isNotEmpty ? q.contextText : q.maskedAyah)),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: quranStyle(25, Theme.of(context).colorScheme.onSurface),
                  ),
                ],
                if (showHint) ...[
                  const SizedBox(height: 8),
                  Text(QuranGameService.hintFor(q), style: const TextStyle(color: goldDeep, fontWeight: FontWeight.w800)),
                ],
                if (answered) ...[
                  const SizedBox(height: 12),
                  Text(
                    correct!
                        ? '${QuranGameService.enabled('effect_correct') ? '✨ ' : ''}أحسنت! +10 نور اللعبة ✨'
                        : 'ليست الإجابة الصحيحة',
                    style: TextStyle(color: correct! ? Colors.green : Colors.orange, fontWeight: FontWeight.w900),
                  ),
                ],
              ],
            ),
          ),
          if (!answered) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _hint,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(
                    'تلميح (${QuranGameService.boosterCount('hint')})',
                  ),
                ),
                TextButton.icon(
                  onPressed: _removeTwo,
                  icon: const Icon(Icons.content_cut),
                  label: Text(
                    'احذف اختيارين (${QuranGameService.boosterCount('remove_two')})',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          for (final option in choices ?? q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _option(option),
            ),
          if (answered && correct == false && !hasSecondChance)
            Center(
              child: TextButton.icon(
                onPressed: _secondChance,
                icon: const Icon(Icons.replay),
                label: Text(
                  'محاولة ثانية (${QuranGameService.boosterCount('second_chance')})',
                ),
              ),
            ),
          if (answered && correct == true) _recitationControls(),
          if (answered && !widget.daily && QuranGameService.levelCompleted) ...[
            const SizedBox(height: 14),
            _levelResultCard(),
          ] else if (answered) ...[
            const SizedBox(height: 14),
            Panel(
              onTap: next,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('السؤال التالي', style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_back_rounded),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'النص القرآني مأخوذ حرفيًا من مصدر المصحف العثماني. التلاوة تستخدم مشغل سكينة المشترك.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelResultCard() => Panel(
        child: Column(
          children: [
            const Text('اكتمل المستوى!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('${QuranGameService.correctAnswersInCurrentLevel} من ${QuranGameService.currentLevelQuestionCount} إجابات صحيحة'),
            const SizedBox(height: 4),
            Text('إجابات خاطئة: ${QuranGameService.mistakesInCurrentLevel}', style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 4),
            Text('أفضل نتيجة: ${QuranGameService.bestCorrectForLevel(QuranGameService.level)} من ${QuranGameService.currentLevelQuestionCount}', style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Icon(Icons.star_rounded, size: 36, color: i < QuranGameService.currentLevelStars ? const Color(0xFFFFC83D) : Colors.grey.shade400))),
            const SizedBox(height: 8),
            Text(QuranGameService.currentLevelStars == 3 ? 'علامة كاملة • أداء ممتاز' : 'يمكنك إعادة المستوى لتحسين نتيجتك', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            if (QuranGameService.level < QuranGameService.maximumAvailableLevel)
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _advanceLevel, icon: const Icon(Icons.arrow_back_rounded), label: const Text('الانتقال للمستوى التالي')))
            else
              const Text('أحسنت! وصلت إلى نهاية الأسئلة المتاحة حاليًا.', textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _recitationControls() => StreamBuilder<PlayerState>(
        stream: AudioCtl.i.player.playerStateStream,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          final player = AudioCtl.i.player;
          return Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_up),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: player.volume.clamp(0, 1).toDouble(),
                        onChanged: (v) => player.setVolume(v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق التلاوة',
                      onPressed: () => AudioCtl.i.stop(),
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
                      onPressed: () => AudioCtl.i.toggle(),
                      icon: Icon(
                          playing ? Icons.pause_circle : Icons.play_circle),
                    ),
                  ],
                ),
                StreamBuilder<Duration?>(
                  stream: player.durationStream,
                  builder: (context, duration) => StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, position) {
                      final total = duration.data ?? Duration.zero;
                      final pos = position.data ?? Duration.zero;
                      final maxMs = max(1, total.inMilliseconds);
                      return Slider(
                        value: pos.inMilliseconds.clamp(0, maxMs).toDouble(),
                        max: maxMs.toDouble(),
                        onChanged: total == Duration.zero
                            ? null
                            : (v) =>
                                player.seek(Duration(milliseconds: v.round())),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
  Widget _option(String option) {
    final isSelected = selected == option;
    final isAnswer = option == q.correctOption;
    final color = selected == null
        ? null
        : isAnswer
            ? Colors.green
            : isSelected
                ? Colors.red
                : null;
    return Panel(
      onTap: selected == null ? () => choose(option) : null,
      color: color?.withAlpha(22),
      child: Row(
        children: [
          Icon(
            selected == null
                ? Icons.radio_button_unchecked
                : isAnswer
                    ? Icons.check_circle
                    : isSelected
                        ? Icons.cancel
                        : Icons.radio_button_unchecked,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              option,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (isSelected && loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
