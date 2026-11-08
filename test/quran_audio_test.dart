import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/services/quran_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
