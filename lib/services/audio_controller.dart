import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../core/settings.dart';
import '../data/surahs.dart';
import 'notification_service.dart';
import 'quran_service.dart';
/// مشغّل صوت واحد للتطبيق كله (القرآن + تجربة الأذان) مع إشعار التحكم بالخلفية.
class AudioCtl {
  static final AudioCtl i = AudioCtl._();
  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<int?> surah = ValueNotifier(null);
  final ValueNotifier<String?> previewLabel = ValueNotifier(null);
  bool _advancing = false;
  Future<void> _sourceQueue = Future<void>.value();

  AudioCtl._() {
    player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed) {
        final n = surah.value;
        if (n != null && previewLabel.value == null) {
          if (Settings.i.autoNext && n < 114 && !_advancing) {
            _advancing = true;
            playSurah(n + 1).whenComplete(() => _advancing = false).catchError((_) {});
          }
        } else if (previewLabel.value != null) {
          previewLabel.value = null;
        }
      }
    }, onError: (Object _) {});
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _sourceQueue.then((_) => operation());
    _sourceQueue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> playSurah(int n) => _serialize(() async {
        await _loadSurah(n, position: Duration.zero, resume: true);
      });

  /// Change the preferred reciter, preserving active Quran playback state.
  Future<void> switchReciter(String id) => _serialize(() async {
        final currentSurah = surah.value;
        final isQuran = currentSurah != null && previewLabel.value == null;
        final resume = isQuran && player.playing;
        final position = isQuran ? player.position : Duration.zero;
        await Settings.i.set('reciter', id);
        if (isQuran) {
          try {
            await _loadSurah(currentSurah, position: position, resume: resume);
          } catch (_) {
            await player.stop();
            previewLabel.value = null;
            surah.value = null;
            rethrow;
          }
        }
      });

  /// Explicitly preview the selected reciter with Al-Fatiha.
  Future<void> previewReciter(String id) => _serialize(() async {
        await Settings.i.set('reciter', id);
        await _loadSurah(1, position: Duration.zero, resume: true);
      });

  Future<void> _loadSurah(int n,
      {required Duration position, required bool resume}) async {
    if (n < 1 || n > 114) throw RangeError.range(n, 1, 114, 'n');
    final s = surahs[n - 1];
    final rec = reciterById(Settings.i.reciter);
    final tag = MediaItem(
      id: '${rec.id}-$n',
      title: 'سورة ${s.name}',
      artist: rec.name,
      album: 'القرآن الكريم - سكينة',
    );
    final local = await QuranService.audioFile(rec.id, n);
    if (await local.exists()) {
      try {
        if (await local.length() < 128) throw const FormatException('Invalid audio file');
        await _setSource(AudioSource.uri(Uri.file(local.path), tag: tag), position);
      } catch (_) {
        // Remove a broken cache entry, then fall back to the network source.
        try {
          await local.delete();
        } catch (_) {}
        await _setSource(AudioSource.uri(Uri.parse(rec.urlFor(n)), tag: tag), position);
      }
    } else {
      await _setSource(AudioSource.uri(Uri.parse(rec.urlFor(n)), tag: tag), position);
    }
    await player.setVolume(1.0);
    previewLabel.value = null;
    surah.value = n;
    if (resume) {
      unawaited(player.play().catchError((Object _) {}));
    } else {
      await player.pause();
    }
  }

  Future<void> _setSource(AudioSource source, Duration position) async {
    await player.setAudioSource(source);
    if (position > Duration.zero) await player.seek(position);
  }

  Future<void> previewAdhan(Muezzin m, {bool fajr = false}) => _serialize(() async {
        final file = await AdhanAudio.download(m, fajr: fajr);
        final tag = MediaItem(
          id: 'adhan-${m.id}',
          title: fajr ? 'أذان الفجر' : 'الأذان',
          artist: m.label,
        );
        surah.value = null;
        previewLabel.value = m.label;
        await player.setVolume(Settings.i.volume);
        await player.setAudioSource(AudioSource.uri(Uri.file(file.path), tag: tag));
        unawaited(player.play().catchError((Object _) {}));
      });

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> stop() => _serialize(() async {
        await player.stop();
        previewLabel.value = null;
        surah.value = null;
      });
}
