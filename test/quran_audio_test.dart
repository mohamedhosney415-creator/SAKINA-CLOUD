import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/services/quran_service.dart';
import 'package:sakina/core/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audio positions persist independently by canonical reciter and surah',
      () async {
    await Store.setJson('audio_positions_v1', <String, dynamic>{});
    await QuranService.saveAudioPosition(
        'afasy', 2, const Duration(minutes: 3, seconds: 12));
    await QuranService.saveAudioPosition(
        'husary', 2, const Duration(seconds: 19));
    expect(QuranService.audioPosition('afasy', 2),
        const Duration(minutes: 3, seconds: 12));
    expect(
        QuranService.audioPosition('husary', 2), const Duration(seconds: 19));
    expect(QuranService.audioPosition('afasy', 3), Duration.zero);
  });

  test('resume position tolerates missing and legacy malformed storage',
      () async {
    await Store.setJson('audio_positions_v1',
        <String, dynamic>{'afasy:1': -50, 'afasy:2': 'old'});
    expect(QuranService.audioPosition('afasy', 1), Duration.zero);
    expect(QuranService.audioPosition('afasy', 2), Duration.zero);
    await Store.setStr('audio_positions_v1', '{broken');
    expect(QuranService.audioPosition('afasy', 1), Duration.zero);
  });

  test('each reciter has a distinct canonical source URL and stable ID', () {
    final ids = reciters.map((r) => r.id).toSet();
    expect(ids.length, reciters.length);
    expect(reciterById('afasy').urlFor(1),
        'https://cdn.mp3quran.net/audio/mishary-alafasy/r1/1.mp3');
    expect(reciterById('abdulbasit').urlFor(2),
        'https://cdn.mp3quran.net/audio/abdulbasit-abdulsamad/r3/2.mp3');
    expect(reciterById('abdulbasitmujawwad').urlFor(2),
        isNot(reciterById('abdulbasit').urlFor(2)));
    expect(reciterById('parhizgar').urlFor(1),
        'https://cdn.islamic.network/quran/audio-surah/128/ar.shahriarparhizgar/1.mp3');
  });

  test('download cache validation rejects truncated and non-audio files',
      () async {
    final dir = await Directory.systemTemp.createTemp('sakina-audio-test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/sample.mp3');

    await file.writeAsBytes(List<int>.filled(24, 0));
    expect(await QuranService.isValidAudioFile(file), isFalse);

    await file.writeAsBytes(<int>[...asciiId3, ...List<int>.filled(200, 0)]);
    expect(await QuranService.isValidAudioFile(file), isTrue);

    await file
        .writeAsBytes(<int>[0xff, 0xfb, 0x90, ...List<int>.filled(200, 0)]);
    expect(await QuranService.isValidAudioFile(file), isTrue);
  });
}

const asciiId3 = <int>[0x49, 0x44, 0x33];
