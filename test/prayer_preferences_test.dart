import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:sakina/core/settings.dart';
import 'package:sakina/core/store.dart';
import 'package:sakina/services/prayer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    Settings.i.load();
    PrayerService.clearCache();
  });

  test('legacy settings keep Egyptian and Shafi calculation defaults', () {
    expect(Settings.i.calculationMethod, 'egyptian');
    expect(Settings.i.asrMadhab, 'shafi');
  });

  test('calculation preferences persist and change schedule signature',
      () async {
    final initialSignature = Settings.i.scheduleSignature;
    await Settings.i.set('prayerCalculationMethod', 'muslim_world_league');
    await Settings.i.set('prayerAsrMadhab', 'hanafi');
    final signature = Settings.i.scheduleSignature;

    Settings.i.load();
    expect(Settings.i.calculationMethod, 'muslim_world_league');
    expect(Settings.i.asrMadhab, 'hanafi');
    expect(signature, isNot(initialSignature));
  });

  test('selected method and madhab are reflected in local prayer calculation',
      () async {
    final date = DateTime(2026, 5, 20);
    final egyptianShafi = PrayerService.forDate(date).t;
    await Settings.i.set('prayerAsrMadhab', 'hanafi');
    PrayerService.clearCache();
    final egyptianHanafi = PrayerService.forDate(date).t;
    expect(egyptianHanafi[Prayer.asr], isNot(egyptianShafi[Prayer.asr]));

    await Settings.i.set('prayerCalculationMethod', 'muslim_world_league');
    PrayerService.clearCache();
    final mwl = PrayerService.forDate(date).t;
    expect(mwl[Prayer.fajr], isNot(egyptianHanafi[Prayer.fajr]));
  });
}
