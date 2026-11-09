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
      ]);
      if (!mounted) return;
      setState(() {
        users = List<Map<String, dynamic>>.from(results[0] as List);
        overview = Map<String, dynamic>.from(results[1] as Map);
        players = List<Map<String, dynamic>>.from(results[2] as List);
        questions = List<Map<String, dynamic>>.from(results[3] as List);
        daily = List<Map<String, dynamic>>.from(results[4] as List);
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
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('البنك السحابي: ${overview['questions'] ?? 0} سؤال نشط. يمكن إدارة الأسئلة والتحدي اليومي من التبويبات الأخرى.', style: const TextStyle(height: 1.5)))),
  ]));

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
    Row(children: [Text('الأسئلة: ${questions.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const Spacer(), FilledButton.icon(onPressed: _newQuestion, icon: const Icon(Icons.add), label: const Text('إضافة'))]),
    const SizedBox(height: 10),
    ...questions.take(250).map((q) => Card(child: ListTile(
      title: Text('${q['id']} • Level ${q['level']}'),
      subtitle: Text('${q['surah_name']} ${q['ayah_number']} • ${q['difficulty']}\n${q['full_ayah']}'),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'toggle') { await GameCloudService.ownerSetQuestionActive('${q['id']}', q['active'] != true); await _load(); } }, itemBuilder: (_) => [PopupMenuItem(value: 'toggle', child: Text(q['active'] == true ? 'تعطيل' : 'تفعيل'))]),
    ))),
    if (questions.length > 250) const Padding(padding: EdgeInsets.all(16), child: Text('يتم عرض أول 250 سؤالًا لتجنب تحميل لوحة المالك بشكل ثقيل.')),
  ]);

  Future<void> _newQuestion() async {
    final id = TextEditingController(); final ayah = TextEditingController(); final word = TextEditingController(); final verse = TextEditingController(); final level = TextEditingController(text: '1'); final options = List.generate(4, (_) => TextEditingController());
    final saved = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('إضافة سؤال'), content: SingleChildScrollView(child: Column(children: [TextField(controller: id, decoration: const InputDecoration(labelText: 'ID')), TextField(controller: verse, decoration: const InputDecoration(labelText: 'نص الآية')), TextField(controller: word, decoration: const InputDecoration(labelText: 'الكلمة المخفية')), TextField(controller: ayah, decoration: const InputDecoration(labelText: 'رقم الآية'), keyboardType: TextInputType.number), TextField(controller: level, decoration: const InputDecoration(labelText: 'المستوى 1-100'), keyboardType: TextInputType.number), ...options.asMap().entries.map((e) => TextField(controller: e.value, decoration: InputDecoration(labelText: 'الخيار ${e.key + 1}')))])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))]));
    if (saved != true) return;
    if (id.text.trim().isEmpty || verse.text.trim().isEmpty || word.text.trim().isEmpty || options.any((x) => x.text.trim().isEmpty)) return;
    try {
      final opts = options.map((x) => x.text.trim()).toList();
      await GameCloudService.ownerUpsertQuestion({'id': id.text.trim(), 'surah_number': 1, 'surah_name': 'غير محدد', 'ayah_number': int.tryParse(ayah.text) ?? 1, 'full_ayah': verse.text.trim(), 'hidden_word': word.text.trim(), 'options': opts, 'correct_option': word.text.trim(), 'difficulty': 'easy', 'level': (int.tryParse(level.text) ?? 1).clamp(1, 100), 'active': true});
      await _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e'))); }
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
