import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/activity_service.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}
class _ChallengesPageState extends State<ChallengesPage> {
  final challenges = const [
    ('quran', 7, 'أسبوع مع القرآن', 'اقرأ شيئًا من القرآن في ٧ أيام مختلفة', Icons.menu_book_rounded),
    ('quran', 30, 'شهر من الصحبة', 'اجعل القراءة عادة يومية خلال ٣٠ يومًا', Icons.auto_stories_rounded),
    ('tasbeeh', 7, 'أسبوع تسبيح', 'خصص وقتًا يوميًا للتسبيح لمدة أسبوع', Icons.fingerprint_rounded),
    ('azkar', 7, 'أسبوع الأذكار', 'حافظ على أذكارك في ٧ أيام مختلفة', Icons.auto_awesome_rounded),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('تحديات سكينة')), body: ListView(padding: const EdgeInsets.all(16), children: [
    HeroCard(margin: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('تحديات اختيارية لتشجيع الاستمرار', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)), const SizedBox(height: 8), Text('اختر تحديًا يناسبك. التقدم محسوب بعدد الأيام النشطة، وليس بمقارنة نفسك بالآخرين.', style: TextStyle(color: Colors.white.withAlpha(220), height: 1.7))]),),
    const SectionTitle('اختر تحديك'),
    for (final c in challenges) _card(c.$1, c.$2, c.$3, c.$4, c.$5),
  ]));
  Widget _card(String task, int goal, String title, String desc, IconData icon) {
    final id = '${task}_$goal';
    final started = ActivityService.challenges[id] as String?;
    final startDate = started == null ? null : DateTime.tryParse(started);
    final progress = startDate == null ? 0 : ActivityService.activeDays(days: goal, task: task, since: startDate).clamp(0, goal);
    final pct = progress / goal;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: gold), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Text('${ar(progress)}/${ar(goal)}', style: const TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 7), Text(desc, style: const TextStyle(fontSize: 12, height: 1.6)), const SizedBox(height: 10),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct, minHeight: 8)),
      if (progress >= goal) const Padding(padding: EdgeInsets.only(top: 8), child: Text('أحسنت! أتممت التحدي 🌟', style: TextStyle(color: goldDeep, fontWeight: FontWeight.w800))),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: started == null ? FilledButton.tonal(onPressed: () async { await ActivityService.startChallenge(id); if (mounted) setState(() {}); }, child: const Text('ابدأ التحدي')) : TextButton(onPressed: () async { await ActivityService.resetChallenge(id); if (mounted) setState(() {}); }, child: const Text('إعادة ضبط التحدي'))),
    ])));
  }
}
