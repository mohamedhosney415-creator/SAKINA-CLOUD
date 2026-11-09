import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakina/core/store.dart';
import 'package:sakina/services/khatma_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
  });

  group('KhatmaStore plans', () {
    test('migrates legacy khatma fields without losing pages or date span',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sk.khatma',
          '{"start":"2025-01-01","days":2,"log":{"2025-01-01":9}}');
      final migrated = KhatmaStore.plan()!;
      expect(KhatmaStore.plans(), hasLength(1));
      expect(migrated['id'], 'legacy-khatma');
      expect(migrated['type'], 'ordinary');
      expect(migrated['end'], '2025-01-02');
      expect(KhatmaStore.pagesRead(migrated), 9);
      expect(KhatmaStore.readOn(migrated, DateTime(2025, 1, 1)), 9);
    });

    test('supports parallel named plans with isolated page logs and selection',
        () async {
      await KhatmaStore.create(10,
          name: 'العادية', type: 'ordinary', start: DateTime(2025, 2, 1));
      final ordinaryId = KhatmaStore.plan()!['id'] as String;
      await KhatmaStore.addPages(12, DateTime(2025, 2, 1));
      await KhatmaStore.create(20,
          name: 'الحفظ', type: 'memorization', start: DateTime(2025, 2, 1));
      final memorization = KhatmaStore.plan()!;
      expect(memorization['name'], 'الحفظ');
      expect(KhatmaStore.plans(), hasLength(2));
      expect(KhatmaStore.pagesRead(memorization), 0);
      await KhatmaStore.select(ordinaryId);
      expect(KhatmaStore.pagesRead(KhatmaStore.plan()!), 12);
    });

    test('honors explicit inclusive boundaries and rejects reversed dates',
        () async {
      await KhatmaStore.create(30,
          start: DateTime(2025, 3, 10), end: DateTime(2025, 3, 12));
      final p = KhatmaStore.plan()!;
      expect(KhatmaStore.daysOf(p), 3);
      expect(KhatmaStore.daysLeft(p, DateTime(2025, 3, 10)), 3);
      expect(KhatmaStore.daysLeft(p, DateTime(2025, 3, 12)), 1);
      expect(KhatmaStore.daysLeft(p, DateTime(2025, 3, 13)), 1);
      expect(KhatmaStore.expectedPagesByNow(p, DateTime(2025, 3, 9)), 0);
      await expectLater(
          KhatmaStore.create(2,
              start: DateTime(2025, 3, 12), end: DateTime(2025, 3, 11)),
          throwsArgumentError);
    });

    test(
        'reports overdue and redistributes remaining pages over remaining days',
        () async {
      await KhatmaStore.create(10, start: DateTime(2025, 4, 1));
      final p = KhatmaStore.plan()!;
      expect(KhatmaStore.expectedPagesByNow(p, DateTime(2025, 4, 4)), 242);
      expect(KhatmaStore.overduePages(p, DateTime(2025, 4, 4)), 242);
      expect(KhatmaStore.wirdToday(p, DateTime(2025, 4, 4)), 87);
      await KhatmaStore.addPages(604, DateTime(2025, 4, 4));
      expect(KhatmaStore.remainingPages(KhatmaStore.plan()!), 0);
      expect(
          KhatmaStore.wirdToday(KhatmaStore.plan()!, DateTime(2025, 4, 4)), 0);
    });

    test('completion increments count and removes only the selected plan',
        () async {
      await KhatmaStore.create(1, name: 'مكتملة', start: DateTime(2025, 5, 1));
      final completedId = KhatmaStore.plan()!['id'];
      await KhatmaStore.addPages(604, DateTime(2025, 5, 1));
      await KhatmaStore.create(3, name: 'مستمرة', start: DateTime(2025, 5, 1));
      await KhatmaStore.select(completedId as String);
      await KhatmaStore.finish();
      expect(KhatmaStore.completed(), 1);
      expect(KhatmaStore.plans(), hasLength(1));
      expect(KhatmaStore.plan()!['name'], 'مستمرة');
    });
  });
}
