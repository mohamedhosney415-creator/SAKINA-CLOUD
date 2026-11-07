import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import '../cloud/cloud_service.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../services/notification_service.dart';
import 'city_picker.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingPage({super.key, required this.onComplete});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _name = TextEditingController(text: Settings.i.userName);
  int step = 0, target = Settings.i.intOf('tasbeehTarget', 33);
  bool busy = false, notifications = Settings.i.notificationsOn, adhan = Settings.i.adhanOn;
  String muezzin = Settings.i.muezzin;
  final titles = const ['أهلًا بك في سكينة','خلّينا نتعرف عليك','حدد مكانك','جهّز الأذان','فعّل التنبيهات','حدد ورد التسبيح','كل شيء جاهز'];

  Future<void> next() async {
    if (step == 1) await Settings.i.set('userName', _name.text.trim());
    if (step == 3) {
      await Settings.i.set('muezzin', muezzin);
      await Settings.i.set('notifOn', notifications);
      await Settings.i.set('adhanOn', adhan);
    }
    if (step == 5) await Settings.i.set('tasbeehTarget', target);
    if (step < titles.length - 1) { setState(() => step++); return; }
    setState(() => busy = true);
    await Settings.i.set('userName', _name.text.trim());
    await Settings.i.set('muezzin', muezzin);
    await Settings.i.set('notifOn', notifications);
    await Settings.i.set('adhanOn', adhan);
    await Settings.i.set('tasbeehTarget', target);
    await Store.setFlag('onboardingComplete', true);
    await NotificationService.ensureScheduled(force: true);
    if (CloudService.enabled && CloudService.signedIn) {
      try { await CloudService.pushLocalData(); } catch (_) {}
    }
    if (mounted) widget.onComplete();
  }

  Future<void> permissions() async {
    setState(() => busy = true);
    await NotificationService.requestPermissions();
    await NotificationService.requestNotificationsOnly();
    if (mounted) setState(() => busy = false);
  }

  Future<void> batterySettings() async {
    try {
      await const AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:com.hosny.sakina',
      ).launch();
    } catch (_) {}
  }

  Widget content(BuildContext context, int i) {
    final cs = Theme.of(context).colorScheme;
    switch (i) {
      case 0:
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.nights_stay_rounded, size: 76, color: cs.primary),
          const SizedBox(height: 24),
          const Text('سكينة… رفيق يومك', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text('مواقيت الصلاة والأذان والقرآن والأذكار في مكان واحد. هنجهّز التطبيق مع بعض في خطوات بسيطة.', textAlign: TextAlign.center, style: TextStyle(height: 1.9)),
        ]);
      case 1:
        return Column(children: [
          const Text('تحب نناديك بإيه؟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسمك أو الاسم المفضل')),
          const SizedBox(height: 8),
          const Text('الاسم اختياري وهيظهر في التحية.', textAlign: TextAlign.center),
        ]);
      case 2:
        return Column(children: [
          const Icon(Icons.location_on_rounded, size: 48),
          const Text('اختار محافظتك ومدينتك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Text('حساب المواقيت يتم محليًا دون طلب GPS.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Card(child: ListTile(
            title: Text(Settings.i.gov), subtitle: Text(Settings.i.cityName),
            trailing: const Icon(Icons.chevron_left),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CityPickerPage()));
              if (mounted) setState(() {});
            },
          )),
        ]);
      case 3:
        final voices = AdhanAudio.muezzins();
        return Column(children: [
          const Icon(Icons.volume_up_rounded, size: 48),
          const Text('اختار صوت الأذان', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: voices.any((v) => v.id == muezzin) ? muezzin : voices.first.id,
            items: [for (final v in voices) DropdownMenuItem(value: v.id, child: Text(v.label, overflow: TextOverflow.ellipsis))],
            onChanged: (v) { if (v != null) setState(() => muezzin = v); },
            decoration: const InputDecoration(labelText: 'المؤذن'),
          ),
          SwitchListTile(title: const Text('تشغيل الأذان عند دخول الوقت'), value: adhan, onChanged: (v) => setState(() => adhan = v)),
          const Text('يمكن تنزيل الصوت وتحديد صوت خاص للفجر لاحقًا من إعدادات الأذان.', textAlign: TextAlign.center),
        ]);
      case 4:
        return Column(children: [
          const Icon(Icons.notifications_active_rounded, size: 48),
          const Text('خلّي سكينة تفكّرك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SwitchListTile(title: const Text('تفعيل الإشعارات'), subtitle: const Text('الأذان والتذكير والورد'), value: notifications, onChanged: (v) => setState(() => notifications = v)),
          FilledButton.icon(onPressed: busy ? null : permissions, icon: const Icon(Icons.verified_user_outlined), label: const Text('طلب أذونات الإشعارات والمنبهات')),
          OutlinedButton.icon(onPressed: batterySettings, icon: const Icon(Icons.battery_saver_outlined), label: const Text('فتح إعدادات التطبيق والبطارية')),
          const Text('اسمح بالإشعارات والمنبهات الدقيقة، وقلّل قيود البطارية أو فعّل التشغيل التلقائي إن توفر. تختلف الخطوات حسب الهاتف، ولا يمكن للتطبيق العمل بعد إيقافه إجباريًا من إعدادات النظام.', style: TextStyle(height: 1.7)),
        ]);
      case 5:
        return Column(children: [
          const Icon(Icons.local_fire_department_rounded, size: 48),
          const Text('حدد هدف التسبيح اليومي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Text('الاستريك يتحسب عند إكمال إجمالي هدف التسبيح من كل الأذكار.', textAlign: TextAlign.center),
          for (final v in [33, 100, 1000])
            RadioListTile<int>(value: v, groupValue: target, title: Text(v.toString() + ' تسبيحة يوميًا'), onChanged: (n) { if (n != null) setState(() => target = n); }),
        ]);
      default:
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_rounded, size: 76, color: cs.primary),
          const SizedBox(height: 20),
          const Text('سكينة جاهزة ليومك', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const Text('تقدر تعدّل كل الإعدادات في أي وقت. ربنا يجعل التطبيق سبب خير وطمأنينة.', textAlign: TextAlign.center, style: TextStyle(height: 1.9)),
        ]);
    }
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          Row(children: [
            Icon(Icons.shield_moon_rounded, color: cs.primary),
            const SizedBox(width: 8),
            const Text('SAKINA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const Spacer(),
            Text((step + 1).toString() + ' / ' + titles.length.toString()),
          ]),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: (step + 1) / titles.length, minHeight: 5),
          const SizedBox(height: 18),
          Text(titles[step], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Expanded(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: SingleChildScrollView(key: ValueKey(step), child: content(context, step)),
          )),
          const SizedBox(height: 12),
          Row(children: [
            if (step > 0) TextButton(onPressed: busy ? null : () => setState(() => step--), child: const Text('رجوع')),
            const Spacer(),
            FilledButton.icon(
              onPressed: busy ? null : next,
              icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(step == titles.length - 1 ? Icons.check : Icons.arrow_back),
              label: Text(step == titles.length - 1 ? 'ابدأ استخدام سكينة' : 'متابعة'),
            ),
          ]),
        ]),
      ))),
    );
  }
}
