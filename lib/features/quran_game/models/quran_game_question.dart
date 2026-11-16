class QuranGameQuestion {
  final String id;
  final int surahNumber;
  final String surahName;
  final int ayahNumber;
  final String fullAyah;
  final String hiddenWord;
  final List<String> options;
  final String correctOption;
  final String difficulty;
  final int level;
  final String? recitationAudio;
  final int? globalAyahNumber;
  final String? explanation;
  final String questionType;
  final String category;
  final String? prompt;
  final int xp;

  const QuranGameQuestion({
    required this.id,
    required this.surahNumber,
    required this.surahName,
    required this.ayahNumber,
    required this.fullAyah,
    required this.hiddenWord,
    required this.options,
    required this.correctOption,
    required this.difficulty,
    required this.level,
    this.recitationAudio,
    this.globalAyahNumber,
    this.explanation,
    this.questionType = 'complete_word',
    this.category = 'quran',
    this.prompt,
    this.xp = 10,
  });

  bool get isQuran => category == 'quran';
  bool get isTrueFalse => questionType == 'true_false';
  bool get isMcq => questionType == 'mcq';
  bool get isCompleteWord => questionType == 'complete_word';
  bool get isCompleteVerse => questionType == 'complete_verse';
  bool get isIdentifySurah => questionType == 'identify_surah';
  bool get isPreviousNext => questionType == 'previous_next';

  String get displayPrompt {
    if (prompt != null && prompt!.trim().isNotEmpty) return prompt!;
    switch (questionType) {
      case 'identify_surah':
        return 'إلى أي سورة تنتمي هذه الآية؟';
      case 'previous_next':
        return 'ما الآية التي تأتي بعد/قبل هذه الآية؟';
      case 'true_false':
        return 'هل العبارة التالية صحيحة؟';
      case 'complete_verse':
        return 'أكمل الآية التالية:';
      default:
        return 'أكمل الكلمة الناقصة:';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'surahNumber': surahNumber,
        'surahName': surahName,
        'ayahNumber': ayahNumber,
        'fullAyah': fullAyah,
        'hiddenWord': hiddenWord,
        'options': options,
        'correctOption': correctOption,
        'difficulty': difficulty,
        'level': level,
        'recitationAudio': recitationAudio,
        'globalAyahNumber': globalAyahNumber,
        'explanation': explanation,
        'questionType': questionType,
        'category': category,
        'prompt': prompt,
        'xp': xp,
      };

  factory QuranGameQuestion.fromJson(Map<String, dynamic> j) =>
      QuranGameQuestion(
        id: '${j['id']}',
        surahNumber: _int(j['surahNumber'] ?? j['surah_number']),
        surahName: '${j['surahName'] ?? j['surah_name']}',
        ayahNumber: _int(j['ayahNumber'] ?? j['ayah_number']),
        fullAyah: '${j['fullAyah'] ?? j['full_ayah'] ?? ''}',
        hiddenWord: '${j['hiddenWord'] ?? j['hidden_word'] ?? ''}',
        options: _stringList(j['options']),
        correctOption: '${j['correctOption'] ?? j['correct_option'] ?? ''}',
        difficulty: '${j['difficulty'] ?? 'easy'}',
        level: _int(j['level'] ?? 1),
        recitationAudio:
            (j['recitationAudio'] ?? j['recitation_audio']) as String?,
        globalAyahNumber:
            _nullableInt(j['globalAyahNumber'] ?? j['global_ayah_number']),
        explanation: j['explanation'] as String?,
        questionType:
            '${j['questionType'] ?? j['question_type'] ?? 'complete_word'}',
        category: '${j['category'] ?? 'quran'}',
        prompt: j['prompt'] as String?,
        xp: _int(j['xp'] ?? 10),
      );

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => '$e').toList(growable: false);
    return const <String>[];
  }

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static int? _nullableInt(dynamic value) =>
      value == null ? null : _int(value);

  String get maskedAyah {
    if (hiddenWord.isEmpty) return fullAyah;
    return fullAyah.replaceFirst(hiddenWord, 'ـــــــ');
  }
}
