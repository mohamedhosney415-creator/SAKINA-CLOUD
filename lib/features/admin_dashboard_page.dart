import 'package:flutter/material.dart';

import '../cloud/cloud_service.dart';
import '../cloud/game_cloud_service.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int tab = 0;
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      if (!await CloudService.isOwner()) throw Exception('Owner access required');
      final results = await Future.wait([
        GameCloudService.ownerSummary(),
        CloudService.adminUsers(),
        GameCloudService.ownerQuestions(),
      ]);
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(results[0] as Map);
        users = List<Map<String, dynamic>>.from(results[1] as List);
        questions = List<Map<String, dynamic>>.from(results[2] as List);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل لوحة المالك. تأكد من صلاحيات الحساب والاتصال.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('لوحة المالك')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('لوحة المالك')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_rounded, size: 52),
                const SizedBox(height: 12),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المالك'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [_overview(), _users(), _questions()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'المستخدمون'),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz_rounded), label: 'اللعبة'),
        ],
      ),
    );
  }

  Widget _overview() {
    final cards = <(String, String, IconData)>[
      ('المستخدمون', '${users.length}', Icons.people_rounded),
      ('لاعبو اللعبة', '${summary['players'] ?? 0}', Icons.sports_esports_rounded),
      ('الأسئلة', '${summary['questions'] ?? questions.length}', Icons.quiz_rounded),
      ('إجابات 24 ساعة', '${summary['events_24h'] ?? 0}', Icons.bolt_rounded),
      ('إجابات 7 أيام', '${summary['events_7d'] ?? 0}', Icons.insights_rounded),
      ('تحديات يومية', '${summary['daily_challenges'] ?? 0}', Icons.today_rounded),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF143B36), Color(0xFF2B675C)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFE6C77A), size: 34),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لوحة مالك سكينة', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('مراقبة التطبيق وإدارة محتوى اللعبة', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            for (final card in cards)
              Panel(
                child: Row(
                  children: [
                    SakinaIconBadge(icon: card.$3, size: 43, iconSize: 22),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(card.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('حالة لوحة اللعبة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              _line('إجابات صحيحة خلال 7 أيام', '${summary['correct_7d'] ?? 0}'),
              _line('لاعبون وصلوا للمستوى 100', '${summary['level_100_players'] ?? 0}'),
              _line('إجمالي الأسئلة النشطة', '${summary['questions'] ?? 0}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(children: [
      Expanded(child: Text(title)),
      Text(value, style: const TextStyle(color: goldDeep, fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _users() {
    if (users.isEmpty) {
      return const EmptyState(icon: Icons.people_outline_rounded, text: 'لا يوجد مستخدمون.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final role = '${u['role'] ?? 'user'}';
        final name = '${u['display_name'] ?? ''}'.trim();
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SakinaIconBadge(
                icon: role == 'owner' ? Icons.verified_user_rounded : Icons.person_rounded,
                size: 44,
                iconSize: 22,
              ),
              title: Text(
                name.isEmpty ? '${u['email'] ?? 'مستخدم'}' : name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${u['email'] ?? 'بدون بريد'}\nآخر نشاط: ${_date(u['last_seen_at'])}'),
              isThreeLine: true,
              trailing: role == 'owner'
                  ? const Chip(label: Text('مالك'))
                  : PopupMenuButton<String>(
                      onSelected: (action) async {
                        try {
                          if (action == 'message') {
                            await _messageUser(u);
                          } else if (action == 'block') {
                            await CloudService.blockUser('${u['id']}', reason: 'حظر من المالك');
                          } else if (action == 'unblock') {
                            await CloudService.unblockUser('${u['id']}');
                          }
                          await _load();
                        } catch (_) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تنفيذ العملية.')));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'message', child: Text('إرسال رسالة')),
                        PopupMenuItem(value: 'block', child: Text('حظر المستخدم')),
                        PopupMenuItem(value: 'unblock', child: Text('إلغاء الحظر')),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _questions() {
    if (questions.isEmpty) {
      return const EmptyState(icon: Icons.quiz_outlined, text: 'لا توجد أسئلة في قاعدة البيانات.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        final active = q['active'] != false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${q['level'] ?? 1}')),
              title: Text(
                '${q['surah_name'] ?? q['surahName'] ?? ''} • آية ${q['ayah_number'] ?? q['ayahNumber'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${q['difficulty'] ?? '—'} • ${active ? 'نشط' : 'متوقف'}'),
              trailing: Switch(
                value: active,
                onChanged: (value) async {
                  try {
                    await GameCloudService.ownerSetQuestionActive('${q['id']}', value);
                    if (mounted) setState(() => q['active'] = value);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر تعديل حالة السؤال.')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _messageUser(Map<String, dynamic> user) async {
    final title = TextEditingController(text: 'رسالة من سكينة');
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('رسالة إلى ${user['display_name'] ?? user['email'] ?? 'المستخدم'}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
          TextField(controller: body, maxLines: 5, decoration: const InputDecoration(labelText: 'الرسالة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok == true && body.text.trim().isNotEmpty) {
      await CloudService.sendMessage(recipientId: '${user['id']}', title: title.text.trim(), body: body.text.trim());
    }
    title.dispose(); body.dispose();
  }
  String _date(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return 'غير متاح';
    try {
      final d = DateTime.parse('$value').toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '$value';
    }
  }
}
