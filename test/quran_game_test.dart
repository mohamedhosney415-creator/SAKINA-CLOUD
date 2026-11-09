import 'package:flutter_test/flutter_test.dart';
import '../lib/features/quran_game/data/quran_game_bank.dart';
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

  test('مضاعف الكومبو يتدرج حتى عشرين', () {
    expect(QuranGameService.comboMultiplier(1), 1);
    expect(QuranGameService.comboMultiplier(3), 3);
    expect(QuranGameService.comboMultiplier(7), 5);
    expect(QuranGameService.comboMultiplier(10), 10);
    expect(QuranGameService.comboMultiplier(25), 20);
  });
}
