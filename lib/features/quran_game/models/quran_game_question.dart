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
  final String questionText;
  final String contextText;
  final String sourceName;
  final String sourceReference;

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
    this.questionType = 'quran',
    this.questionText = '',
    this.contextText = '',
    this.sourceName = '',
    this.sourceReference = '',
  });

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
        'questionText': questionText,
        'contextText': contextText,
        'sourceName': sourceName,
        'sourceReference': sourceReference,
      };

  factory QuranGameQuestion.fromJson(Map<String, dynamic> j) =>
      QuranGameQuestion(
        id: '${j['id']}',
        surahNumber: _int(j['surahNumber'] ?? j['surah_number']),
        surahName: '${j['surahName'] ?? j['surah_name']}',
        ayahNumber: _int(j['ayahNumber'] ?? j['ayah_number']),
        fullAyah: '${j['fullAyah'] ?? j['full_ayah']}',
        hiddenWord: '${j['hiddenWord'] ?? j['hidden_word']}',
        options: List<String>.from(j['options'] as List),
        correctOption: '${j['correctOption'] ?? j['correct_option']}',
        difficulty: '${j['difficulty']}',
        level: _int(j['level']),
        recitationAudio: (j['recitationAudio'] ?? j['recitation_audio']) as String?,
        globalAyahNumber: _nullableInt(j['globalAyahNumber'] ?? j['global_ayah_number']),
        explanation: (j['explanation']) as String?,
        questionType: '${j['questionType'] ?? j['question_type'] ?? 'quran'}',
        questionText: '${j['questionText'] ?? j['question_text'] ?? ''}',
        contextText: '${j['contextText'] ?? j['context_text'] ?? ''}',
        sourceName: '${j['sourceName'] ?? j['source_name'] ?? ''}',
        sourceReference: '${j['sourceReference'] ?? j['source_reference'] ?? ''}',
      );

  static int _int(dynamic value) => (value as num).toInt();
  static int? _nullableInt(dynamic value) => value == null ? null : (value as num).toInt();

  String get maskedAyah => fullAyah.replaceFirst(hiddenWord, 'ـــــــ');
  bool get isIslamicKnowledge => questionType == 'islamic';
}
