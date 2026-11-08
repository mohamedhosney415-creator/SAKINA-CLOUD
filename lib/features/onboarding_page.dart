import 'package:flutter/material.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/notification_service.dart';
import 'city_picker.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingPage({super.key, required this.onComplete});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final name = TextEditingController(text: Settings.i.userName);
  int step = 0;
  bool busy = false;
  bool notifications = Settings.i.notificationsOn;
  bool adhan = Settings.i.adhanOn;

  Future<void> next() async {
    if (step == 1) {
      await Settings.i.set('userName', name.text.trim());
    }
    if (step < 2) {
      setState(() => step++);
      return;
    }
    setState(() => busy = true);
    await Settings.i.set('userName', name.text.trim());
    await Settings.i.set('notifOn', notifications);
    await Settings.i.set('adhanOn', adhan);
    await Store.setFlag('onboardingComplete', true);
    await NotificationService.ensureScheduled(force: true);
    if (mounted) widget.onComplete();
  }

  Future<void> requestPermissions() async {
    setState(() => busy = true);
    await NotificationService.requestPermissions();
    await NotificationService.requestNotificationsOnly();
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Widget _brand(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withAlpha(18),
            border: Border.all(color: gold.withAlpha(140), width: 1.5),
          ),
          child: Icon(Icons.nights_stay_rounded, size: 48, color: cs.primary),
        ),
        const SizedBox(height: 22),
        const Text('سكينة',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('رفيقك إلى الطمأنينة اليومية',
            style: TextStyle(color: cs.onSurface.withAlpha(160))),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (step) {
      case 0:
        return Column(
          key: const ValueKey(0),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _brand(context),
            const SizedBox(height: 30),
            const Text(
              'مواقيت الصلاة والقرآن والأذكار في مكان واحد، بتجربة هادئة وبسيطة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.9),
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SakinaIconBadge(
                icon: Icons.waving_hand_rounded, color: gold, size: 66, iconSize: 32),
            const SizedBox(height: 20),
            const Text('خلّينا نجهز سكينة ليومك',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('الاسم اختياري وسيظهر في التحية فقط.',
                style: TextStyle(color: cs.onSurface.withAlpha(150))),
            const SizedBox(height: 22),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'اسمك أو الاسم المفضل',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 18),
            Panel(
              color: cs.primary.withAlpha(16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_rounded, color: gold),
                title: const Text('المدينة',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${Settings.i.gov} • ${Settings.i.cityName}'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CityPickerPage()));
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey(2),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SakinaIconBadge(
                icon: Icons.notifications_active_rounded,
                color: gold,
                size: 66,
                iconSize: 32),
            const SizedBox(height: 20),
            const Text('هل نذكّرك بالخير؟',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('يمكنك تغيير هذه الاختيارات في أي وقت من الإعدادات.',
                textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
            const SizedBox(height: 18),
            Panel(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الإشعارات',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('مواقيت الصلاة والورد اليومي'),
                    value: notifications,
                    onChanged: (v) => setState(() => notifications = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('صوت الأذان',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('سيتم تنزيل الصوت تلقائيًا عند أول تشغيل'),
                    value: adhan,
                    onChanged: notifications
                        ? (v) => setState(() => adhan = v)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: busy ? null : requestPermissions,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('السماح بالإشعارات الآن'),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_moon_rounded, color: gold),
                    const SizedBox(width: 8),
                    const Text('SAKINA',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const Spacer(),
                    Text('${step + 1} / 3',
                        style: TextStyle(color: cs.onSurface.withAlpha(150))),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: (step + 1) / 3, minHeight: 6),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: SingleChildScrollView(
                        key: ValueKey(step), child: _content(context)),
                  ),
                ),
                Row(
                  children: [
                    if (step > 0)
                      TextButton(
                          onPressed:
                              busy ? null : () => setState(() => step--),
                          child: const Text('رجوع')),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: busy ? null : next,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(step == 2
                              ? Icons.check_rounded
                              : Icons.arrow_back_rounded),
                      label: Text(step == 2 ? 'ابدأ استخدام سكينة' : 'متابعة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
