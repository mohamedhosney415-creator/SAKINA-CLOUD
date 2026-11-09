import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import 'events_service.dart';
import 'prayer_service.dart';
import 'widget_sync.dart';
import 'noor_service.dart';
import 'activity_service.dart';
import 'package:flutter/material.dart';
import '../features/adhan_experience_page.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> sakinaNavigatorKey =
    GlobalKey<NavigatorState>();

class Muezzin {
  final String id, label, remoteUrl;
  final String? fajrRemoteUrl;
  const Muezzin(this.id, this.label, this.remoteUrl, {this.fajrRemoteUrl});
  bool get hasFajr => fajrRemoteUrl != null;
}

/// كتالوج أصوات الأذان القابلة للتنزيل. تُحفظ الملفات محليًا بعد أول تنزيل.
/// روابط AlAdhan من صفحة Download Adhans، مع تسجيل CC0 مستقل من Wikimedia.
class AdhanAudio {
  static const _catalog = <Muezzin>[
    Muezzin('afasy', 'مشاري راشد العفاسي — نسخة دبي',
        'https://cdn.aladhan.com/audio/adhans/a4.mp3'),
    Muezzin('mishary_2', 'مشاري راشد العفاسي — النسخة الثانية',
        'https://cdn.aladhan.com/audio/adhans/a7.mp3'),
    Muezzin('mishary_3', 'مشاري راشد العفاسي — النسخة الثالثة',
        'https://cdn.aladhan.com/audio/adhans/a9.mp3'),
    Muezzin(
      'abdulbasit',
      'عبد الباسط عبد الصمد',
      'https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/Abdulbasit_Abdusamad_1_-_Egypt_(عبد_الباسط_عبد_الصمد_-_مصر).mp3',
      fajrRemoteUrl:
          'https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/Abdulbasit_Abdusamad_6_-_Fajr_Egypt_(عبد_الباسط_عبد_الصمد_-_فجر_مصر).mp3',
    ),
    Muezzin('ahmad_alnafees', 'أحمد النفيس',
        'https://cdn.aladhan.com/audio/adhans/a1.mp3'),
    Muezzin('mustafa_ozcan', 'حافظ مصطفى أوزجان',
        'https://cdn.aladhan.com/audio/adhans/a2.mp3'),
    Muezzin('mansour_zahrani', 'منصور الزهراني',
        'https://cdn.aladhan.com/audio/adhans/a11-mansour-al-zahrani.mp3'),
    Muezzin('sakina_cc0', 'أذان سكينة — تسجيل CC0',
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Beautiful_adhan.ogg'),
  ];

  static List<Muezzin> muezzins() => _catalog;

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/adhan_audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _extensionFor(String url) {
    final name = Uri.parse(url).path.toLowerCase().split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) {
      final ext = name.substring(dot + 1);
      if (const {'mp3', 'ogg', 'wav', 'm4a', 'aac'}.contains(ext)) return ext;
    }
    return 'mp3';
  }

  static Future<File> audioFile(Muezzin m, {bool fajr = false}) async {
    final dir = await _dir();
    final url = (fajr && m.hasFajr) ? m.fajrRemoteUrl! : m.remoteUrl;
    final suffix = fajr && m.hasFajr ? '_fajr' : '';
    return File('${dir.path}/${m.id}$suffix.${_extensionFor(url)}');
  }

  static Future<bool> isDownloaded(Muezzin m, {bool fajr = false}) async {
    final f = await audioFile(m, fajr: fajr);
    return f.exists().then((ok) async => ok && await f.length() > 1024);
  }

  static Future<File> download(Muezzin m, {bool fajr = false}) async {
    final target = await audioFile(m, fajr: fajr);
    if (await target.exists() && await target.length() > 1024) return target;
    final url = (fajr && m.hasFajr) ? m.fajrRemoteUrl! : m.remoteUrl;
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (response.statusCode != 200 ||
        response.bodyBytes.length < 1024 ||
        contentType.contains('text/html') ||
        contentType.contains('application/json')) {
      throw Exception('تعذر تنزيل ملف الأذان (${response.statusCode})');
    }
    final temp = File('${target.path}.part');
    await temp.writeAsBytes(response.bodyBytes, flush: true);
    if (await target.exists()) await target.delete();
    return temp.rename(target.path);
  }

  static Future<void> delete(Muezzin m) async {
    final f = await audioFile(m);
    if (await f.exists()) await f.delete();
    final fajr = await audioFile(m, fajr: true);
    if (await fajr.exists()) await fajr.delete();
  }

  static Future<Muezzin?> selected() async {
    final list = muezzins();
    for (final m in list) {
      if (m.id == Settings.i.muezzin) return m;
    }
    return list.isEmpty ? null : list.first;
  }

  /// يضمن وجود صوت الأذان المختار محليًا حتى يعمل دون اتصال لاحقًا.
  /// لا يعيد التنزيل إذا كان الملف موجودًا وسليمًا.
  static Future<void> ensureSelectedDownloaded() async {
    final m = await selected();
    if (m == null) return;
    await download(m);
    if (m.hasFajr) {
      try {
        await download(m, fajr: true);
      } catch (_) {
        // صوت الفجر الإضافي اختياري؛ لا يمنع تنزيل الصوت الأساسي.
      }
    }
  }
}

/// مهلة زوال إشعار الأذان تلقائيًا (بالميلي ثانية): مدة التسجيل + هامش.
const int adhanNotificationTimeoutMs = 165000;

class NotificationService {
  static bool ready = false;

  /// يزيل أي إشعار أذان ظاهر الآن (دون المساس بالإشعارات المجدولة القادمة).
  static Future<void> dismissAdhanNotifications() async {
    try {
      final active = await _android?.getActiveNotifications() ??
          const <ActiveNotification>[];
      for (final n in active) {
        final id = n.id;
        if (id != null && (n.channelId ?? '').startsWith('sakina_full_adhan')) {
          await notificationsPlugin.cancel(id);
        }
      }
    } catch (_) {}
  }

  /// بيانات المناطق الزمنية (متزامنة وسريعة) — تلزم قبل عرض أي مواقيت.
  static void initTimeZones() {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    } catch (_) {}
  }

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notificationsPlugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        if (payload.startsWith('adhan:')) {
          final prayerKey = payload.substring('adhan:'.length);
          sakinaNavigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => AdhanExperiencePage(prayerKey: prayerKey),
          ));
        }
      },
    );
    ready = true;
  }

  /// يتعامل مع فتح التطبيق من إشعار أذان بينما كان التطبيق مغلقًا.
  static Future<void> handleAppLaunchDetails() async {
    try {
      final details =
          await notificationsPlugin.getNotificationAppLaunchDetails();
      final payload = details?.notificationResponse?.payload ?? '';
      if (details?.didNotificationLaunchApp == true &&
          payload.startsWith('adhan:')) {
        final prayerKey = payload.substring('adhan:'.length);
        sakinaNavigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => AdhanExperiencePage(
              prayerKey: prayerKey, exitAppWhenDone: true),
        ));
      }
    } catch (_) {}
  }

  /// إذن الإشعارات فقط (لا يفتح شاشات إعدادات).
  static Future<bool> requestNotificationsOnly() async {
    try {
      return (await _android?.requestNotificationsPermission()) ?? true;
    } catch (_) {
      return false;
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<bool> notificationsAllowed() async =>
      (await _android?.areNotificationsEnabled()) ?? true;

  static Future<bool> exactAllowed() async {
    try {
      return (await _android?.canScheduleExactNotifications()) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestPermissions() async {
    bool ok = true;
    try {
      ok = (await _android?.requestNotificationsPermission()) ?? true;
    } catch (_) {}
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
    // Android 14+ may revoke full-screen-intent access. Failure must not block
    // ordinary scheduled alerts.
    await requestFullScreenIntentAccess();
    return ok;
  }

  static Future<bool> requestFullScreenIntentAccess() async {
    try {
      return (await _android?.requestFullScreenIntentPermission()) ?? true;
    } catch (_) {
      return false;
    }
  }

  // ---------- تفاصيل الإشعارات ----------
  static NotificationDetails _adhanDetails(String body) {
    final vib = Settings.i.vibrate;
    // Android notification channels can only use bundled raw resources reliably.
    // The selected/downloaded voice is private app storage and cannot be a channel
    // sound. Bundle the CC0 recording and bump this channel id when its sound changes.
    const raw = 'sakina_adhan';
    final channel = 'sakina_full_adhan_v2_${vib ? 'v' : 'n'}';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        'الأذان',
        channelDescription: 'الأذان الكامل وتنبيه دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(raw),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        autoCancel: true,
        // التسجيل المرفق مدته ٢:٣٤؛ يزول الإشعار تلقائيًا بعد انتهائه.
        timeoutAfter: adhanNotificationTimeoutMs,
        visibility: NotificationVisibility.public,
        enableVibration: vib,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
  }

  static NotificationDetails _reminderDetails(String body) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sakina_reminder',
          'تذكير قبل الصلاة',
          channelDescription: 'تذكير قبل دخول وقت الصلاة',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static NotificationDetails _generalDetails(String body) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sakina_general',
          'تنبيهات سكينة',
          channelDescription: 'السحور والإفطار والمناسبات وتذكير الورد',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static NotificationDetails _dailyMessageDetails(String body) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sakina_daily_message_v1',
          'رسالة سكينة اليومية',
          channelDescription: 'رسائل إيمانية يومية متغيرة',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static NotificationDetails _noorDetails(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          'sakina_noor_daily_v1',
          'نور يومك',
          channelDescription: 'حديث أو حكمة اليوم',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static NotificationDetails _streakDetails(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          'sakina_streak_v1',
          'تذكير الاستمرار',
          channelDescription: 'تذكير لطيف لإكمال هدف التسبيح اليومي',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static NotificationDetails _personalReminderDetails(String body) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sakina_personal_reminders_v1',
          'تذكيرات القرآن والأذكار والصيام',
          channelDescription: 'تذكيرات اختيارية قابلة للتخصيص',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static Future<void> cancelTodayStreakReminder() async {
    try {
      await notificationsPlugin.cancel(4002);
    } catch (_) {}
  }

  static Future<void> _at(int id, String title, String body, tz.TZDateTime when,
      NotificationDetails d, AndroidScheduleMode mode,
      {DateTimeComponents? repeat, String? payload}) async {
    try {
      await notificationsPlugin.zonedSchedule(id, title, body, when, d,
          androidScheduleMode: mode,
          payload: payload,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat);
    } catch (_) {}
  }

  // ---------- الجدولة ----------
  /// يعيد الجدولة إذا تغيّر اليوم أو الإعدادات.
  static Future<void> ensureScheduled({bool force = false}) async {
    if (!ready) return;
    final key = '${dayKey(cairoNow())}|${Settings.i.scheduleSignature}';
    if (!force && Store.str('sched_key') == key) {
      await WidgetSync.update();
      return;
    }
    await rescheduleAll();
    await Store.setStr('sched_key', key);
    await WidgetSync.update();
  }

  /// يجدول الأذان لأربعة عشر يومًا قادمة، ويُعاد تلقائيًا كلما فُتح التطبيق.
  static Future<void> rescheduleAll() async {
    final s = Settings.i;
    PrayerService.clearCache();
    try {
      await notificationsPlugin.cancelAll();
    } catch (_) {}
    if (!s.notificationsOn) return;
    // لا نضع إشعارات مجدولة إذا كان إذن الإشعارات ممنوعًا على النظام.
    if (!await notificationsAllowed()) return;

    final mode = (await exactAllowed())
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = cairoNow();

    for (int d = 0; d < 14; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      final day = PrayerService.forDate(date);

      for (int i = 0; i < fardPrayers.length; i++) {
        final p = fardPrayers[i];
        final at = day.t[p]!;
        final name = prayerAr[p]!;
        if (s.adhanOn && s.adhanFor(p.name) && at.isAfter(now)) {
          final body = 'حان الآن موعد أذان $name حسب توقيت ${s.cityName}';
          await _at(d * 20 + i * 3, 'حان وقت صلاة $name', body, at,
              _adhanDetails(body), mode,
              payload: 'adhan:${p.name}');
        }
        if (s.reminderOn && s.adhanFor(p.name)) {
          final r = at.subtract(Duration(minutes: s.reminderMinutes));
          if (r.isAfter(now)) {
            final body =
                'بقي ${fmtDurWords(Duration(minutes: s.reminderMinutes))} على صلاة $name';
            await _at(d * 20 + i * 3 + 1, 'اقترب وقت $name', body, r,
                _reminderDetails(body), mode);
          }
        }
      }

      // السحور والإفطار في رمضان
      if (s.ramadanAlerts && hijriOf(date).hMonth == 9) {
        final suhoor =
            day.t[Prayer.fajr]!.subtract(const Duration(minutes: 30));
        if (suhoor.isAfter(now)) {
          const body =
              'بقي نصف ساعة على أذان الفجر، تسحّروا فإن في السحور بركة.';
          await _at(1000 + d * 2, 'وقت السحور', body, suhoor,
              _generalDetails(body), mode);
        }
        final iftar =
            day.t[Prayer.maghrib]!.subtract(const Duration(minutes: 10));
        if (iftar.isAfter(now)) {
          const body = 'بقي عشر دقائق على الإفطار، فاغتنم وقت الدعاء.';
          await _at(1001 + d * 2, 'اقترب الإفطار', body, iftar,
              _generalDetails(body), mode);
        }
      }

      // رسائل يومية مستقلة القنوات والهوية.
      if (!s.quietMode && s.dailyMessageOn) {
        const messages = [
          'ابدأ يومك بنية طيبة، واجعل لك نصيبًا من الذكر مهما كان وقتك قليلًا.',
          'خذ دقيقة تهدأ فيها، واستغفر الله، فالقليل الدائم باب خير.',
          'لا تؤجل وردك؛ آيات قليلة بقلب حاضر خير من انقطاع طويل.',
          'اجعل الصلاة محطة راحة في يومك، لا مهمة تؤجلها.',
          'كل يوم فرصة جديدة للقرب من الله، فابدأ بما تستطيع.',
          'املأ وقتك بذكر لطيف، فالقلب يطمئن بذكر الله.',
          'خطوة صغيرة اليوم قد تصنع عادة جميلة تدوم.',
        ];
        final when =
            cairoDate(date.year, date.month, date.day, s.dailyMessageHour, 0);
        if (when.isAfter(now)) {
          final body = messages[(date.day + date.month) % messages.length];
          await _at(4000 + d * 3, 'رسالة سكينة لك 🌿', body, when,
              _dailyMessageDetails(body), mode);
        }
      }

      if (!s.quietMode && s.noorNotificationOn) {
        final when = cairoDate(
            date.year, date.month, date.day, s.noorNotificationHour, 0);
        if (when.isAfter(now)) {
          final item = NoorService.forDay(date);
          final body = item.text;
          await _at(4001 + d * 3, 'نور يومك • ${item.label}', body, when,
              _noorDetails(body), mode);
        }
      }

      if (!s.quietMode && s.streakReminderOn &&
          s.intOf('tasbeehTarget', 33) > 0 &&
          !(d == 0 && ActivityService.tasbeehGoalReached())) {
        final when =
            cairoDate(date.year, date.month, date.day, s.streakReminderHour, 0);
        if (when.isAfter(now)) {
          const body =
              'لسه عندك وقت تكمل هدف التسبيح اليومي. خُد دقيقة لذكرك، وربنا يتقبل منك.';
          await _at(4002 + d * 3, 'حافظ على استمراك 🌱', body, when,
              _streakDetails(body), mode);
        }
      }

      // تذكيرات شخصية مستقلة بمعرفات منفصلة عن كل الإشعارات القائمة.
      Future<void> personal(int id, bool enabled, int hour, int dayMask,
          String title, String body) async {
        if (!enabled || (dayMask & (1 << (date.weekday - 1))) == 0) return;
        final when = cairoDate(date.year, date.month, date.day, hour, 0);
        if (when.isAfter(now)) {
          await _at(
              id, title, body, when, _personalReminderDetails(body), mode);
        }
      }

      await personal(
          5000 + d,
          !s.quietMode && s.quranReminderOn,
          s.quranReminderHour,
          s.quranReminderDays,
          'تذكير القرآن الكريم',
          'حان وقت وردك من القرآن الكريم، اقرأ ما تيسّر لك.');
      await personal(
          5020 + d,
          !s.quietMode && s.morningAdhkarReminderOn,
          s.morningAdhkarReminderHour,
          s.morningAdhkarReminderDays,
          'أذكار الصباح',
          'لا تنس أذكار الصباح؛ ابدأ يومك بذكر الله.');
      await personal(
          5040 + d,
          !s.quietMode && s.eveningAdhkarReminderOn,
          s.eveningAdhkarReminderHour,
          s.eveningAdhkarReminderDays,
          'أذكار المساء',
          'حان وقت أذكار المساء والطمأنينة بذكر الله.');
      await personal(
          5060 + d,
          !s.quietMode && s.mondayFastReminderOn && date.weekday == DateTime.sunday,
          s.fastingReminderHour,
          127,
          'تذكير صيام الاثنين',
          'غدًا الاثنين؛ تذكير بصيام التطوع لمن أراد.');
      await personal(
          5080 + d,
          !s.quietMode && s.thursdayFastReminderOn && date.weekday == DateTime.wednesday,
          s.fastingReminderHour,
          127,
          'تذكير صيام الخميس',
          'غدًا الخميس؛ تذكير بصيام التطوع لمن أراد.');
    }

    // المناسبات الإسلامية القادمة
    if (!s.quietMode && s.eventAlerts) {
      final evs = EventsService.upcoming(now, horizonDays: 60);
      for (int i = 0; i < evs.length && i < 12; i++) {
        final e = evs[i];
        final when = cairoDate(e.date.year, e.date.month, e.date.day, 8, 0);
        if (when.isAfter(now)) {
          await _at(2000 + i, e.event.title, e.event.note, when,
              _generalDetails(e.event.note), mode);
        }
      }
    }

    // تذكير الورد اليومي
    if (!s.quietMode && s.khatmaReminder) {
      var when =
          cairoDate(now.year, now.month, now.day, s.khatmaHour, s.khatmaMinute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      const body =
          'حان وقت وردك من القرآن الكريم، قليل دائم خير من كثير منقطع.';
      await _at(3000, 'وردك اليومي', body, when, _generalDetails(body), mode,
          repeat: DateTimeComponents.time);
    }
  }

  /// إشعار فوري بنفس قناة الأذان لاختبار الصوت.
  static Future<void> testAdhanNotification() async {
    const body = 'هذا اختبار لصوت الأذان في الإشعارات.';
    await notificationsPlugin.show(
        9999, 'تجربة الأذان', body, _adhanDetails(body),
        payload: 'adhan:${Prayer.dhuhr.name}');
  }
}
