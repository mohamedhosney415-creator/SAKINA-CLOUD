import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/azkar.dart';
import '../services/activity_service.dart';
import '../services/azkar_progress_service.dart';
import 'tasbeeh_page.dart';

/// تقدّم الأذكار اليومي (يُحفظ ٣ أيام فقط ثم يُمسح تلقائيًا).
class AzkarProgress {
  static Map<String, dynamic> _all() {
    final j = Store.json('azkar_prog', {});
    return j is Map ? Map<String, dynamic>.from(j) : {};
  }

  static int get(String id) {
    final day = _all()[dayKey(DateTime.now())];
    return day is Map && day[id] is num ? (day[id] as num).toInt() : 0;
  }

  static Future<void> set(String id, int v) async {
    final all = _all();
    final k = dayKey(DateTime.now());
    final day =
        all[k] is Map ? Map<String, dynamic>.from(all[k]) : <String, dynamic>{};
    if (v <= 0) {
      day.remove(id);
    } else {
      day[id] = v;
    }
    all[k] = day;
    final keys = all.keys.toList()..sort();
    while (keys.length > 3) {
      all.remove(keys.removeAt(0));
    }
    await Store.setJson('azkar_prog', all);
  }

  static int doneIn(AzkarCategory c) =>
      c.items.where((z) => get(z.id) >= z.count).length;
}

class AzkarPage extends StatefulWidget {
  final bool standalone;
  const AzkarPage({super.key, this.standalone = false});
  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _groups = [];
  @override
  void initState() {
    super.initState();
    _groups = AzkarProgressService.groups;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = TextEditingController();
    final selected = <String>{};
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, refresh) => AlertDialog(
                title: const Text('مجموعة أذكار جديدة'),
                content: SizedBox(
                    width: 420,
                    child: ListView(shrinkWrap: true, children: [
                      TextField(
                          controller: name,
                          decoration:
                              const InputDecoration(labelText: 'اسم المجموعة')),
                      for (final category in azkarCategories)
                        ExpansionTile(title: Text(category.title), children: [
                          for (final zikr in category.items)
                            CheckboxListTile(
                                dense: true,
                                value: selected.contains(zikr.id),
                                title: Text(zikr.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                onChanged: (value) => refresh(() {
                                      if (value == true) {
                                        selected.add(zikr.id);
                                      } else {
                                        selected.remove(zikr.id);
                                      }
                                    }))
                        ]),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('حفظ'))
                ],
              ),
            ));
    if (saved == true && name.text.trim().isNotEmpty) {
      await AzkarProgressService.saveGroup(
          DateTime.now().microsecondsSinceEpoch.toString(),
          name.text.trim(),
          selected.toList());
      if (mounted) setState(() => _groups = AzkarProgressService.groups);
    }
    name.dispose();
  }

  Future<void> _openLast() async {
    final last = AzkarProgressService.last;
    final id = last['categoryId'];
    AzkarCategory? category;
    for (final c in azkarCategories) {
      if (c.id == id) category = c;
    }
    if (category == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AzkarListPage(
            category: category!, initialZikrId: last['zikrId'] as String?)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final results = <({AzkarCategory category, Zikr zikr})>[];
    if (query.isNotEmpty) {
      for (final c in azkarCategories) {
        for (final z in c.items) {
          if ('${z.text} ${z.source} ${z.fadl} ${c.title}'
              .toLowerCase()
              .contains(query)) results.add((category: c, zikr: z));
        }
      }
    }
    return Standalone(
      on: widget.standalone,
      title: 'الأذكار',
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (!widget.standalone)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('الأذكار',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            Panel(
              onTap: () => go(context, const TasbeehPage()),
              color: cs.primary.withAlpha(26),
              child: Row(children: [
                Icon(Icons.touch_app_rounded, color: cs.primary, size: 30),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('المسبحة الإلكترونية',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16))),
                const Icon(Icons.chevron_left),
              ]),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث في الأذكار ومصادرها',
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none))),
            if (AzkarProgressService.last['categoryId'] != null)
              TextButton.icon(
                  onPressed: _openLast,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('متابعة آخر ذكر')),
            Row(children: [
              const Expanded(
                  child: Text('مجموعاتي',
                      style: TextStyle(fontWeight: FontWeight.w800))),
              IconButton(
                  tooltip: 'إنشاء مجموعة',
                  onPressed: _createGroup,
                  icon: const Icon(Icons.create_new_folder_outlined))
            ]),
            if (_groups.isEmpty)
              const Text('أنشئ مجموعة شخصية لتنظيم الأذكار.'),
            for (final group in _groups)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_outlined),
                  title: Text('${group['name']}'),
                  subtitle:
                      Text('${(group['zikrIds'] as List? ?? []).length} ذكر'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AzkarGroupPage(group: group))),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'حذف المجموعة',
                      onPressed: () async {
                        await AzkarProgressService.deleteGroup(
                            '${group['id']}');
                        if (mounted)
                          setState(() => _groups = AzkarProgressService.groups);
                      })),
            if (query.isNotEmpty) ...[
              Text('نتائج البحث (${results.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final result in results.take(60))
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(result.zikr.text,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${result.category.title} · ${result.zikr.source}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AzkarListPage(
                              category: result.category,
                              initialZikrId: result.zikr.id)));
                      if (mounted) setState(() {});
                    }),
            ],
            const SizedBox(height: 14),
            if (query.isEmpty)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final c in azkarCategories)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AzkarListPage(category: c)));
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: gold.withAlpha(70)),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(c.icon, color: cs.primary, size: 30),
                              Text(c.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  '${ar(AzkarProgress.doneIn(c))} / ${ar(c.items.length)} اكتمل اليوم',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface.withAlpha(150))),
                            ]),
                      ),
                    ),
                ],
              ),
            const DeveloperSignature(),
          ]),
    );
  }
}

class AzkarListPage extends StatefulWidget {
  final AzkarCategory category;
  final String? initialZikrId;
  const AzkarListPage({super.key, required this.category, this.initialZikrId});
  @override
  State<AzkarListPage> createState() => _AzkarListPageState();
}

class _AzkarListPageState extends State<AzkarListPage> {
  @override
  void initState() {
    super.initState();
    AzkarProgressService.saveLast(
        categoryId: widget.category.id, zikrId: widget.initialZikrId);
  }

  Future<void> _tap(Zikr z) async {
    final cur = AzkarProgress.get(z.id);
    if (cur >= z.count) return;
    if (Settings.i.haptic) {
      cur + 1 >= z.count
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick();
    }
    await AzkarProgress.set(z.id, cur + 1);
    await AzkarProgressService.saveLast(
        categoryId: widget.category.id, zikrId: z.id, count: cur + 1);
    if (widget.category.items
        .every((item) => AzkarProgress.get(item.id) >= item.count)) {
      await ActivityService.mark('azkar');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final cs = Theme.of(context).colorScheme;
    final done = AzkarProgress.doneIn(c);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.title),
        actions: [
          IconButton(
            tooltip: 'إعادة العدّ',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              for (final z in c.items) {
                await AzkarProgress.set(z.id, 0);
              }
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: [
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: done / c.items.length, minHeight: 8),
                ),
              ),
              const SizedBox(width: 10),
              Text('${ar(done)}/${ar(c.items.length)}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            for (final z in c.items)
              Builder(builder: (context) {
                final cur = AzkarProgress.get(z.id);
                final finished = cur >= z.count;
                final full = '${z.text}\n\n${z.source}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Opacity(
                    opacity: finished ? .55 : 1,
                    child: Panel(
                      onTap: () => _tap(z),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(z.text,
                                style: const TextStyle(
                                    fontSize: 18,
                                    height: 2,
                                    fontWeight: FontWeight.w600)),
                            if (z.fadl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(z.fadl,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.7,
                                      color: cs.primary)),
                            ],
                            const SizedBox(height: 4),
                            Text(z.source,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurface.withAlpha(150))),
                            const SizedBox(height: 6),
                            Row(children: [
                              FavButton(
                                  type: 'zikr',
                                  id: z.id,
                                  text: z.text,
                                  source: z.source),
                              IconButton(
                                  onPressed: () => copyText(context, full),
                                  icon: const Icon(Icons.copy_rounded)),
                              IconButton(
                                  onPressed: () => shareText(context, full),
                                  icon: const Icon(Icons.share_rounded)),
                              const Spacer(),
                              if (finished)
                                const Icon(Icons.check_circle,
                                    color: gold, size: 32)
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: cs.primary,
                                      borderRadius: BorderRadius.circular(14)),
                                  child: Text('${ar(cur)} / ${ar(z.count)}',
                                      style: TextStyle(
                                          color: cs.onPrimary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ),
                            ]),
                          ]),
                    ),
                  ),
                );
              }),
          ]),
    );
  }
}

class AzkarGroupPage extends StatefulWidget {
  final Map<String, dynamic> group;
  const AzkarGroupPage({super.key, required this.group});
  @override
  State<AzkarGroupPage> createState() => _AzkarGroupPageState();
}

class _AzkarGroupPageState extends State<AzkarGroupPage> {
  late final List<({AzkarCategory category, Zikr zikr})> items;

  @override
  void initState() {
    super.initState();
    final ids =
        (widget.group['zikrIds'] as List? ?? []).map((id) => '$id').toSet();
    items = [
      for (final category in azkarCategories)
        for (final zikr in category.items)
          if (ids.contains(zikr.id)) (category: category, zikr: zikr),
    ];
  }

  Future<void> _increment(AzkarCategory category, Zikr zikr) async {
    final current = AzkarProgress.get(zikr.id);
    if (current >= zikr.count) return;
    await AzkarProgress.set(zikr.id, current + 1);
    await AzkarProgressService.saveLast(
      categoryId: category.id,
      zikrId: zikr.id,
      count: current + 1,
    );
    if (items
        .every((item) => AzkarProgress.get(item.zikr.id) >= item.zikr.count)) {
      await ActivityService.mark('azkar');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.group['name']}')),
        body: items.isEmpty
            ? const Center(child: Text('هذه المجموعة فارغة.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final zikr = item.zikr;
                  final current = AzkarProgress.get(zikr.id);
                  return Panel(
                    onTap: () => _increment(item.category, zikr),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.category.title,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(zikr.text,
                            style: const TextStyle(fontSize: 18, height: 1.9)),
                        if (zikr.fadl.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(zikr.fadl,
                              style:
                                  const TextStyle(fontSize: 12, height: 1.6)),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: Text(zikr.source,
                                  style: const TextStyle(fontSize: 11))),
                          Text('${ar(current)} / ${ar(zikr.count)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                      ],
                    ),
                  );
                },
              ),
      );
}
