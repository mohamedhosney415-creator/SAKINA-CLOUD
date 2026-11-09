import 'package:flutter/material.dart';
import '../cloud/game_cloud_service.dart';
import '../cloud/cloud_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool loading = true;
  String? error;
  int tab = 0;
  Map<String, dynamic> overview = {};
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> daily = [];
  int quranMix = 50;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final owner = await CloudService.isOwner();
      if (!owner) throw Exception('Owner access required');
      final results = await Future.wait([
        CloudService.adminUsers(),
        GameCloudService.ownerSummary(),
        GameCloudService.ownerPlayers(),
        GameCloudService.ownerQuestions(),
        GameCloudService.ownerDailyChallenges(),
        GameCloudService.fetchQuestionMix().catchError((_) => 50),
      ]);
      if (!mounted) return;
      setState(() {
        users = List<Map<String, dynamic>>.from(results[0] as List);
        overview = Map<String, dynamic>.from(results[1] as Map);
        players = List<Map<String, dynamic>>.from(results[2] as List);
        questions = List<Map<String, dynamic>>.from(results[3] as List);
        daily = List<Map<String, dynamic>>.from(results[4] as List);
        quranMix = results[5] as int;
      });
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة المالك'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: loading ? const Center(child: CircularProgressIndicator()) : error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('إعادة المحاولة'))])))
          : IndexedStack(index: tab, children: [_overview(), _players(), _questions(), _daily()]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'نظرة عامة'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'اللاعبون'),
        NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: 'الأسئلة'),
        NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'التحدي اليومي'),
      ]),
    );
  }

  Widget _metric(String title, dynamic value, IconData icon) => Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(title), trailing: Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))));

  Widget _overview() => RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
    const Text('SAKINA Game Cloud', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    const SizedBox(height: 12),
    _metric('إجمالي الحسابات', users.length, Icons.people_alt_outlined),
    _metric('لاعبو أكمل الآية', overview['players'] ?? 0, Icons.sports_esports_outlined),
    _metric('الأسئلة النشطة', overview['questions'] ?? 0, Icons.menu_book_outlined),
    _metric('الأحداث آخر 24 ساعة', overview['events_24h'] ?? 0, Icons.bolt_outlined),
    _metric('الأحداث آخر 7 أيام', overview['events_7d'] ?? 0, Icons.insights_outlined),
    _metric('وصلوا للمستوى 100', overview['level_100_players'] ?? 0, Icons.emoji_events_outlined),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('البنك السحابي: ${overview['questions'] ?? 0} سؤال نشط، منها ${questions.where((q) => q['question_type'] == 'islamic').length} ثقافة إسلامية و${questions.where((q) => q['question_type'] != 'islamic').length} سؤال قرآني.', style: const TextStyle(height: 1.5)))),
    _mixSettings(),
  ]));

  Widget _mixSettings() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('توزيع الأسئلة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('القرآن الكريم: $quranMix%  •  الثقافة الإسلامية: ${100 - quranMix}%'),
              Slider(
                value: quranMix.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$quranMix%',
                onChanged: (value) => setState(() => quranMix = value.round()),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await GameCloudService.ownerSetQuestionMix(quranMix);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ توزيع الأسئلة')));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ التوزيع: $e')));
                    }
                  },
                  child: const Text('حفظ التوزيع'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _players() => RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(12), children: [
    ...players.map((p) => Card(child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text('${p['display_name'] ?? p['email'] ?? 'مستخدم'}'),
      subtitle: Text('Level ${p['level'] ?? 1} • Score ${p['score'] ?? 0} • Noor ${p['noor'] ?? 0}\nإجابات: ${p['correct_answers'] ?? 0}/${p['total_questions'] ?? 0} • Streak: ${p['streak'] ?? 0}'),
      trailing: IconButton(icon: const Icon(Icons.tune), onPressed: () => _adjustNoor(p)),
    ))),
    if (players.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('لا يوجد لاعبون بعد'))),
  ]));

  Future<void> _adjustNoor(Map<String, dynamic> p) async {
    final controller = TextEditingController();
    final reason = TextEditingController(text: 'Owner adjustment');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('تعديل نور اللعبة'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('الرصيد الحالي: ${p['noor'] ?? 0}'), TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الفرق (+ أو -)')), TextField(controller: reason, decoration: const InputDecoration(labelText: 'السبب'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))]));
    if (ok != true) return;
    final delta = int.tryParse(controller.text.trim());
    if (delta == null || delta == 0) return;
    try { await GameCloudService.ownerAdjustNoor(userId: '${p['user_id']}', delta: delta, reason: reason.text.trim().isEmpty ? 'Owner adjustment' : reason.text.trim()); await _load(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل الرصيد'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التعديل: $e'))); }
  }

  Widget _questions() => ListView(padding: const EdgeInsets.all(12), children: [
    Row(children: [
      Text('الأسئلة: ${questions.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      const Spacer(),
      FilledButton.icon(onPressed: () => _newQuestion(), icon: const Icon(Icons.add), label: const Text('إضافة')),
    ]),
    const SizedBox(height: 10),
    ...questions.take(250).map((q) => Card(child: ListTile(
      title: Text('${q['id']} • Level ${q['level']} • ${q['question_type'] == 'islamic' ? 'ثقافة إسلامية' : 'قرآن'}'),
      subtitle: Text(q['question_type'] == 'islamic'
          ? '${q['question_text']}\nالمصدر: ${q['source_name'] ?? ''} • ${q['source_reference'] ?? ''}'
          : '${q['surah_name']} ${q['ayah_number']} • ${q['difficulty']}\n${q['full_ayah']}'),
      isThreeLine: true,
      onTap: () => _newQuestion(existing: q),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'toggle') {
            await GameCloudService.ownerSetQuestionActive('${q['id']}', q['active'] != true);
            await _load();
          } else if (v == 'edit') {
            await _newQuestion(existing: q);
          } else if (v == 'delete') {
            final ok = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('حذف السؤال؟'),
                content: Text('سيتم حذف السؤال ${q['id']} من البنك السحابي.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                  FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
                ],
              ),
            );
            if (ok == true) {
              try {
                await GameCloudService.ownerDeleteQuestion('${q['id']}');
                await _load();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
              }
            }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('تعديل')),
          PopupMenuItem(value: 'toggle', child: Text(q['active'] == true ? 'تعطيل' : 'تفعيل')),
          const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ],
      ),
    ))),
    if (questions.length > 250) const Padding(padding: EdgeInsets.all(16), child: Text('يتم عرض أول 250 سؤالًا لتجنب تحميل لوحة المالك بشكل ثقيل.')),
  ]);

  Future<void> _newQuestion({Map<String, dynamic>? existing}) async {
    final id = TextEditingController(text: '${existing?['id'] ?? ''}');
    final verse = TextEditingController(text: '${existing?['full_ayah'] ?? ''}');
    final word = TextEditingController(text: '${existing?['hidden_word'] ?? ''}');
    final prompt = TextEditingController(text: '${existing?['question_text'] ?? ''}');
    final level = TextEditingController(text: '${existing?['level'] ?? 1}');
    final surahNumber = TextEditingController(text: '${existing?['surah_number'] ?? 1}');
    final surahName = TextEditingController(text: '${existing?['surah_name'] ?? ''}');
    final ayah = TextEditingController(text: '${existing?['ayah_number'] ?? 1}');
    final sourceName = TextEditingController(text: '${existing?['source_name'] ?? ''}');
    final sourceReference = TextEditingController(text: '${existing?['source_reference'] ?? ''}');
    final contextText = TextEditingController(text: '${existing?['context_text'] ?? ''}');
    final rawOptions = existing?['options'];
    final options = List.generate(4, (i) => TextEditingController(
      text: rawOptions is List && i < rawOptions.length ? '${rawOptions[i]}' : '',
    ));
    final correctAnswer = TextEditingController(text: '${existing?['correct_option'] ?? ''}');
    String questionType = '${existing?['question_type'] ?? 'quran'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة سؤال' : 'تعديل السؤال'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(children: [
                DropdownButtonFormField<String>(
                  value: questionType,
                  decoration: const InputDecoration(labelText: 'نوع السؤال'),
                  items: const [
                    DropdownMenuItem(value: 'quran', child: Text('القرآن الكريم')),
                    DropdownMenuItem(value: 'islamic', child: Text('ثقافة إسلامية')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => questionType = value);
                  },
                ),
                TextField(controller: id, readOnly: existing != null, decoration: const InputDecoration(labelText: 'ID')),
                if (questionType == 'quran') ...[
                  TextField(controller: surahNumber, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم السورة')),
                  TextField(controller: surahName, decoration: const InputDecoration(labelText: 'اسم السورة')),
                  TextField(controller: ayah, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم الآية')),
                  TextField(controller: verse, decoration: const InputDecoration(labelText: 'نص الآية')),
                  TextField(controller: word, decoration: const InputDecoration(labelText: 'الكلمة المطلوبة')),
                  TextField(controller: contextText, maxLines: 3, decoration: const InputDecoration(labelText: 'سياق الآيات (اختياري)')),
                ] else
                  TextField(controller: prompt, maxLines: 3, decoration: const InputDecoration(labelText: 'نص السؤال الديني')),
                TextField(controller: level, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المستوى 1-100')),
                for (var i = 0; i < options.length; i++)
                  TextField(controller: options[i], decoration: InputDecoration(labelText: 'الخيار ${i + 1}')),
                TextField(controller: correctAnswer, decoration: const InputDecoration(labelText: 'الإجابة الصحيحة (يجب أن تطابق أحد الخيارات)')),
                if (questionType == 'islamic') ...[
                  TextField(controller: sourceName, decoration: const InputDecoration(labelText: 'المصدر')),
                  TextField(controller: sourceReference, decoration: const InputDecoration(labelText: 'المرجع / رقم الحديث أو الآية')),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final opts = options.map((x) => x.text.trim()).toList();
    final correct = questionType == 'quran' ? word.text.trim() : correctAnswer.text.trim();
    final valid = id.text.trim().isNotEmpty &&
        opts.every((x) => x.isNotEmpty) &&
        opts.toSet().length == 4 &&
        opts.contains(correct) &&
        (questionType == 'quran'
            ? verse.text.trim().isNotEmpty && word.text.trim().isNotEmpty && verse.text.contains(word.text.trim())
            : prompt.text.trim().isNotEmpty && sourceName.text.trim().isNotEmpty && sourceReference.text.trim().isNotEmpty);
    if (!valid) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('راجع السؤال والاختيارات والإجابة والمصدر قبل الحفظ.')));
      return;
    }
    try {
      await GameCloudService.ownerUpsertQuestion({
        'id': id.text.trim(),
        'question_type': questionType,
        'question_text': prompt.text.trim(),
        'context_text': contextText.text.trim(),
        'source_name': sourceName.text.trim(),
        'source_reference': sourceReference.text.trim(),
        'surah_number': questionType == 'quran' ? (int.tryParse(surahNumber.text) ?? 1) : 0,
        'surah_name': questionType == 'quran' ? surahName.text.trim() : '',
        'ayah_number': questionType == 'quran' ? (int.tryParse(ayah.text) ?? 1) : 0,
        'full_ayah': questionType == 'quran' ? verse.text.trim() : '',
        'hidden_word': questionType == 'quran' ? word.text.trim() : '',
        'options': opts,
        'correct_option': correct,
        'difficulty': '${existing?['difficulty'] ?? 'easy'}',
        'level': (int.tryParse(level.text) ?? 1).clamp(1, 100),
        'active': existing?['active'] != false,
      });
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    }
  }

  Widget _daily() => ListView(padding: const EdgeInsets.all(12), children: [
    Row(children: [const Text('Daily Challenge', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const Spacer(), FilledButton(onPressed: _newDaily, child: const Text('تعيين'))]),
    const SizedBox(height: 10),
    ...daily.map((d) => Card(child: ListTile(leading: const Icon(Icons.today), title: Text('${d['date_key']}'), subtitle: Text('Question: ${d['question_id']} • Reward: ${d['reward']} Noor'), trailing: Icon(d['active'] == true ? Icons.check_circle : Icons.pause_circle)))),
    if (daily.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('لا يوجد Daily Challenge'))),
  ]);

  Future<void> _newDaily() async {
    final date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10)); final q = TextEditingController(); final reward = TextEditingController(text: '30');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('تعيين تحدي يومي'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: date, decoration: const InputDecoration(labelText: 'التاريخ YYYY-MM-DD')), TextField(controller: q, decoration: const InputDecoration(labelText: 'Question ID')), TextField(controller: reward, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المكافأة'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))]));
    if (ok != true || q.text.trim().isEmpty) return;
    try { await GameCloudService.ownerSetDailyChallenge(dateKey: date.text.trim(), questionId: q.text.trim(), reward: int.tryParse(reward.text) ?? 30); await _load(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e'))); }
  }
}
