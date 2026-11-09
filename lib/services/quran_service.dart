import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/store.dart';
import '../data/surahs.dart';

class Ayah {
  final int n;
  final String text;
  Ayah(this.n, this.text);
}

/// القرّاء. لإضافة قارئ جديد: أضف عنصرًا هنا بنمط رابط يحتوي {n} (رقم السورة).
class Reciter {
  final String id, name, urlPattern;
  const Reciter(this.id, this.name, this.urlPattern);
  String urlFor(int surah) => urlPattern.replaceAll('{n}', '$surah');
}

const reciters = <Reciter>[
  Reciter('afasy', 'الشيخ مشاري راشد العفاسي',
      'https://cdn.mp3quran.net/audio/mishary-alafasy/r1/{n}.mp3'),
  Reciter('abdulbasit', 'الشيخ عبد الباسط عبد الصمد – مرتل',
      'https://cdn.mp3quran.net/audio/abdulbasit-abdulsamad/r3/{n}.mp3'),
  Reciter('abdulbasitmujawwad', 'الشيخ عبد الباسط عبد الصمد – مجود',
      'https://cdn.mp3quran.net/audio/abdulbasit-abdulsamad/r1/{n}.mp3'),
  Reciter('minshawi', 'الشيخ محمد صديق المنشاوي',
      'https://cdn.mp3quran.net/audio/muhammad-minshawi/r1/{n}.mp3'),
  Reciter('minshawimujawwad', 'الشيخ محمد صديق المنشاوي – مجود',
      'https://cdn.mp3quran.net/audio/muhammad-minshawi/r2/{n}.mp3'),
  Reciter('husary', 'الشيخ محمود خليل الحصري',
      'https://cdn.mp3quran.net/audio/mahmoud-husary/r1/{n}.mp3'),
  Reciter('husarymujawwad', 'الشيخ محمود خليل الحصري – مجود',
      'https://cdn.mp3quran.net/audio/mahmoud-husary/r2/{n}.mp3'),
  Reciter('sudais', 'الشيخ عبد الرحمن السديس',
      'https://cdn.mp3quran.net/audio/abdulrahman-sudais/r1/{n}.mp3'),
  Reciter('shuraim', 'الشيخ سعود الشريم',
      'https://cdn.mp3quran.net/audio/saud-shuraim/r1/{n}.mp3'),
  Reciter('ajamy', 'الشيخ أحمد العجمي',
      'https://cdn.mp3quran.net/audio/ahmad-ajmi/r1/{n}.mp3'),
  Reciter('muhammadayoub', 'الشيخ محمد أيوب',
      'https://cdn.mp3quran.net/audio/muhammad-ayyub/r1/{n}.mp3'),
  Reciter('muhammadjibreel', 'الشيخ محمد جبريل',
      'https://cdn.mp3quran.net/audio/muhammad-jibreel/r1/{n}.mp3'),
  Reciter('hudhaify', 'الشيخ علي الحذيفي',
      'https://cdn.mp3quran.net/audio/ali-hudhaifi/r1/{n}.mp3'),
  Reciter('parhizgar', 'الشيخ شهريار پرهيزگار',
      'https://cdn.islamic.network/quran/audio-surah/128/ar.shahriarparhizgar/{n}.mp3'),
  Reciter('hanirifai', 'الشيخ هاني الرفاعي',
      'https://cdn.mp3quran.net/audio/hani-rifai/r1/{n}.mp3'),
];

Reciter reciterById(String id) =>
    reciters.firstWhere((r) => r.id == id, orElse: () => reciters.first);

class DownloadedFile {
  final String reciter;
  final int surah;
  final int bytes;
  final File file;
  DownloadedFile(this.reciter, this.surah, this.bytes, this.file);
}

class QuranService {
  static String _audioKey(String reciter, int surah) => '$reciter:$surah';
  static Set<String> get audioFavorites =>
      (Store.json('audio_favorites', <dynamic>[]) as List)
          .cast<String>()
          .toSet();
  static List<String> get audioPlaylist =>
      (Store.json('audio_playlist', <dynamic>[]) as List).cast<String>();
  static bool isAudioFavorite(String reciter, int surah) =>
      audioFavorites.contains(_audioKey(reciter, surah));
  static Future<void> toggleAudioFavorite(String reciter, int surah) async {
    final items = audioFavorites;
    final key = _audioKey(reciter, surah);
    if (!items.add(key)) items.remove(key);
    await Store.setJson('audio_favorites', items.toList());
  }

  static Future<void> addToAudioPlaylist(String reciter, int surah) async {
    final items = audioPlaylist;
    final key = _audioKey(reciter, surah);
    if (!items.contains(key)) items.add(key);
    await Store.setJson('audio_playlist', items);
  }

  static Future<void> removeFromAudioPlaylist(String reciter, int surah) async {
    final items = audioPlaylist..remove(_audioKey(reciter, surah));
    await Store.setJson('audio_playlist', items);
  }

  // Versioned JSON map keyed by canonical reciter/surah. Missing or malformed
  // legacy values safely behave as an empty resume history.
  static Map<String, dynamic> get _audioPositions {
    final value = Store.json('audio_positions_v1', <String, dynamic>{});
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  static Duration audioPosition(String reciter, int surah) {
    final value = _audioPositions[_audioKey(reciterById(reciter).id, surah)];
    final ms = value is num ? value.toInt() : 0;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  static Future<void> saveAudioPosition(
      String reciter, int surah, Duration position) async {
    if (surah < 1 || surah > 114) return;
    final values = _audioPositions;
    final ms = position.inMilliseconds;
    if (ms <= 0) {
      values.remove(_audioKey(reciterById(reciter).id, surah));
    } else {
      values[_audioKey(reciterById(reciter).id, surah)] = ms;
    }
    await Store.setJson('audio_positions_v1', values);
  }

  static int get listenedSeconds => Store.integer('audio_listened_seconds', 0);
  static Future<void> recordListeningSeconds(int seconds) async {
    if (seconds > 0) {
      await Store.setInt('audio_listened_seconds', listenedSeconds + seconds);
    }
  }

  static Future<Directory> _dir(String sub) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$sub');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // ---------- النص ----------
  static String _plain(String s) => s
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll('ٱ', 'ا');

  /// النص من المصدر يبدأ بالبسملة في أول آية؛ نفصلها لنعرضها كسطر مستقل.
  static String _stripBasmala(String t) {
    final words = t.trim().split(RegExp(r'\s+'));
    if (words.length > 4 &&
        _plain(words.sublist(0, 4).join(' ')) == 'بسم الله الرحمن الرحيم') {
      return words.sublist(4).join(' ');
    }
    return t;
  }

  static List<Ayah> _parse(int surah, List list) {
    final out = <Ayah>[];
    for (final a in list) {
      final n = (a['n'] as num).toInt();
      var t = a['t'].toString();
      if (n == 1 && surah != 1 && surah != 9) t = _stripBasmala(t);
      out.add(Ayah(n, t));
    }
    return out;
  }

  static Future<File> _textFile(int s) async =>
      File('${(await _dir('quran_text')).path}/$s.json');

  static Future<bool> hasText(int s) async => (await _textFile(s)).exists();

  /// يقرأ من التخزين المحلي، وإن لم يوجد يحمّله مرة واحدة ويحفظه.
  static Future<List<Ayah>> text(int s) async {
    final f = await _textFile(s);
    if (await f.exists()) {
      try {
        return _parse(s, jsonDecode(await f.readAsString()) as List);
      } catch (_) {
        await f.delete();
      }
    }
    final r = await http
        .get(Uri.parse('https://api.alquran.cloud/v1/surah/$s/quran-uthmani'))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('quran-text');
    final data = jsonDecode(utf8.decode(r.bodyBytes))['data']['ayahs'] as List;
    final list =
        data.map((a) => {'n': a['numberInSurah'], 't': a['text']}).toList();
    await f.writeAsString(jsonEncode(list));
    return _parse(s, list);
  }

  static Future<int> cachedTextCount() async {
    final d = await _dir('quran_text');
    return d.listSync().whereType<File>().length;
  }

  static Future<void> downloadAllText(
      {void Function(int done)? onProgress}) async {
    for (final s in surahs) {
      if (!await hasText(s.number)) {
        await text(s.number);
      }
      onProgress?.call(s.number);
    }
  }

  static Future<void> clearText() async {
    final d = await _dir('quran_text');
    for (final f in d.listSync()) {
      try {
        f.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// بحث نصي داخل السور المحفوظة محليًا؛ لا يجري أي اتصال بالشبكة.
  static Future<List<(int, Ayah)>> searchCached(String query,
      {int limit = 100}) async {
    String norm(String value) => value
        .replaceAll(
            RegExp('[\\u064B-\\u065F\\u0670\\u06D6-\\u06ED\\u0640]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final needle = norm(query);
    if (needle.isEmpty) return [];
    final out = <(int, Ayah)>[];
    for (final s in surahs) {
      final f = await _textFile(s.number);
      if (!await f.exists()) continue;
      try {
        final list = jsonDecode(await f.readAsString()) as List;
        for (final ayah in _parse(s.number, list)) {
          if (norm(ayah.text).contains(needle)) {
            out.add((s.number, ayah));
            if (out.length >= limit) return out;
          }
        }
      } catch (_) {/* تجاهل ملف محلي تالف واستمر */}
    }
    return out;
  }

  // ---------- الصوت ----------
  static Future<File> audioFile(String reciter, int s) async {
    final canonicalId = reciterById(reciter).id;
    return File(
        '${(await _dir('audio/$canonicalId')).path}/${s.toString().padLeft(3, '0')}.mp3');
  }

  /// Reject empty/truncated cache entries before they mask a valid network URL.
  static Future<bool> isValidAudioFile(File file) async {
    try {
      if (!await file.exists() || await file.length() < 128) return false;
      final handle = await file.open();
      try {
        final header = await handle.read(3);
        // MP3 streams may start with an ID3 tag or an MPEG frame sync word.
        return header.length >= 3 &&
            (String.fromCharCodes(header) == 'ID3' ||
                (header[0] == 0xff && (header[1] & 0xe0) == 0xe0));
      } finally {
        await handle.close();
      }
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDownloaded(String reciter, int s) async =>
      isValidAudioFile(await audioFile(reciter, s));

  static Future<void> downloadAudio(String reciterId, int s,
      {void Function(double p)? onProgress}) async {
    final rec = reciterById(reciterId);
    final client = http.Client();
    try {
      final res = await client
          .send(http.Request('GET', Uri.parse(rec.urlFor(s))))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('audio ${res.statusCode}');
      final total = res.contentLength ?? 0;
      final file = await audioFile(rec.id, s);
      final tmp = File('${file.path}.part');
      try {
        final sink = tmp.openWrite();
        int got = 0;
        try {
          await for (final chunk in res.stream) {
            sink.add(chunk);
            got += chunk.length;
            if (total > 0) onProgress?.call(got / total);
          }
        } finally {
          await sink.close();
        }
        if (!await isValidAudioFile(tmp)) {
          throw const FormatException('Downloaded audio is invalid');
        }
        if (await file.exists()) await file.delete();
        await tmp.rename(file.path);
      } catch (_) {
        if (await tmp.exists()) await tmp.delete();
        rethrow;
      }
    } finally {
      client.close();
    }
  }

  static Future<void> deleteAudio(String reciter, int s) async {
    final f = await audioFile(reciter, s);
    if (await f.exists()) await f.delete();
  }

  static Future<List<DownloadedFile>> downloadedAudio() async {
    final out = <DownloadedFile>[];
    for (final r in reciters) {
      final d = await _dir('audio/${r.id}');
      for (final e in d.listSync().whereType<File>()) {
        final name = e.path.split('/').last;
        if (!name.endsWith('.mp3') || !isValidAudioFileSync(e)) continue;
        final n = int.tryParse(name.replaceAll('.mp3', ''));
        if (n == null || n < 1 || n > 114) continue;
        out.add(DownloadedFile(r.id, n, e.lengthSync(), e));
      }
    }
    out.sort((a, b) => a.surah.compareTo(b.surah));
    return out;
  }
}

bool isValidAudioFileSync(File file) {
  try {
    if (file.lengthSync() < 128) return false;
    final header = file.openSync();
    try {
      final bytes = header.readSync(3);
      return bytes.length >= 3 &&
          (String.fromCharCodes(bytes) == 'ID3' ||
              (bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0));
    } finally {
      header.closeSync();
    }
  } catch (_) {
    return false;
  }
}
