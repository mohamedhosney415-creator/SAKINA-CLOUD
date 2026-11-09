import 'package:flutter/material.dart';
import '../core/settings.dart';
import '../cloud/cloud_service.dart';
import '../core/widgets.dart';
import '../services/audio_controller.dart';
import '../services/notification_service.dart';
import '../services/quran_service.dart';
import 'about_page.dart';
import 'adhan_settings_page.dart';
import 'appearance_page.dart';
import 'backup_page.dart';
import 'city_picker.dart';
import 'diagnostics_page.dart';
import 'downloads_page.dart';
import 'offsets_page.dart';
import 'readiness_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _editName(BuildContext context) async {
    final c = TextEditingController(text: Settings.i.userName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اسمك'),
        content: TextField(
            controller: c,
            decoration: const InputDecoration(
                hintText: 'يظهر في التحية بالصفحة الرئيسية')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) await Settings.i.set('userName', c.text.trim());
  }

  Future<void> _pickDays(BuildContext context, String key, int current) async {
    final selected = <int>{
      for (var day = 1; day <= 7; day++)
        if ((current & (1 << (day - 1))) != 0) day,
    };
    const names = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('أيام التذكير'),
          content: Wrap(
            spacing: 6,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(names[day - 1]),
                  selected: selected.contains(day),
                  onSelected: (value) => setState(() {
                    value ? selected.add(day) : selected.remove(day);
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(
                  dialogContext,
                  selected.fold<int>(
                      0, (mask, day) => mask | (1 << (day - 1)))),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await Settings.i.set(key, result);
      await NotificationService.ensureScheduled(force: true);
    }
  }

  void _privacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('الخصوصية'),
        content: const SingleChildScrollView(
          child: Text(
              'يمكنك استخدام سكينة محليًا، وعند تسجيل الدخول يُستخدم حسابك لمزامنة بيانات التطبيق بين أجهزتك.\n\n'
              '• تُحفظ الإعدادات وسجل الاستخدام محليًا، وتُزامن بيانات التطبيق المرتبطة بحسابك عند تسجيل الدخول.\n'
              '• لا نبيع بياناتك ولا نستخدم إعلانات أو أدوات تتبّع.\n'
              '• لا يُطلب إذن الموقع (GPS)؛ تختار مدينتك يدويًا.\n'
              '• الإنترنت يُستخدم لتحميل نص القرآن والتلاوات عند طلبك، ثم تُحفظ الملفات للاستخدام دون اتصال.\n'
              '• النسخة الاحتياطية ملف تتحكم أنت في مكان حفظه.',
              style: TextStyle(height: 1.8)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنًا'))
        ],
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final current = Settings.i.language;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('لغة التطبيق / App language'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RadioListTile<String>(
            value: 'ar',
            groupValue: current,
            title: const Text('العربية'),
            onChanged: (v) => Navigator.pop(dialogContext, v),
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: current,
            title: const Text('English'),
            onChanged: (v) => Navigator.pop(dialogContext, v),
          ),
        ]),
      ),
    );
    if (selected != null && selected != current) {
      await Settings.i.set('language', selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListenableBuilder(
        listenable: Settings.i,
        builder: (context, _) {
          final s = Settings.i;
          Future<void> sw(String k, bool v) async {
            await s.set(k, v);
            await NotificationService.ensureScheduled(force: true);
          }

          Future<void> pickHour(String key, int hour) async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: hour, minute: 0),
            );
            if (picked == null) return;
            await s.set(key, picked.hour);
            await NotificationService.ensureScheduled(force: true);
          }

          return ListView(children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('اسمك'),
              subtitle: Text(s.userName.isEmpty ? 'غير محدد' : s.userName),
              onTap: () => _editName(context),
            ),
            const SectionTitle('الصلاة والتنبيهات'),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('جاهزية سكينة'),
              subtitle: const Text('مراجعة الإشعارات والمنبهات وصوت الأذان'),
              onTap: () => go(context, const ReadinessPage()),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('المدينة'),
              subtitle: Text('${s.gov} • ${s.cityName}'),
              onTap: () => go(context, const CityPickerPage()),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: const Text('إعدادات الأذان والمؤذن'),
              onTap: () => go(context, const AdhanSettingsPage()),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('ضبط فروق المواقيت والتاريخ الهجري'),
              onTap: () => go(context, const OffsetsPage()),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.restaurant),
              title: const Text('تنبيهات السحور والإفطار في رمضان'),
              value: s.ramadanAlerts,
              onChanged: (v) => sw('ramadanAlerts', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.event),
              title: const Text('تنبيهات المناسبات الإسلامية'),
              value: s.eventAlerts,
              onChanged: (v) => sw('eventAlerts', v),
            ),
            const SectionTitle('الإشعارات اليومية'),
            SwitchListTile(
              secondary: const Icon(Icons.wb_sunny_outlined),
              title: const Text('رسالة سكينة اليومية'),
              subtitle: const Text('رسالة إيمانية متغيرة كل يوم'),
              value: s.dailyMessageOn,
              onChanged: (v) => sw('dailyMessageOn', v),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('موعد الرسالة اليومية'),
              subtitle:
                  Text('${s.dailyMessageHour.toString().padLeft(2, '0')}:00'),
              onTap: () => pickHour('dailyMessageHour', s.dailyMessageHour),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('إشعار نور يومك'),
              subtitle: const Text('حديث أو حكمة اليوم'),
              value: s.noorNotificationOn,
              onChanged: (v) => sw('noorNotificationOn', v),
            ),
            ListTile(
              leading: const Icon(Icons.light_mode_outlined),
              title: const Text('موعد نور يومك'),
              subtitle: Text(
                  '${s.noorNotificationHour.toString().padLeft(2, '0')}:00'),
              onTap: () =>
                  pickHour('noorNotificationHour', s.noorNotificationHour),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.local_fire_department_outlined),
              title: const Text('تذكير إكمال الاستريك'),
              subtitle: const Text('يتوقف تلقائيًا بعد إكمال هدف التسبيح'),
              value: s.streakReminderOn,
              onChanged: (v) => sw('streakReminderOn', v),
            ),
            ListTile(
              leading: const Icon(Icons.nights_stay_outlined),
              title: const Text('موعد تذكير الاستريك'),
              subtitle:
                  Text('${s.streakReminderHour.toString().padLeft(2, '0')}:00'),
              onTap: () => pickHour('streakReminderHour', s.streakReminderHour),
            ),
            const SectionTitle('تذكيرات القرآن والأذكار والصيام'),
            SwitchListTile(
              secondary: const Icon(Icons.menu_book_outlined),
              title: const Text('تذكير ورد القرآن'),
              value: s.quranReminderOn,
              onChanged: (v) => sw('quranReminderOn', v),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('وقت تذكير القرآن'),
              subtitle:
                  Text('${s.quranReminderHour.toString().padLeft(2, '0')}:00'),
              onTap: () => pickHour('quranReminderHour', s.quranReminderHour),
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('أيام تذكير القرآن'),
              subtitle: const Text('اختر أيام التذكير'),
              onTap: () =>
                  _pickDays(context, 'quranReminderDays', s.quranReminderDays),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.wb_twilight),
              title: const Text('تذكير أذكار الصباح'),
              value: s.morningAdhkarReminderOn,
              onChanged: (v) => sw('morningAdhkarReminderOn', v),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('وقت أذكار الصباح'),
              subtitle: Text(
                  '${s.morningAdhkarReminderHour.toString().padLeft(2, '0')}:00'),
              onTap: () => pickHour(
                  'morningAdhkarReminderHour', s.morningAdhkarReminderHour),
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('أيام أذكار الصباح'),
              subtitle: const Text('اختر أيام التذكير'),
              onTap: () => _pickDays(context, 'morningAdhkarReminderDays',
                  s.morningAdhkarReminderDays),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.nights_stay_outlined),
              title: const Text('تذكير أذكار المساء'),
              value: s.eveningAdhkarReminderOn,
              onChanged: (v) => sw('eveningAdhkarReminderOn', v),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('وقت أذكار المساء'),
              subtitle: Text(
                  '${s.eveningAdhkarReminderHour.toString().padLeft(2, '0')}:00'),
              onTap: () => pickHour(
                  'eveningAdhkarReminderHour', s.eveningAdhkarReminderHour),
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('أيام أذكار المساء'),
              subtitle: const Text('اختر أيام التذكير'),
              onTap: () => _pickDays(context, 'eveningAdhkarReminderDays',
                  s.eveningAdhkarReminderDays),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.event_available_outlined),
              title: const Text('تذكير صيام الاثنين'),
              subtitle: const Text('في مساء اليوم السابق'),
              value: s.mondayFastReminderOn,
              onChanged: (v) => sw('mondayFastReminderOn', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.event_available_outlined),
              title: const Text('تذكير صيام الخميس'),
              subtitle: const Text('في مساء اليوم السابق'),
              value: s.thursdayFastReminderOn,
              onChanged: (v) => sw('thursdayFastReminderOn', v),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('وقت تذكير الصيام'),
              subtitle: Text(
                  '${s.fastingReminderHour.toString().padLeft(2, '0')}:00'),
              onTap: () =>
                  pickHour('fastingReminderHour', s.fastingReminderHour),
            ),
            const SectionTitle('المظهر واللغة'),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('لغة التطبيق / App language'),
              subtitle: Text(s.isEnglish ? 'English' : 'العربية'),
              onTap: () => _pickLanguage(context),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('الألوان والخط والوضع الداكن'),
              onTap: () => go(context, const AppearancePage()),
            ),
            const SectionTitle('القرآن'),
            ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('القارئ'),
              subtitle: Text(reciterById(s.reciter).name),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final r in reciters)
                        ListTile(
                          title: Text(r.name),
                          trailing: s.reciter == r.id
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () async {
                            Navigator.pop(context);
                            if (s.reciter == r.id) return;
                            try {
                              await AudioCtl.i.switchReciter(r.id);
                            } catch (_) {
                              if (context.mounted) {
                                toast(context,
                                    'تعذر تبديل التلاوة. تحقق من الاتصال ثم أعد المحاولة');
                              }
                            }
                          },
                        ),
                    ]),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('حجم خط المصحف'),
              subtitle: Slider(
                value: s.quranFont,
                min: 20,
                max: 42,
                divisions: 11,
                onChanged: (v) => s.set('quranFont', v),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.skip_next),
              title: const Text('الانتقال التلقائي للسورة التالية'),
              value: s.autoNext,
              onChanged: (v) => s.set('autoNext', v),
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
              title: const Text('إدارة الملفات المحمّلة'),
              onTap: () => go(context, const DownloadsPage()),
            ),
            const SectionTitle('البيانات'),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('النسخ الاحتياطي والاستعادة'),
              onTap: () => go(context, const BackupPage()),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('الخصوصية'),
              onTap: () => _privacy(context),
            ),
            FutureBuilder<bool>(
              future: CloudService.isOwner(),
              builder: (context, access) => access.data == true
                  ? ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      title: const Text('تشخيص التطبيق (للمالك)'),
                      onTap: () => go(context, const DiagnosticsPage()),
                    )
                  : const SizedBox.shrink(),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('عن التطبيق'),
              onTap: () => go(context, const AboutPage()),
            ),
            const DeveloperSignature(),
          ]);
        },
      ),
    );
  }
}
