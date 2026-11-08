import 'prayer_log.dart';

/// Derived prayer tracking summaries. No parallel storage: all values come from `plog`.
class PrayerAchievementsService {
  static int countDaysWithAnyPrayer(DateTime end, int days) {
    var count = 0;
    for (var i = 0; i < days; i++) {
      final d = DateTime(end.year, end.month, end.day - i);
      if (PrayerLog.countDay(d) > 0) count++;
    }
    return count;
  }

  static int completeDays(DateTime end, int days) {
    var count = 0;
    for (var i = 0; i < days; i++) {
      final d = DateTime(end.year, end.month, end.day - i);
      if (PrayerLog.countDay(d) == 5) count++;
    }
    return count;
  }

  static Map<String, dynamic> summary(DateTime end, int days) {
    final total = PrayerLog.doneInRange(end, days);
    final possible = days * 5;
    return {
      'days': days,
      'prayers': total,
      'possible': possible,
      'rate': possible == 0 ? 0.0 : total / possible,
      'activeDays': countDaysWithAnyPrayer(end, days),
      'completeDays': completeDays(end, days),
      'streak': PrayerLog.streak(end),
    };
  }

  static List<String> badges(DateTime today) {
    final week = summary(today, 7);
    final month = summary(today, 30);
    final earned = <String>[];
    if ((week['prayers'] as int) >= 5) earned.add('بداية مواظبة');
    if ((week['completeDays'] as int) >= 1) earned.add('يوم مكتمل');
    if ((week['completeDays'] as int) >= 3) earned.add('ثلاثة أيام مكتملة');
    if ((month['completeDays'] as int) >= 7)
      earned.add('أسبوع من الأيام المكتملة');
    if ((month['streak'] as int) >= 7) earned.add('سلسلة أسبوع');
    return earned;
  }
}
