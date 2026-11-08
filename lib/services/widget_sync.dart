import 'package:home_widget/home_widget.dart';
import '../core/format.dart';
import '../core/settings.dart';
import 'khatma_store.dart';
import 'prayer_service.dart';

/// يرسل المواقيت والورد المحلي لويدجت الشاشة الرئيسية.
class WidgetSync {
  static Future<void> update() async {
    try {
      final now = cairoNow();
      final parts = <String>[];
      for (int d = 0; d < 5; d++) {
        final date = DateTime(now.year, now.month, now.day + d);
        final day = PrayerService.forDate(date);
        for (final p in fardPrayers) {
          parts.add('${prayerAr[p]},${day.t[p]!.millisecondsSinceEpoch}');
        }
      }
      await HomeWidget.saveWidgetData<String>('upcoming', parts.join(';'));
      await HomeWidget.saveWidgetData<String>('hijri', fmtHijri(now));
      await HomeWidget.saveWidgetData<String>('city', Settings.i.cityName);

      // خطة الختمة محفوظة محليًا؛ لا حاجة للاتصال بالإنترنت لعرضها.
      final plan = KhatmaStore.plan();
      if (plan == null) {
        await HomeWidget.saveWidgetData<String>('wird_today', '');
      } else {
        final today = DateTime(now.year, now.month, now.day);
        final target = KhatmaStore.wirdToday(plan, today);
        final read = KhatmaStore.readOn(plan, today);
        await HomeWidget.saveWidgetData<String>('wird_today', '$target,$read');
      }
      await HomeWidget.updateWidget(androidName: 'SakinaWidgetProvider');
    } catch (_) {}
  }
}
