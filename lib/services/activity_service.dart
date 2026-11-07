import '../core/format.dart';
import '../core/store.dart';

/// Local-first activity journal for the daily assistant, streaks and Quran journey.
class ActivityService {
  static const taskNames = <String, String>{
    'quran': 'قراءة القرآن',
    'azkar': 'الأذكار',
    'tasbeeh': 'التسبيح',
    'prayer': 'متابعة الصلاة',
  };

  static String get todayKey => dayKey(DateTime.now());

  static Map<String, dynamic> _all() {
    final v = Store.json('activity_days', {});
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  static Map<String, dynamic> forDay([String? key]) {
    final day = _all()[key ?? todayKey];
    return day is Map ? Map<String, dynamic>.from(day) : {};
  }

  static Future<void> mark(String task, {bool done = true}) async {
    final all = _all();
    final day = all[todayKey] is Map
        ? Map<String, dynamic>.from(all[todayKey])
        : <String, dynamic>{};
    day[task] = done;
    all[todayKey] = day;
    final keys = all.keys.toList()..sort();
    while (keys.length > 400) {
      all.remove(keys.removeAt(0));
    }
    await Store.setJson('activity_days', all);
  }

  static bool completed(String task, [String? key]) =>
      forDay(key)[task] == true;

  static int get currentStreak {
    final all = _all();
    var cursor = DateTime.now();
    var count = 0;
    // A streak day means at least one user-selected worship activity was completed.
    for (var i = 0; i < 400; i++) {
      final key = dayKey(cursor);
      final value = all[key];
      final hasAny = value is Map && value.values.any((v) => v == true);
      if (!hasAny) {
        if (i == 0) {
          cursor = cursor.subtract(const Duration(days: 1));
          final yesterday = all[dayKey(cursor)];
          if (yesterday is Map && yesterday.values.any((v) => v == true)) {
            count++;
            cursor = cursor.subtract(const Duration(days: 1));
            continue;
          }
        }
        break;
      }
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static int activeDays({int days = 7, String task = 'quran', DateTime? since}) {
    var count = 0;
    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: i));
      if (since != null && d.isBefore(DateTime(since.year, since.month, since.day))) continue;
      if (completed(task, dayKey(d))) count++;
    }
    return count;
  }

  static Map<String, dynamic> _journey() {
    final v = Store.json('quran_journey', {});
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  static Future<void> markQuranRead(int surah, {int? ayah}) async {
    await mark('quran');
    final j = _journey();
    final days = (j['days'] is List ? (j['days'] as List).map((e) => '$e').toSet() : <String>{});
    days.add(todayKey);
    final read = (j['surahs'] is List ? (j['surahs'] as List).map((e) => (e as num).toInt()).toSet() : <int>{});
    read.add(surah);
    j['days'] = days.toList()..sort();
    j['surahs'] = read.toList()..sort();
    j['lastSurah'] = surah;
    if (ayah != null) j['lastAyah'] = ayah;
    j['lastDate'] = todayKey;
    await Store.setJson('quran_journey', j);
  }

  static Map<String, dynamic> get journey => _journey();

  static int get quranDays => (_journey()['days'] is List ? (_journey()['days'] as List).length : 0);
  static int get quranSurahs => (_journey()['surahs'] is List ? (_journey()['surahs'] as List).length : 0);

  static Future<void> setAssistantTask(String task, bool value) => mark(task, done: value);

  static Map<String, dynamic> get challenges {
    final v = Store.json('sakina_challenges', {});
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  static Future<void> startChallenge(String id) async {
    final all = challenges;
    all[id] = todayKey;
    await Store.setJson('sakina_challenges', all);
  }

  static Future<void> resetChallenge(String id) async {
    final all = challenges;
    all.remove(id);
    await Store.setJson('sakina_challenges', all);
  }
}
