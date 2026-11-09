import 'package:flutter_test/flutter_test.dart';
import '../lib/features/quran_game/data/quran_game_bank.dart';
import '../lib/features/quran_game/data/islamic_knowledge_bank.dart';
import '../lib/features/quran_game/services/quran_game_service.dart';

void main() {
  test('بنك الأسئلة يحتوي على بيانات صالحة للاختيار', () {
    expect(quranGameBank, isNotEmpty);
    for (final question in quranGameBank) {
      expect(question.options, contains(question.correctOption));
      expect(question.fullAyah, contains(question.hiddenWord));
      expect(question.level, inInclusiveRange(1, 100));
    }
  });

  test('Islamic knowledge bank contains sourced valid multiple-choice questions', () {
    expect(islamicKnowledgeBank, isNotEmpty);
    for (final question in islamicKnowledgeBank) {
      expect(question.isIslamicKnowledge, isTrue);
      expect(question.questionText, isNotEmpty);
      expect(question.options, hasLength(4));
      expect(question.options.toSet(), hasLength(4));
      expect(question.options, contains(question.correctOption));
      expect(question.sourceName, isNotEmpty);
      expect(question.sourceReference, isNotEmpty);
    }
  });

  test('مضاعف الكومبو يتدرج حتى عشرين', () {
    expect(QuranGameService.comboMultiplier(1), 1);
    expect(QuranGameService.comboMultiplier(3), 3);
    expect(QuranGameService.comboMultiplier(7), 5);
    expect(QuranGameService.comboMultiplier(10), 10);
    expect(QuranGameService.comboMultiplier(25), 20);
  });
}
