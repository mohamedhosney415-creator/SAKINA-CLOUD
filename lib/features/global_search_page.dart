import 'package:flutter/material.dart';
import '../core/widgets.dart';
import '../core/theme.dart';
import '../data/surahs.dart';
import '../data/azkar.dart';
import 'reader_page.dart';
import 'azkar_page.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});
  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    final norm = q.replaceAll(RegExp('[\u064B-\u065F]'), '');
    final surahResults = q.isEmpty
        ? <Surah>[]
        : surahs.where((s) => s.name.contains(norm) || '${s.number}' == q).take(20).toList();
    final zikrResults = q.isEmpty
        ? <({AzkarCategory category, Zikr zikr})>[]
        : [
            for (final category in azkarCategories)
              for (final zikr in category.items)
                if ('${zikr.text} ${zikr.source} ${category.title}'.contains(q))
                  (category: category, zikr: zikr),
          ].take(30).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('البحث الشامل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'ابحث في القرآن والأذكار',
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        setState(() => query = '');
                      },
                      icon: const Icon(Icons.close_rounded)),
            ),
          ),
          const SizedBox(height: 18),
          if (q.isEmpty)
            const EmptyState(
                icon: Icons.manage_search_rounded,
                text: 'اكتب كلمة أو اسم سورة للبحث في محتوى سكينة.'),
          if (surahResults.isNotEmpty) ...[
            const SectionTitle('القرآن الكريم'),
            for (final s in surahResults)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => SurahReaderPage(number: s.number))),
                  child: Row(children: [
                    SakinaIconBadge(icon: Icons.menu_book_rounded, color: tintGreen),
                    const SizedBox(width: 10),
                    Expanded(child: Text('سورة ${s.name}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    const Icon(Icons.chevron_left_rounded, color: goldDeep),
                  ]),
                ),
              ),
          ],
          if (zikrResults.isNotEmpty) ...[
            const SectionTitle('الأذكار'),
            for (final result in zikrResults)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => AzkarListPage(category: result.category))),
                  child: Row(children: [
                    SakinaIconBadge(icon: Icons.auto_awesome_rounded, color: tintGold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(result.category.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(result.zikr.text, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(160))),
                      ]),
                    ),
                  ]),
                ),
              ),
          ],
          if (q.isNotEmpty && surahResults.isEmpty && zikrResults.isEmpty)
            const EmptyState(icon: Icons.search_off_rounded, text: 'لم نجد نتائج بهذا البحث.'),
        ],
      ),
    );
  }
}
