import 'dart:math';

import '../../../core/store.dart';
import '../../../cloud/game_cloud_service.dart';
import '../data/quran_game_bank.dart';
import '../data/islamic_knowledge_bank.dart';
import '../models/quran_game_question.dart';

class QuranGameConfig {
  static const questionsPerLevel = 3;
  static int questionsForLevel(int value) => 3 + ((value - 1) ~/ 10);

  static const basePoints = 10;
  static const levelBonus = 25;
  static const perfectBonus = 50;
  static const dailyBonus = 30;
  static const hintCost = 30;
  static const removeTwoCost = 50;
  static const secondChanceCost = 75;
  static const comboProtectionCost = 150;
  static const streakRewards = <int, int>{
    3: 20,
    7: 50,
    14: 100,
    30: 250,
    60: 500,
    100: 1000,
    365: 2000,
  };
  static const streakBadges = <int, String>{
    7: 'شارة سلسلة الأسبوع',
    30: 'شارة السلسلة المميزة',
    100: 'شارة سلسلة المئة',
    365: 'شارة سلسلة الأستاذ',
  };
  static const storeCatalog = <String, int>{
    'gold': 120,
    'night': 180,
    'ramadan': 200,
    'mushaf': 250,
    'frame_gold': 100,
    'badge_skilled': 250,
    'title_reader': 150,
    'effect_correct': 80,
    'effect_perfect': 120,
    'effect_level': 150,
    'hint': hintCost,
    'remove_two': removeTwoCost,
    'second_chance': secondChanceCost,
    'combo_protection': comboProtectionCost,
  };
}

class QuranGameService {
  static final _random = Random();
  static List<QuranGameQuestion>? _remoteQuestions;

  static Future<void> loadRemoteQuestions() async {
    try {
      final rows = await GameCloudService.fetchQuestions();
      try {
        await Store.setInt('qgame_quran_mix', await GameCloudService.fetchQuestionMix());
      } catch (_) {}
      if (rows.length >= 100) {
        _remoteQuestions = rows
            .map(QuranGameQuestion.fromJson)
            .where((q) =>
                q.level >= 1 &&
                q.level <= 100 &&
                q.options.length == 4 &&
                q.options.contains(q.correctOption) &&
                (q.isIslamicKnowledge || q.fullAyah.contains(q.hiddenWord)))
            .toList(growable: false);
      }
    } catch (_) {
      // The bundled 1000-question bank remains the offline fallback.
    }
  }

  /// Cloud sync is deliberately best-effort: gameplay must never fail because
  /// the network is unavailable.
  static Future<void> _syncCloud() async {
    try {
      await Store.setStr(
        'qgame_local_changed_at',
        DateTime.now().toUtc().toIso8601String(),
      );
      await GameCloudService.sync();
    } catch (_) {
      // Offline-first: keep local progress and retry on the next successful
      // game mutation/login.
    }
  }

  static Future<void> syncFromCloud() async {
    try {
      await GameCloudService.sync(preferRemote: true);
    } catch (_) {}
  }
  static List<QuranGameQuestion> get questions => [
        ...(_remoteQuestions ?? quranGameBank),
        ...islamicKnowledgeBank,
      ];
  static int get maximumAvailableLevel => questions.isEmpty
      ? 0
      : questions.map((q) => q.level).reduce((a, b) => a > b ? a : b).clamp(1, 100).toInt();
  static int get currentLevelQuestionCount => questionsForLevel(level);
  static int get quranQuestionPercent => Store.integer('qgame_quran_mix', 50).clamp(0, 100).toInt();
  static bool get levelCompleted => Store.flag('qgame_level_completed_$level');
  static bool isLevelCompleted(int value) => Store.flag('qgame_level_completed_$value');
  static int starsForLevel(int value) {
    final map = Store.json('qgame_level_stars', <String, dynamic>{});
    if (map is! Map) return 0;
    final stars = map['$value'];
    return (stars is num ? stars.toInt() : 0).clamp(0, 3).toInt();
  }
  static int bestCorrectForLevel(int value) {
    final map = Store.json('qgame_level_best_correct', <String, dynamic>{});
    if (map is! Map) return 0;
    final best = map['$value'];
    return (best is num ? best.toInt() : 0).clamp(0, questionsForLevel(value)).toInt();
  }
  static int get totalStars {
    final map = Store.json('qgame_level_stars', <String, dynamic>{});
    if (map is! Map) return 0;
    return map.values.fold<int>(0, (sum, value) => sum + (value is num ? value.toInt().clamp(0, 3).toInt() : 0));
  }
  static int get currentLevelStars {
    final total = currentLevelQuestionCount;
    final correct = correctAnswersInCurrentLevel;
    if (total <= 0) return 0;
    if (correct == total && questionsAnsweredInCurrentLevel == total) return 3;
    final ratio = correct / total;
    if (ratio >= .8) return 2;
    if (ratio >= .5) return 1;
    return 0;
  }

  static int get level => Store.integer('qgame_level', 1).clamp(1, 100).toInt();
  static int get score =>
      Store.integer('qgame_score').clamp(0, 1 << 30).toInt();
  static int get xp => score;
  static int get noor => Store.integer('qgame_noor').clamp(0, 1 << 30).toInt();
  static int get combo =>
      Store.integer('qgame_combo').clamp(0, 1 << 30).toInt();
  static int get bestCombo =>
      Store.integer('qgame_best_combo').clamp(0, 1 << 30).toInt();
  static int get totalQuestions =>
      Store.integer('qgame_total').clamp(0, 1 << 30).toInt();
  static int get correctAnswers =>
      Store.integer('qgame_correct').clamp(0, totalQuestions).toInt();
  static int get wrongAnswers =>
      Store.integer('qgame_wrong').clamp(0, totalQuestions).toInt();
  static int get questionsAnsweredInCurrentLevel =>
      Store.integer('qgame_level_answered')
          .clamp(0, currentLevelQuestionCount)
          .toInt();
  static int get correctAnswersInCurrentLevel =>
      Store.integer('qgame_level_correct')
          .clamp(0, currentLevelQuestionCount)
          .toInt();
  static int get mistakesInCurrentLevel => Store.integer('qgame_level_mistakes')
      .clamp(0, currentLevelQuestionCount)
      .toInt();
  static int get currentLevelPoints => Store.integer('qgame_level_points').clamp(0, 1 << 30).toInt();
  static int get currentLevelAccuracy => currentLevelQuestionCount == 0
      ? 0
      : (correctAnswersInCurrentLevel * 100 / currentLevelQuestionCount).round();
  static int get streak =>
      Store.integer('qgame_streak').clamp(0, 36500).toInt();
  static int get longestStreak =>
      Store.integer('qgame_longest_streak').clamp(0, 36500).toInt();
  static int get dailyChallenges =>
      Store.integer('qgame_daily_count').clamp(0, 1 << 30).toInt();
  static int get perfectLevels =>
      Store.integer('qgame_perfect_levels').clamp(0, 100).toInt();
  static int get achievementCount =>
      (Store.json('qgame_achievements', <dynamic>[]) as List).length;
  static List<String> get history =>
      List<String>.from(Store.json('qgame_history', <dynamic>[]) as List);
  static bool get autoRecite => Store.flag('qgame_auto_recite', true);
  static bool get darkMode => Store.flag('qgame_dark_mode', true);
  static String get activeTheme => const ['gold', 'night', 'ramadan', 'mushaf']
      .firstWhere((id) => Store.flag('qgame_active_$id'),
          orElse: () => 'default');
  static String get todayKey => _dateKey(DateTime.now());
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static bool get dailyDone => Store.str('qgame_daily_done') == todayKey;
  static int get longestStreakSafe => max(longestStreak, streak);

  static QuranGameQuestion nextQuestion({int requestedLevel = 1}) {
    final safeLevel = requestedLevel.clamp(1, 100).toInt();
    final base = _remoteQuestions ?? quranGameBank;
    final quranPool = base
        .where((q) => !q.isIslamicKnowledge && q.level == safeLevel)
        .toList();
    final knowledgePool = [
      ...base.where((q) => q.isIslamicKnowledge),
      ...islamicKnowledgeBank,
    ]
        .where((q) => q.isIslamicKnowledge)
        .fold<Map<String, QuranGameQuestion>>(
          <String, QuranGameQuestion>{},
          (map, q) {
            map[q.id] = q.withLevel(safeLevel);
            return map;
          },
        )
        .values
        .toList();
    final seenThisLevel = (Store.json(
      'qgame_level_history',
      <dynamic>[],
    ) as List).cast<String>().toSet();
    final recent = history.take(4).toSet();
    final freshQuran = quranPool
        .where((q) => !seenThisLevel.contains(q.id) && !recent.contains(q.id))
        .toList();
    final freshKnowledge = knowledgePool
        .where((q) => !seenThisLevel.contains(q.id) && !recent.contains(q.id))
        .toList();
    final availableQuran = freshQuran.isNotEmpty
        ? freshQuran
        : quranPool.where((q) => !seenThisLevel.contains(q.id)).toList();
    final availableKnowledge = freshKnowledge.isNotEmpty
        ? freshKnowledge
        : knowledgePool.where((q) => !seenThisLevel.contains(q.id)).toList();
    final chooseKnowledge = availableKnowledge.isNotEmpty &&
        (availableQuran.isEmpty || _random.nextInt(100) >= quranQuestionPercent);
    final source = chooseKnowledge ? availableKnowledge : availableQuran;
    if (source.isEmpty) {
      throw StateError('No unused questions remain for level $safeLevel');
    }
    return source[_random.nextInt(source.length)];
  }

  static int comboMultiplier(int value) => value >= 20
      ? 20
      : value >= 10
          ? 10
          : value >= 5
              ? 5
              : value >= 3
                  ? 3
                  : value >= 2
                      ? 2
                      : 1;

  static Future<Map<String, int>> answer(
    QuranGameQuestion q,
    bool correct, {
    bool daily = false,
    bool retry = false,
  }) async {
    if (q.level < 1 ||
        q.level > 100 ||
        q.options.length != 4 ||
        !q.options.contains(q.correctOption) ||
        (!q.isIslamicKnowledge && !q.fullAyah.contains(q.hiddenWord))) {
      throw ArgumentError('Invalid Quran game question');
    }
    if (!daily && q.level != level)
      throw StateError('Question does not belong to the current level');
    final alreadyAnswered = daily
        ? dailyDone
        : questionsAnsweredInCurrentLevel >= currentLevelQuestionCount;
    if (alreadyAnswered) return {'points': 0, 'noor': 0, 'combo': combo};
    final levelHistory =
        (Store.json('qgame_level_history', <dynamic>[]) as List).cast<String>();
    final retryAllowed = Store.flag('qgame_retry_allowed_${q.id}');
    if (retry && !retryAllowed) return {'points': 0, 'noor': 0, 'combo': combo};
    if (!retry && !daily && levelHistory.contains(q.id))
      return {'points': 0, 'noor': 0, 'combo': combo};
    if (retry) {
      await Store.setFlag('qgame_retry_allowed_${q.id}', false);
      await Store.setFlag('qgame_retry_used_${q.id}', true);
    }
    final protected = !correct && boosterCount('combo_protection') > 0;
    if (protected)
      await Store.setInt(
        'qgame_booster_combo_protection',
        boosterCount('combo_protection') - 1,
      );
    final nextCombo = correct
        ? combo + 1
        : protected
            ? combo
            : 0;
    final points =
        correct ? QuranGameConfig.basePoints * comboMultiplier(nextCombo) : 0;
    final earnedNoor = correct ? 10 : 0;
    await Store.setInt('qgame_total', totalQuestions + 1);
    await Store.setInt('qgame_correct', correctAnswers + (correct ? 1 : 0));
    await Store.setInt('qgame_wrong', wrongAnswers + (correct ? 0 : 1));
    await Store.setInt('qgame_combo', nextCombo);
    await Store.setInt('qgame_best_combo', max(bestCombo, nextCombo));
    await Store.setInt('qgame_score', score + points);
    if (!daily && !retry) {
      await Store.setInt('qgame_level_points', currentLevelPoints + points);
    }
    await _credit(earnedNoor, 'إجابة صحيحة');
    if (daily) {
      await Store.setStr('qgame_daily_attempt_date', todayKey);
      if (correct) await Store.setStr('qgame_daily_success_date', todayKey);
    }
    if (!daily && !retry) {
      await Store.setInt(
        'qgame_level_answered',
        questionsAnsweredInCurrentLevel + 1,
      );
      await Store.setInt(
        'qgame_level_correct',
        correctAnswersInCurrentLevel + (correct ? 1 : 0),
      );
      await Store.setInt(
        'qgame_level_mistakes',
        mistakesInCurrentLevel + (correct ? 0 : 1),
      );
    }
    final updated = [q.id, ...history].toSet().take(100).toList();
    await Store.setJson('qgame_history', updated);
    if (!daily && !retry) {
      final levelHistory = (Store.json(
        'qgame_level_history',
        <dynamic>[],
      ) as List)
          .cast<String>()
          .toSet()
        ..add(q.id);
      await Store.setJson('qgame_level_history', levelHistory.toList());
    }
    await _checkAchievements();
    await GameCloudService.recordEvent(
      type: correct ? 'answer_correct' : 'answer_wrong',
      amount: correct ? points : 0,
      metadata: {
        'question_id': q.id,
        'level': q.level,
        'daily': daily,
        'retry': retry,
      },
    ).catchError((_) {});
    await GameCloudService.markQuestionSeen(q.id).catchError((_) {});
    await _syncCloud();
    return {'points': points, 'noor': earnedNoor, 'combo': nextCombo};
  }

  static Future<bool> activateSecondChance(String questionId) async {
    if (Store.flag('qgame_retry_used_$questionId') ||
        !await useBooster('second_chance')) return false;
    await Store.setFlag('qgame_retry_allowed_$questionId', true);
    return true;
  }

  static Future<bool> completeLevelIfReady() async {
    if (questionsAnsweredInCurrentLevel != currentLevelQuestionCount)
      return false;
    if (levelCompleted) return false;
    await Store.setFlag('qgame_level_completed_$level', true);
    await _credit(QuranGameConfig.levelBonus, 'إكمال المستوى $level');
    final isPerfect = correctAnswersInCurrentLevel == currentLevelQuestionCount &&
        mistakesInCurrentLevel == 0;
    final earnedStars = currentLevelStars;
    final starsByLevel = Map<String, dynamic>.from(
      Store.json('qgame_level_stars', <String, dynamic>{}) as Map,
    );
    final previousStars = (starsByLevel['$level'] as num?)?.toInt() ?? 0;
    if (earnedStars > previousStars) {
      starsByLevel['$level'] = earnedStars;
      await Store.setJson('qgame_level_stars', starsByLevel);
    }
    final bestCorrectByLevel = Map<String, dynamic>.from(
      Store.json('qgame_level_best_correct', <String, dynamic>{}) as Map,
    );
    final previousBest = (bestCorrectByLevel['$level'] as num?)?.toInt() ?? 0;
    if (correctAnswersInCurrentLevel > previousBest) {
      bestCorrectByLevel['$level'] = correctAnswersInCurrentLevel;
      await Store.setJson('qgame_level_best_correct', bestCorrectByLevel);
    }
    if (isPerfect) {
      await Store.setInt('qgame_perfect_levels', perfectLevels + 1);
      await Store.setJson('qgame_perfect_level_ids', [
        ...(Store.json('qgame_perfect_level_ids', <dynamic>[]) as List),
        level,
      ]);
      await _credit(QuranGameConfig.perfectBonus, 'مستوى مثالي');
    }
    await Store.setJson('qgame_pending_rewards', [
      ...(Store.json('qgame_pending_rewards', <dynamic>[]) as List),
      {
        'title': 'اكتمل المستوى $level',
        'noor': QuranGameConfig.levelBonus,
        'perfect': isPerfect,
        'stars': earnedStars,
      },
    ]);
    await _checkAchievements();
    await GameCloudService.recordEvent(
      type: isPerfect ? 'perfect_level' : 'level_complete',
      amount: QuranGameConfig.levelBonus + (isPerfect ? QuranGameConfig.perfectBonus : 0),
      metadata: {'level': level},
    ).catchError((_) {});
    await _syncCloud();
    return true;
  }

  /// Advance only after the player has viewed the completed-level result.
  static Future<bool> advanceToNextLevel() async {
    if (!levelCompleted || level >= maximumAvailableLevel || level >= 100) {
      return false;
    }
    await Store.setInt('qgame_level', level + 1);
    await Store.setInt('qgame_level_answered', 0);
    await Store.setInt('qgame_level_correct', 0);
    await Store.setInt('qgame_level_mistakes', 0);
    await Store.setInt('qgame_level_points', 0);
    await Store.setJson('qgame_level_history', <String>[]);
    await _syncCloud();
    return true;
  }

  static Future<int> completeDaily() async {
    if (dailyDone) return 0;
    final now = DateTime.now();
    final today = todayKey;
    if (Store.str('qgame_daily_success_date') != today) return 0;
    final last = Store.str('qgame_last_day');
    // Never let a backward device-clock change pay or advance the streak again.
    if (last.isNotEmpty && today.compareTo(last) <= 0) return 0;
    final previous = _dateKey(DateTime(now.year, now.month, now.day - 1));
    final next = last == previous ? streak + 1 : 1;
    await Store.setStr('qgame_daily_done', today);
    await Store.setStr('qgame_last_day', today);
    await Store.setInt('qgame_streak', next);
    await Store.setInt('qgame_longest_streak', max(longestStreak, next));
    await Store.setInt('qgame_daily_count', dailyChallenges + 1);
    var reward = QuranGameConfig.dailyBonus;
    final milestone = QuranGameConfig.streakRewards[next];
    if (milestone != null) {
      reward += milestone;
      final badges = (Store.json('qgame_badges', <dynamic>[]) as List)
          .cast<String>()
          .toSet();
      final badge = QuranGameConfig.streakBadges[next];
      if (badge != null) badges.add(badge);
      await Store.setJson('qgame_badges', badges.toList());
    }
    await _credit(reward, 'تحدي اليوم وسلسلة $next يومًا');
    await Store.setJson('qgame_pending_rewards', [
      ...(Store.json('qgame_pending_rewards', <dynamic>[]) as List),
      {'title': 'اكتمل تحدي اليوم', 'noor': reward, 'streak': next},
    ]);
    await _checkAchievements();
    await GameCloudService.recordEvent(
      type: 'daily_complete',
      amount: reward,
      metadata: {'date': today, 'streak': next},
    ).catchError((_) {});
    await _syncCloud();
    return reward;
  }

  static Future<void> _checkAchievements() async {
    final earned = (Store.json('qgame_achievements', <dynamic>[]) as List)
        .cast<String>()
        .toSet();
    final candidates = <String, bool>{
      'first_correct': correctAnswers >= 1,
      'fifty_correct': correctAnswers >= 50,
      'combo_ten': bestCombo >= 10,
      'perfect_level': perfectLevels > 0,
      'seven_daily': dailyChallenges >= 7,
      'level_25': level >= 25,
      'level_50': level >= 50,
      'streak_30': longestStreak >= 30,
    };
    const rewards = <String, int>{
      'first_correct': 5,
      'fifty_correct': 30,
      'combo_ten': 20,
      'perfect_level': 50,
      'seven_daily': 30,
      'level_25': 50,
      'level_50': 100,
      'streak_30': 100,
    };
    final unlocked = <Map<String, dynamic>>[];
    for (final entry in candidates.entries) {
      if (!entry.value || !earned.add(entry.key)) continue;
      final amount = rewards[entry.key] ?? 0;
      await _credit(amount, 'إنجاز ${entry.key}');
      unlocked.add({'title': 'إنجاز ${entry.key}', 'noor': amount});
    }
    if (unlocked.isEmpty) return;
    await Store.setJson('qgame_achievements', earned.toList());
    await Store.setJson('qgame_pending_rewards', [
      ...(Store.json('qgame_pending_rewards', <dynamic>[]) as List),
      ...unlocked,
    ]);
  }

  static Future<void> _credit(int amount, String reason) async {
    if (amount <= 0) return;
    await Store.setInt('qgame_noor', noor + amount);
    await _ledger('credit', amount, reason);
  }

  static Future<void> _debit(int amount, String reason) async {
    if (amount < 0 || noor < amount)
      throw StateError('رصيد نور اللعبة غير كافٍ');
    await Store.setInt('qgame_noor', noor - amount);
    await _ledger('debit', amount, reason);
  }

  static Future<void> _ledger(String type, int amount, String reason) async {
    final rows =
        (Store.json('qgame_noor_ledger', <dynamic>[]) as List).toList();
    rows.insert(0, {
      'type': type,
      'amount': amount,
      'reason': reason,
      'at': DateTime.now().toIso8601String(),
    });
    await Store.setJson('qgame_noor_ledger', rows.take(200).toList());
  }

  static Future<void> setAutoRecite(bool v) =>
      Store.setFlag('qgame_auto_recite', v);
  static Future<void> setDarkMode(bool v) =>
      Store.setFlag('qgame_dark_mode', v);
  static Future<bool> buy(String id, [int? requestedCost]) async {
    final cost = QuranGameConfig.storeCatalog[id];
    if (cost == null ||
        requestedCost != null && requestedCost != cost ||
        noor < cost ||
        owned(id)) return false;
    await _debit(cost, 'شراء $id');
    await Store.setFlag('qgame_item_$id', true);
    await GameCloudService.recordEvent(
      type: 'store_purchase',
      amount: -cost,
      metadata: {'item': id},
    ).catchError((_) {});
    await _syncCloud();
    return true;
  }

  static bool owned(String id) => Store.flag('qgame_item_$id');
  static bool enabled(String id) => Store.flag('qgame_active_$id') && owned(id);
  static Future<void> setItemEnabled(String id, bool enabled) async {
    if (!owned(id)) return;
    if (enabled && const {'gold', 'night', 'ramadan', 'mushaf'}.contains(id)) {
      for (final theme in const ['gold', 'night', 'ramadan', 'mushaf']) {
        await Store.setFlag('qgame_active_$theme', theme == id);
      }
      return;
    }
    await Store.setFlag('qgame_active_$id', enabled);
  }

  static int boosterCount(String id) => Store.integer('qgame_booster_$id');
  static Future<bool> useBooster(String id) async {
    if (!const {
      'hint',
      'remove_two',
      'second_chance',
      'combo_protection',
    }.contains(id)) return false;
    final count = boosterCount(id);
    if (count <= 0) return false;
    await Store.setInt('qgame_booster_$id', count - 1);
    return true;
  }

  static Future<bool> purchaseBooster(String id) async {
    if (!const {
      'hint',
      'remove_two',
      'second_chance',
      'combo_protection',
    }.contains(id)) return false;
    final cost = QuranGameConfig.storeCatalog[id];
    if (cost == null || noor < cost) return false;
    await _debit(cost, 'شراء معزز $id');
    await Store.setFlag('qgame_item_$id', true);
    await Store.setInt('qgame_booster_$id', boosterCount(id) + 1);
    await GameCloudService.recordEvent(
      type: 'booster_purchase',
      amount: -cost,
      metadata: {'item': id},
    ).catchError((_) {});
    await _syncCloud();
    return true;
  }

  static Future<List<String>> removeTwoWrongOptions(QuranGameQuestion q) async {
    final wrong = q.options.where((o) => o != q.correctOption).toList()
      ..shuffle(_random);
    final kept = q.options
        .where((o) => o == q.correctOption || !wrong.take(2).contains(o))
        .toList();
    return kept;
  }

  static String hintFor(QuranGameQuestion q) => q.isIslamicKnowledge
      ? 'تلميح: ${q.explanation ?? 'راجع مصدر السؤال'}'
      : 'تلميح: الكلمة الناقصة تبدأ بـ «${q.hiddenWord.substring(0, 1)}»';

  static Future<void> reset() async {
    final keys = [
      'qgame_level',
      'qgame_score',
      'qgame_noor',
      'qgame_combo',
      'qgame_best_combo',
      'qgame_total',
      'qgame_correct',
      'qgame_wrong',
      'qgame_streak',
      'qgame_longest_streak',
      'qgame_daily_count',
      'qgame_perfect_levels',
      'qgame_level_answered',
      'qgame_level_correct',
      'qgame_level_mistakes',
      'qgame_level_points',
      'qgame_daily_done',
      'qgame_daily_attempt_date',
      'qgame_daily_success_date',
      'qgame_last_day',
      'qgame_level_history',
      'qgame_level_stars',
      'qgame_level_best_correct',
      'qgame_history',
      'qgame_perfect_level_ids',
      'qgame_pending_rewards',
      'qgame_badges',
      'qgame_achievements',
      'qgame_noor_ledger',
    ];
    for (final k in keys) {
      await Store.remove(k);
    }
    for (var i = 1; i <= 100; i++) {
      await Store.remove('qgame_level_completed_$i');
    }
    for (final id in QuranGameConfig.storeCatalog.keys) {
      await Store.remove('qgame_item_$id');
      await Store.remove('qgame_active_$id');
      await Store.remove('qgame_booster_$id');
    }
    for (final q in questions) {
      await Store.remove('qgame_retry_allowed_${q.id}');
      await Store.remove('qgame_retry_used_${q.id}');
    }
    await _syncCloud();
  }
}
