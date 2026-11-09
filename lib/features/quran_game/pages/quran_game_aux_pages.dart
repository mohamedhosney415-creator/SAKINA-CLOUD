import 'package:flutter/material.dart';

import '../../../core/store.dart';
import '../../../core/widgets.dart';
import '../services/quran_game_service.dart';

class QuranGameAchievementsPage extends StatelessWidget {
  const QuranGameAchievementsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final items = <(String, String, bool)>[
      ('🌱 أول خطوة', 'أجب إجابة صحيحة', QuranGameService.correctAnswers >= 1),
      (
        '📖 محب القرآن',
        '50 إجابة صحيحة',
        QuranGameService.correctAnswers >= 50,
      ),
      ('🔥 Combo Master', 'Combo ×10', QuranGameService.bestCombo >= 10),
      (
        '💯 Perfect',
        'أكمل مستوى بلا أخطاء',
        QuranGameService.perfectLevels > 0,
      ),
      (
        '🎯 Daily Player',
        '7 تحديات يومية',
        QuranGameService.dailyChallenges >= 7,
      ),
      ('🏅 الماهر', 'الوصول للمستوى 25', QuranGameService.level >= 25),
      ('👑 الحافظ', 'الوصول للمستوى 50', QuranGameService.level >= 50),
      (
        '🔥 Streak 30',
        '30 يومًا متتاليًا',
        QuranGameService.longestStreak >= 30,
      ),
      ('✨ المثابر', 'إكمال 10 مستويات', QuranGameService.level > 10),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('الإنجازات')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          for (final x in items)
            Panel(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    x.$1,
                    style: TextStyle(
                      fontSize: 24,
                      color: x.$3 ? null : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    x.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Icon(
                    x.$3 ? Icons.check_circle : Icons.lock_outline,
                    size: 18,
                    color: x.$3 ? Colors.green : Colors.grey,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class QuranGameStorePage extends StatefulWidget {
  const QuranGameStorePage({super.key});
  @override
  State<QuranGameStorePage> createState() => _QuranGameStorePageState();
}

class _QuranGameStorePageState extends State<QuranGameStorePage> {
  static const products = <(String, String, String, IconData)>[
    (
      'gold',
      'المظهر الذهبي',
      'سمة ذهبية هادئة قابلة للتفعيل',
      Icons.workspace_premium,
    ),
    ('night', 'مظهر الليل', 'سمة ليلية مريحة للعين', Icons.dark_mode),
    ('ramadan', 'مظهر رمضان', 'لمسات رمضانية للعبة', Icons.nights_stay),
    ('mushaf', 'مظهر المصحف', 'هوية مستوحاة من المصحف', Icons.menu_book),
    ('frame_gold', 'إطار ذهبي', 'إطار مميز للملف الشخصي', Icons.crop_square),
    ('badge_skilled', 'شارة الماهر', 'شارة ملف شخصية', Icons.military_tech),
    ('title_reader', 'لقب قارئ القرآن', 'لقب للملف الشخصي', Icons.badge),
    (
      'effect_correct',
      'تأثير الإجابة الصحيحة',
      'تأثير بصري عند الإجابة',
      Icons.auto_awesome,
    ),
    (
      'effect_perfect',
      'تأثير المستوى المثالي',
      'تأثير بصري للإنجاز المثالي',
      Icons.stars,
    ),
    (
      'effect_level',
      'تأثير إكمال المستوى',
      'احتفال بصري بإكمال المستوى',
      Icons.celebration,
    ),
    (
      'hint',
      'تلميح',
      'يُظهر الحرف الأول للكلمة الناقصة',
      Icons.lightbulb_outline,
    ),
    (
      'remove_two',
      'إزالة اختيارين',
      'يُبقي الإجابة واختيارًا خاطئًا',
      Icons.content_cut,
    ),
    (
      'second_chance',
      'محاولة ثانية',
      'يفتح محاولة إضافية بعد الخطأ',
      Icons.replay,
    ),
    (
      'combo_protection',
      'حماية Combo',
      'يحمي السلسلة من خطأ واحد',
      Icons.shield,
    ),
  ];
  Future<void> _buy(String id) async {
    final ok = id == 'hint' ||
            id == 'remove_two' ||
            id == 'second_chance' ||
            id == 'combo_protection'
        ? await QuranGameService.purchaseBooster(id)
        : await QuranGameService.buy(id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'تم الشراء بنجاح.'
                : 'رصيد نور اللعبة غير كافٍ أو العنصر مملوك بالفعل.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Text('متجر نور اللعبة ✨'),
          actions: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Center(child: Text('${QuranGameService.noor} ✨')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'الرصيد مستقل عن أي رصيد آخر في سكينة. العناصر التي يمكن تفعيلها تتيح التحكم بها بعد الشراء.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            for (final x in products) _item(x.$1, x.$2, x.$3, x.$4),
          ],
        ),
      );
  Widget _item(String id, String title, String description, IconData icon) {
    final cost = QuranGameConfig.storeCatalog[id]!;
    final owned = QuranGameService.owned(id);
    final booster = const {
      'hint',
      'remove_two',
      'second_chance',
      'combo_protection',
    }.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Row(
          children: [
            Icon(icon, color: Colors.amber, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(description, style: const TextStyle(fontSize: 12)),
                  if (owned && booster)
                    Text(
                      'المخزون: ${QuranGameService.boosterCount(id)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            if (owned && !booster)
              Switch(
                value: QuranGameService.enabled(id),
                onChanged: (v) async {
                  await QuranGameService.setItemEnabled(id, v);
                  setState(() {});
                },
              )
            else
              TextButton(
                onPressed: owned ? () => _buy(id) : () => _buy(id),
                child: Text(owned ? 'شراء مرة أخرى • $cost ✨' : '$cost ✨'),
              ),
          ],
        ),
      ),
    );
  }
}

class QuranGameStatsPage extends StatelessWidget {
  const QuranGameStatsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final total = QuranGameService.totalQuestions;
    final accuracy = total == 0
        ? 0
        : (QuranGameService.correctAnswers * 100 / total).round();
    final rewards = Store.json('qgame_pending_rewards', <dynamic>[]) as List;
    final badges = Store.json('qgame_badges', <dynamic>[]) as List;
    return Scaffold(
      appBar: AppBar(title: const Text('إحصائيات اللعبة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _stat('المستوى الحالي', '${QuranGameService.level}'),
          _stat(
            'أسئلة المستوى الحالي',
            '${QuranGameService.questionsAnsweredInCurrentLevel}/10',
          ),
          _stat(
            'صحيحة في المستوى',
            '${QuranGameService.correctAnswersInCurrentLevel}',
          ),
          _stat('أخطاء المستوى', '${QuranGameService.mistakesInCurrentLevel}'),
          _stat('إجمالي الأسئلة (يشمل اليومي)', '$total'),
          _stat('الإجابات الصحيحة', '${QuranGameService.correctAnswers}'),
          _stat('الإجابات الخاطئة', '${QuranGameService.wrongAnswers}'),
          _stat('الدقة', '$accuracy%'),
          _stat('أفضل Combo', '${QuranGameService.bestCombo}'),
          _stat('نور اللعبة ✨', '${QuranGameService.noor}'),
          _stat(
            'التحديات اليومية المكتملة',
            '${QuranGameService.dailyChallenges}',
          ),
          _stat(
            'السلسلة الحالية / الأطول',
            '${QuranGameService.streak} / ${QuranGameService.longestStreak}',
          ),
          _stat('المستويات المثالية', '${QuranGameService.perfectLevels}'),
          _stat(
            'الإنجازات المكتملة',
            '${[
              QuranGameService.correctAnswers >= 1,
              QuranGameService.correctAnswers >= 50,
              QuranGameService.bestCombo >= 10,
              QuranGameService.perfectLevels > 0,
              QuranGameService.dailyChallenges >= 7,
              QuranGameService.level >= 25,
              QuranGameService.level >= 50,
              QuranGameService.longestStreak >= 30
            ].where((x) => x).length}',
          ),
          _stat(
            'الشارات المفتوحة',
            badges.join('، ').isEmpty ? 'لا توجد بعد' : badges.join('، '),
          ),
          _stat(
            'عناصر المتجر المملوكة',
            '${QuranGameConfig.storeCatalog.keys.where(QuranGameService.owned).length}',
          ),
          _stat('مكافآت مسجلة', '${rewards.length}'),
        ],
      ),
    );
  }

  Widget _stat(String a, String b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(a,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  b,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      );
}

class QuranGameSettingsPage extends StatefulWidget {
  const QuranGameSettingsPage({super.key});
  @override
  State<QuranGameSettingsPage> createState() => _QuranGameSettingsPageState();
}

class _QuranGameSettingsPageState extends State<QuranGameSettingsPage> {
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('إعدادات اللعبة')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              value: QuranGameService.autoRecite,
              onChanged: (v) async {
                await QuranGameService.setAutoRecite(v);
                setState(() {});
              },
              title: const Text('تشغيل تلاوة الآية بعد الإجابة الصحيحة'),
              subtitle: const Text('يستخدم مشغل القرآن الحالي في سكينة'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('إعادة ضبط إحصائيات اللعبة'),
              subtitle: const Text(
                'يحذف التقدم والنور والمشتريات والسجل المحلي للعبة فقط',
              ),
              onTap: () => showDialog(
                context: c,
                builder: (d) => AlertDialog(
                  title: const Text('تأكيد إعادة الضبط'),
                  content: const Text(
                    'سيتم حذف تقدم اللعبة محليًا. لا يمكن التراجع عن ذلك.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await QuranGameService.reset();
                        if (d.mounted) Navigator.pop(d);
                        if (mounted) setState(() {});
                      },
                      child: const Text('إعادة الضبط'),
                    ),
                  ],
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('أكمل الآية'),
              subtitle: Text(
                'بيانات اللعبة تحفظ محليًا ضمن مخزن SAKINA الحالي وتدخل في النسخ الاحتياطي ومزامنة المستخدم القائمة.',
              ),
            ),
          ],
        ),
      );
}
