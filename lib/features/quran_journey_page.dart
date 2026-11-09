import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/surahs.dart';
import '../services/activity_service.dart';
import '../services/khatma_store.dart';
import 'quran_page.dart';

class QuranJourneyPage extends StatelessWidget {
  const QuranJourneyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final j = ActivityService.journey;
    final days = ActivityService.quranDays;
    final count = ActivityService.quranSurahs;
    final last = (j['lastSurah'] as num?)?.toInt();
    final pagePct = (count / 114).clamp(0.0, 1.0);
    final plan = KhatmaStore.plan();
    final pagesRead = plan == null ? 0 : KhatmaStore.pagesRead(plan);
    return Scaffold(appBar: AppBar(title: const Text('رحلتي مع القرآن')), body: ListView(padding: const EdgeInsets.all(16), children: [
      HeroCard(margin: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('رحلة مستمرة مع كتاب الله', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: _stat('أيام القراءة', ar(days))), Expanded(child: _stat('سور زرتها', '${ar(count)} / ١١٤')), Expanded(child: _stat('صفحات الختمة', ar(pagesRead)))]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pagePct, minHeight: 9, color: gold, backgroundColor: Colors.white24)),
        const SizedBox(height: 6),
        Text('عدد السور التي قرأتها مرة واحدة على الأقل', style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 11)),
      ])),
      const SectionTitle('آخر قراءة'),
      Panel(child: Row(children: [const Icon(Icons.bookmark_added_rounded, color: gold), const SizedBox(width: 10), Expanded(child: Text(last != null && last > 0 && last <= 114 ? 'سورة ${surahs[last - 1].name}${j['lastAyah'] is num ? ' • الآية ${ar(j['lastAyah'])}' : ''}' : 'لم تسجل قراءة بعد', style: const TextStyle(fontWeight: FontWeight.w800))), FilledButton.tonal(onPressed: () => go(context, const QuranPage(standalone: true)), child: const Text('ابدأ القراءة'))])),
      const SectionTitle('أيام القراءة – آخر 7 أيام'),
      Panel(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [for (var i = 6; i >= 0; i--) _day(DateTime.now().subtract(Duration(days: i)))])),
      const SizedBox(height: 14),
      const Text('المؤشرات هنا تسجل الأيام والسور التي فتحتها وقرأت منها داخل التطبيق، ولا تقيس مقدار التدبر أو جودة القراءة.', style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.7)),
    ]));
  }
  Widget _stat(String a, String b) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a, style: const TextStyle(color: Colors.white70)), Text(b, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 23))]);
  Widget _day(DateTime d) { final active = ActivityService.completed('quran', dayKey(d)); return Column(children: [Text(['ن','ث','ر','خ','ج','س','ح'][d.weekday - 1], style: const TextStyle(fontSize: 11)), const SizedBox(height: 7), CircleAvatar(radius: 15, backgroundColor: active ? gold : Colors.grey.withAlpha(45), child: active ? const Icon(Icons.check, size: 16, color: Colors.black) : Text(ar(d.day), style: const TextStyle(fontSize: 11)))]); }
}
