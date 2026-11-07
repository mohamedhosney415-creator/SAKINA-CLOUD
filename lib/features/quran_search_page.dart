import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/widgets.dart';
import '../data/surahs.dart';
import '../services/quran_service.dart';
import 'reader_page.dart';
import 'downloads_page.dart';

class QuranSearchPage extends StatefulWidget {
  const QuranSearchPage({super.key});
  @override
  State<QuranSearchPage> createState() => _QuranSearchPageState();
}
class _QuranSearchPageState extends State<QuranSearchPage> {
  final controller = TextEditingController();
  bool busy = false;
  String query = '';
  List<(int, Ayah)> results = [];
  String message = 'اكتب كلمة أو جزءًا من آية للبحث في النصوص المحفوظة على جهازك.';
  Future<void> _search() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;
    setState(() { busy = true; query = q; results = []; message = 'جارٍ البحث في السور المحفوظة...'; });
    try {
      final found = await QuranService.searchCached(q, limit: 100);
      if (!mounted) return;
      setState(() { results = found; message = found.isEmpty ? 'لم نجد نتائج في النصوص المحفوظة. حمّل نص القرآن كاملًا من صفحة التحميلات ثم جرّب دون إنترنت.' : 'نتائج البحث: ${ar(found.length)}'; });
    } catch (_) { if (mounted) setState(() => message = 'تعذر إتمام البحث.'); }
    if (mounted) setState(() => busy = false);
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('البحث الذكي في القرآن')), body: Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: TextField(controller: controller, textInputAction: TextInputAction.search, onSubmitted: (_) => _search(), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بكلمة أو جزء من آية', border: OutlineInputBorder()))), const SizedBox(width: 8), FilledButton(onPressed: busy ? null : _search, child: const Icon(Icons.search))])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Align(alignment: Alignment.centerRight, child: Text(message, style: const TextStyle(fontSize: 12, color: Colors.grey))), TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsPage())), icon: const Icon(Icons.download_for_offline_outlined), label: const Text('تحميل نص القرآن للبحث دون إنترنت'))])),
    if (busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
    Expanded(child: results.isEmpty ? const EmptyState(icon: Icons.manage_search_rounded, text: 'ستظهر نتائج البحث هنا') : ListView.separated(padding: const EdgeInsets.all(12), itemCount: results.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) { final s = results[i].$1; final a = results[i].$2; return ListTile(title: Text('﴿${a.text}﴾', textAlign: TextAlign.right, style: const TextStyle(height: 1.8, fontSize: 17)), subtitle: Text('سورة ${surahs[s - 1].name} • الآية ${ar(a.n)}'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SurahReaderPage(number: s, ayah: a.n)))); })),
  ]));
}
