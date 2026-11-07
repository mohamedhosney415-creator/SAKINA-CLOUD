import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/activity_service.dart';
import 'quran_page.dart';
import 'tasbeeh_page.dart';
import 'azkar_page.dart';

class DailyAssistantPage extends StatefulWidget {
  const DailyAssistantPage({super.key});
  @override
  State<DailyAssistantPage> createState() => _DailyAssistantPageState();
}

class _DailyAssistantPageState extends State<DailyAssistantPage> {
  final tasks = const [
    ('quran', 'ورد القرآن', 'اقرأ ما تيسر لك اليوم', Icons.menu_book_rounded),
    ('azkar', 'الأذكار', 'أذكار الصباح أو المساء', Icons.auto_awesome_rounded),
    ('tasbeeh', 'التسبيح', 'اختر ذكرًا وابدأ التسبيح', Icons.fingerprint_rounded),
    ('prayer', 'متابعة الصلاة', 'سجّل إنجازك اليومي للصلاة', Icons.mosque_rounded),
  ];
  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => ActivityService.completed(t.$1)).length;
    final streak = ActivityService.currentStreak;
    return Scaffold(
      appBar: AppBar(title: const Text('مساعد سكينة اليومي')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        HeroCard(margin: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('خطوة صغيرة كل يوم 🌱', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('أنجز ما يناسب وقتك، واجعل لك وردًا ثابتًا بلا ضغط.', style: TextStyle(color: Colors.white.withAlpha(220), height: 1.7)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _metric('إنجاز اليوم', '${ar(done)}/${ar(tasks.length)}')),
            Expanded(child: _metric('سلسلتك الحالية', '${ar(streak)} يوم 🔥')),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: done / tasks.length, minHeight: 9, color: gold, backgroundColor: Colors.white24)),
        ])),
        const SectionTitle('برنامجك اليوم'),
        for (final t in tasks)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(child: Row(children: [
            Icon(t.$4, color: gold, size: 27), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w800)), Text(t.$3, style: const TextStyle(fontSize: 12))])),
            Checkbox(value: ActivityService.completed(t.$1), onChanged: (v) async { await ActivityService.setAssistantTask(t.$1, v ?? false); if (mounted) setState(() {}); }),
            IconButton(tooltip: 'افتح القسم', onPressed: () => go(context, t.$1 == 'quran' ? const QuranPage(standalone: true) : t.$1 == 'tasbeeh' ? const TasbeehPage() : t.$1 == 'azkar' ? const AzkarPage(standalone: true) : const AzkarPage(standalone: true)), icon: const Icon(Icons.chevron_left)),
          ]))),
        const SizedBox(height: 8),
        const Text('يمكنك وضع علامة الإنجاز بنفسك، كما يسجل التطبيق القراءة والتسبيح تلقائيًا عند استخدامهما.', style: TextStyle(fontSize: 12, height: 1.7, color: Colors.grey)),
      ]),
    );
  }
  Widget _metric(String title, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19))]);
}
