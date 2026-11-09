import 'package:flutter/material.dart';
import '../core/format.dart';
import '../data/surahs.dart';
import '../services/quran_notes_store.dart';
import 'reader_page.dart';

class QuranNotesPage extends StatefulWidget {
  const QuranNotesPage({super.key});

  @override
  State<QuranNotesPage> createState() => _QuranNotesPageState();
}

class _QuranNotesPageState extends State<QuranNotesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    await QuranNotesStore.remove(item['s'] as int, item['a'] as int);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items =
        _tabs.index == 0 ? QuranNotesStore.marked : QuranNotesStore.annotated;
    return Scaffold(
      appBar: AppBar(
        title: const Text('علاماتي وملاحظاتي'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'العلامات'),
          Tab(text: 'الملاحظات'),
        ]),
      ),
      body: items.isEmpty
          ? Center(
              child: Text(_tabs.index == 0
                  ? 'لا توجد علامات مرجعية بعد'
                  : 'لا توجد ملاحظات بعد'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final s = item['s'] as int;
                final a = item['a'] as int;
                final name = (item['name'] as String?)?.isNotEmpty == true
                    ? item['name'] as String
                    : surahs[s - 1].name;
                final note = item['note'] as String? ?? '';
                return ListTile(
                  leading: Icon(_tabs.index == 0
                      ? Icons.bookmark
                      : Icons.sticky_note_2_outlined),
                  title: Text('سورة $name • آية ${ar(a)}'),
                  subtitle: note.isEmpty
                      ? null
                      : Text(note,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(item),
                  ),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                    builder: (_) => SurahReaderPage(number: s, ayah: a),
                  ))
                      .then((_) {
                    if (mounted) setState(() {});
                  }),
                );
              },
            ),
    );
  }
}
