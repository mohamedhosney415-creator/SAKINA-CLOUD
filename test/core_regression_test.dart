import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakina/core/store.dart';
import 'package:sakina/services/prayer_achievements_service.dart';
import 'package:sakina/services/prayer_log.dart';
import 'package:sakina/services/prayer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    await Store.setJson('plog', <String, dynamic>{});
  });

  test('prayer statistics count only logged fard prayers', () async {
    final day = DateTime(2026, 1, 20);
    await PrayerLog.toggle(day, Prayer.fajr);
    await PrayerLog.toggle(day, Prayer.dhuhr);

    expect(PrayerLog.countDay(day), 2);
    final result = PrayerAchievementsService.summary(day, 1);
    expect(result['prayers'], 2);
    expect(result['possible'], 5);
    expect(result['activeDays'], 1);
    expect(result['completeDays'], 0);
  });

  test('a fully logged day earns the first complete-day badge', () async {
    final day = DateTime(2026, 1, 20);
    for (final prayer in fardPrayers) {
      await PrayerLog.toggle(day, prayer);
    }

    expect(PrayerAchievementsService.summary(day, 1)['completeDays'], 1);
    expect(PrayerAchievementsService.badges(day), contains('يوم مكتمل'));
  });

  test('importAll removes stale app keys before restoring snapshot values',
      () async {
    await Store.setStr('stale_setting', 'must disappear');
    await Store.importAll({'restored_setting': 'restored'});

    final data = Store.exportAll();
    expect(data['restored_setting'], 'restored');
    expect(data.containsKey('stale_setting'), isFalse);
  });

  test('invalid import is rejected without clearing existing local values',
      () async {
    await Store.setStr('keep_setting', 'keep me');

    await expectLater(
      Store.importAll({
        'bad_list': <Object>['valid', 42]
      }),
      throwsA(isA<FormatException>()),
    );
    expect(Store.str('keep_setting'), 'keep me');
  });
}
