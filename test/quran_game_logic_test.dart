import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakina/core/store.dart';
import 'package:sakina/features/quran_game/data/quran_game_bank.dart';
import 'package:sakina/features/quran_game/services/quran_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    await QuranGameService.reset();
  });

  test(
    'question bank has 1,000 distinct valid questions across all levels',
    () {
      expect(quranGameBank, hasLength(1000));
      expect(quranGameBank.map((q) => q.id).toSet(), hasLength(1000));
      for (var level = 1; level <= 100; level++) {
        final questions = quranGameBank.where((q) => q.level == level).toList();
        expect(questions, hasLength(10), reason: 'level $level');
        for (final q in questions) {
          expect(q.options, hasLength(4));
          expect(q.options.toSet(), hasLength(4));
          expect(q.options, contains(q.correctOption));
          expect(q.fullAyah, contains(q.hiddenWord));
          expect(q.globalAyahNumber, inInclusiveRange(1, 6236));
        }
      }
    },
  );

  test('question count grows by one every ten levels', () {
    expect(QuranGameConfig.questionsForLevel(1), 3);
    expect(QuranGameConfig.questionsForLevel(10), 3);
    expect(QuranGameConfig.questionsForLevel(11), 4);
    expect(QuranGameConfig.questionsForLevel(20), 4);
    expect(QuranGameConfig.questionsForLevel(21), 5);
    expect(QuranGameConfig.questionsForLevel(100), 12);
  });

  test('question mix supports both categories and avoids repeats within a level', () async {
    await Store.setInt('qgame_quran_mix', 0);
    final ids = <String>{};
    for (var i = 0; i < 3; i++) {
      final question = QuranGameService.nextQuestion(requestedLevel: 1);
      expect(question.isIslamicKnowledge, isTrue);
      expect(ids.add(question.id), isTrue);
      await QuranGameService.answer(question, true);
    }
    expect(QuranGameService.questionsAnsweredInCurrentLevel, 3);
    expect(ids, hasLength(3));
  });

  test('daily answer does not advance ordinary level progress', () async {
    final q = quranGameBank.first;
    await QuranGameService.answer(q, true, daily: true);
    expect(QuranGameService.questionsAnsweredInCurrentLevel, 0);
    expect(QuranGameService.correctAnswersInCurrentLevel, 0);
    expect(QuranGameService.totalQuestions, 1);
  });

  test(
    'three correct answers complete level one but wait for explicit continuation',
    () async {
      final levelQuestions = quranGameBank.where((q) => q.level == 1).take(3);
      for (final q in levelQuestions) {
        await QuranGameService.answer(q, true);
      }
      expect(QuranGameService.questionsAnsweredInCurrentLevel, 3);
      expect(await QuranGameService.completeLevelIfReady(), isTrue);
      expect(QuranGameService.level, 1);
      expect(QuranGameService.levelCompleted, isTrue);
      expect(QuranGameService.perfectLevels, 1);
      expect(QuranGameService.currentLevelStars, 3);
      expect(QuranGameService.totalStars, 3);
      expect(await QuranGameService.completeLevelIfReady(), isFalse);
      expect(await QuranGameService.advanceToNextLevel(), isTrue);
      expect(QuranGameService.level, 2);
      expect(QuranGameService.questionsAnsweredInCurrentLevel, 0);
      expect(QuranGameService.currentLevelPoints, 0);
    },
  );

  test(
    'an incorrect answer prevents perfect status and keeps the result until continuation',
    () async {
      final levelQuestions = quranGameBank.where((q) => q.level == 1).take(3).toList();
      for (var i = 0; i < levelQuestions.length; i++) {
        await QuranGameService.answer(levelQuestions[i], i != 1);
      }
      await QuranGameService.completeLevelIfReady();
      expect(QuranGameService.perfectLevels, 0);
      expect(QuranGameService.mistakesInCurrentLevel, 1);
      expect(QuranGameService.level, 1);
      expect(QuranGameService.levelCompleted, isTrue);
      expect(QuranGameService.currentLevelStars, 1);
      expect(await QuranGameService.advanceToNextLevel(), isTrue);
      expect(QuranGameService.level, 2);
    },
  );

  test('same question cannot advance ordinary level progress twice', () async {
    final q = quranGameBank.first;
    await QuranGameService.answer(q, true);
    final before = QuranGameService.noor;
    final result = await QuranGameService.answer(q, true);
    expect(result['noor'], 0);
    expect(QuranGameService.questionsAnsweredInCurrentLevel, 1);
    expect(QuranGameService.noor, before);
  });

  test('first-correct achievement is rewarded once and recorded', () async {
    await QuranGameService.answer(quranGameBank.first, true);
    expect(QuranGameService.achievementCount, 1);
    expect(Store.json('qgame_pending_rewards'), isNotEmpty);
    expect(
        QuranGameService.noor, 15); // answer reward + first achievement reward
    await QuranGameService.answer(quranGameBank[1], true);
    expect(QuranGameService.achievementCount, 1);
  });

  test('Noor purchase is charged once and cannot become negative', () async {
    await Store.setInt('qgame_noor', 300);
    expect(await QuranGameService.buy('gold'), isTrue);
    expect(QuranGameService.noor, 180);
    expect(await QuranGameService.buy('gold'), isFalse);
    expect(await QuranGameService.buy('mushaf'), isFalse);
    expect(QuranGameService.noor, 180);
  });

  test(
    'booster purchases add inventory and remove-two keeps the answer',
    () async {
      await Store.setInt('qgame_noor', 500);
      expect(await QuranGameService.purchaseBooster('remove_two'), isTrue);
      expect(QuranGameService.boosterCount('remove_two'), 1);
      final q = quranGameBank.first;
      final remaining = await QuranGameService.removeTwoWrongOptions(q);
      expect(remaining, hasLength(2));
      expect(remaining, contains(q.correctOption));
      expect(await QuranGameService.useBooster('remove_two'), isTrue);
      expect(QuranGameService.boosterCount('remove_two'), 0);
    },
  );

  test(
    'second chance retries the same question without double-counting level progress',
    () async {
      await Store.setInt('qgame_noor', 100);
      final q = quranGameBank.first;
      await QuranGameService.answer(q, false);
      expect(QuranGameService.questionsAnsweredInCurrentLevel, 1);
      expect(await QuranGameService.purchaseBooster('second_chance'), isTrue);
      expect(await QuranGameService.activateSecondChance(q.id), isTrue);
      await QuranGameService.answer(q, true, retry: true);
      expect(QuranGameService.questionsAnsweredInCurrentLevel, 1);
      expect(QuranGameService.mistakesInCurrentLevel, 1);
      expect(QuranGameService.totalQuestions, 2);
      expect(QuranGameService.correctAnswers, 1);
    },
  );

  test('streak reward is credited once per local day', () async {
    await QuranGameService.answer(quranGameBank.first, true, daily: true);
    final reward = await QuranGameService.completeDaily();
    expect(reward, greaterThanOrEqualTo(QuranGameConfig.dailyBonus));
    final balance = QuranGameService.noor;
    expect(await QuranGameService.completeDaily(), 0);
    expect(QuranGameService.noor, balance);
    expect(QuranGameService.dailyChallenges, 1);
  });
}
