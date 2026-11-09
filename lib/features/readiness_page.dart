import 'package:flutter/material.dart';
import '../core/settings.dart';
import '../core/widgets.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';

class ReadinessPage extends StatefulWidget {
  const ReadinessPage({super.key});
  @override
  State<ReadinessPage> createState() => _ReadinessPageState();
}

class _ReadinessPageState extends State<ReadinessPage> {
  bool notifications = true;
  bool exactAlarms = true;
  bool adhanDownloaded = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final selected = await AdhanAudio.selected();
    final values = await Future.wait<bool>([
      NotificationService.notificationsAllowed(),
      NotificationService.exactAllowed(),
      if (selected != null) AdhanAudio.isDownloaded(selected),
    ]);
    if (!mounted) return;
    setState(() {
      notifications = values[0];
      exactAlarms = values[1];
      adhanDownloaded = selected != null && values.length > 2 && values[2];
      loading = false;
    });
  }

  Future<void> _permissions() async {
    await NotificationService.requestPermissions();
    await NotificationService.requestFullScreenIntentAccess();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('جاهزية سكينة')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          HeroCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('خلّي سكينة جاهزة ليومك',
                  style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('راجع الصلاحيات والصوت من مكان واحد.',
                  style: TextStyle(color: Colors.white.withAlpha(190), height: 1.6)),
            ]),
          ),
          const SizedBox(height: 16),
          if (loading) const LinearProgressIndicator(),
          _status('الإشعارات', 'مواقيت الصلاة والتنبيهات', notifications,
              Icons.notifications_active_outlined),
          _status('المنبهات الدقيقة', 'لضبط مواقيت الأذان بدقة', exactAlarms,
              Icons.alarm_outlined),
          _status('صوت الأذان', 'محفوظ ليعمل دون إنترنت', adhanDownloaded,
              Icons.volume_up_outlined),
          _status('الإشعارات داخل التطبيق', 'المفتاح الرئيسي', Settings.i.notificationsOn,
              Icons.tune_rounded),
          const SizedBox(height: 12),
          Panel(
            color: cs.primary.withAlpha(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إعداد الصلاحيات',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('إذا كان أي عنصر غير جاهز، اضغط الزر لطلب الصلاحيات من النظام.',
                  style: TextStyle(height: 1.6)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _permissions,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('مراجعة الصلاحيات الآن'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _status(String title, String subtitle, bool ok, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Row(children: [
          SakinaIconBadge(icon: icon, color: ok ? cs.primary : Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(145))),
            ]),
          ),
          Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: ok ? cs.primary : Colors.orange),
        ]),
      ),
    );
  }
}
