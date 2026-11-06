import 'package:flutter/material.dart';
import 'app.dart';
import 'core/diag.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'services/favorites.dart';
import 'services/notification_service.dart';
import 'cloud/cloud_service.dart';
import 'features/auth_page.dart';

/// الإقلاع الخفيف: نجهّز فقط ما تحتاجه الشاشة الأولى ثم نشغّل الواجهة فورًا.
/// باقي الخدمات (الصوت، الإشعارات، الجدولة) تُهيَّأ بعد ظهور الواجهة وأي خطأ فيها يُسجَّل.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Diag.install();
  await Diag.guard('storage', () async {
    await Store.init();
    Settings.i.load();
    Favorites.i.load();
  });
  try {
    await CloudService.init();
    NotificationService.initTimeZones();
    Diag.i.ok('timezones');
  } catch (e, s) {
    Diag.i.error('timezones', e, s);
  }
  runApp(const SakinaApp());
}
