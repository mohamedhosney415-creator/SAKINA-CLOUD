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
  final ValueNotifier<int> memorizationRemaining = ValueNotifier(0);
  final ValueNotifier<int?> memorizationAyah = ValueNotifier(null);
  int? _memorizeSurah, _memorizeEnd;
  int _memorizeRepeats = 1, _memorizeDone = 0;
  int _globalAyah(int surah, int ayah) =>
      surahs.take(surah - 1).fold<int>(0, (n, s) => n + s.ayahs) + ayah;
  // `playing` is false while just_audio is loading/buffering, so preserve the
  // requested state independently during source changes.
  bool _wantsPlayback = false;
  Future<void> _sourceQueue = Future<void>.value();
  Timer? _sleepTimer;
  Timer? _positionSaveTimer;
  DateTime? _lastListeningTick;
  Duration get sleepTimeLeft => _sleepTimer == null || !_sleepTimer!.isActive
      ? Duration.zero
      : _sleepDeadline.difference(DateTime.now());
  DateTime _sleepDeadline = DateTime.fromMillisecondsSinceEpoch(0);

  AudioCtl._() {
    player.playingStream.listen((playing) {
      if (playing) _wantsPlayback = true;
      _lastListeningTick =
          playing && surah.value != null ? DateTime.now() : null;
    });
    player.positionStream.listen((position) {
      final n = surah.value;
      if (n != null && previewLabel.value == null) {
        _positionSaveTimer?.cancel();
        _positionSaveTimer = Timer(const Duration(seconds: 2), () {
          unawaited(
              QuranService.saveAudioPosition(Settings.i.reciter, n, position));
        });
      }
      final last = _lastListeningTick;
      if (last == null || !player.playing || surah.value == null) return;
      final now = DateTime.now();
      final seconds = now.difference(last).inSeconds;
      if (seconds > 0) {
        _lastListeningTick = now;
        unawaited(QuranService.recordListeningSeconds(seconds));
      }
    });
    player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed) {
        _wantsPlayback = false;
        if (_memorizeSurah != null) {
          unawaited(_memorizationCompleted());
          return;
        }
        final n = surah.value;
        if (n != null && previewLabel.value == null) {
          if (Settings.i.autoNext && n < 114 && !_advancing) {
            _advancing = true;
            playSurah(n + 1)
                .whenComplete(() => _advancing = false)
                .catchError((_) {});
          }
        } else if (previewLabel.value != null) {
          previewLabel.value = null;
        }
      }
    }, onError: (Object _) {});
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _sourceQueue.then((_) => operation());
    _sourceQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> playSurah(int n) => _serialize(() async {
        _memorizeSurah = null;
        memorizationRemaining.value = 0;
        _wantsPlayback = true;
        await _loadSurah(n,
            position: QuranService.audioPosition(Settings.i.reciter, n),
            resume: true);
      });

  Future<void> setVolume(double volume) async {
    final safe = volume.clamp(0.0, 1.0).toDouble();
    await Settings.i.set('volume', safe);
    await player.setVolume(safe);
  }

  Future<void> setRepeatMode(int mode) async {
    final safe = mode.clamp(0, 2);
    await Settings.i.set('quranRepeatMode', safe);
    await player.setLoopMode(safe == 1 ? LoopMode.one : LoopMode.off);
  }

  Future<void> startMemorization(
      int surahNumber, int startAyah, int endAyah, int repeats) async {
    if (surahNumber < 1 ||
        surahNumber > 114 ||
        startAyah < 1 ||
        endAyah < startAyah ||
        endAyah > surahs[surahNumber - 1].ayahs ||
        !const [1, 3, 5, 10, 20].contains(repeats)) {
      throw ArgumentError('Invalid memorization range');
    }
    _memorizeSurah = surahNumber;
    _memorizeEnd = endAyah;
    _memorizeRepeats = repeats;
    _memorizeDone = 0;
    memorizationAyah.value = startAyah;
    memorizationRemaining.value = (endAyah - startAyah + 1) * repeats;
    await _playMemorizationAyah();
  }

  Future<void> _playMemorizationAyah() async {
    final s = _memorizeSurah, a = memorizationAyah.value;
    if (s == null || a == null) return;
    _memorizeDone = 0;
    await playAyah(_globalAyah(s, a));
  }

  Future<void> _memorizationCompleted() async {
    final a = memorizationAyah.value;
    if (a == null) return;
    _memorizeDone++;
    memorizationRemaining.value =
        (memorizationRemaining.value - 1).clamp(0, 1 << 30);
    if (_memorizeDone < _memorizeRepeats) {
      await _playMemorizationAyah();
    } else if (a < (_memorizeEnd ?? a)) {
      memorizationAyah.value = a + 1;
      await _playMemorizationAyah();
    } else {
      _memorizeSurah = null;
      memorizationAyah.value = null;
    }
  }

  /// Play one Quran ayah through the shared app player. Quran Game uses the
  /// global ayah number from the trusted Quran API audio endpoint.
  Future<void> playAyah(int globalAyahNumber) => _serialize(() async {
        if (globalAyahNumber < 1 || globalAyahNumber > 6236) {
          throw RangeError.range(globalAyahNumber, 1, 6236, 'globalAyahNumber');
        }
        _wantsPlayback = true;
        if (player.playing) await player.stop();
        surah.value = null;
        previewLabel.value = 'تلاوة آية';
        final tag = MediaItem(
          id: 'game-ayah-$globalAyahNumber',
          title: 'تلاوة آية من القرآن الكريم',
          artist: reciterById(Settings.i.reciter).name,
          album: 'سكينة • أكمل الآية',
        );
        await player.setVolume(Settings.i.volume);
        await player.setLoopMode(LoopMode.off);
        await player.setAudioSource(
          AudioSource.uri(
            Uri.parse(
              'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$globalAyahNumber.mp3',
            ),
            tag: tag,
          ),
        );
        unawaited(
          player.play().catchError((Object _) {
            _wantsPlayback = false;
          }),
        );
      });

  /// Change the preferred reciter, preserving active Quran playback state.
  Future<void> switchReciter(String id) => _serialize(() async {
        final currentSurah = surah.value;
        final isQuran = currentSurah != null && previewLabel.value == null;
        final resume = isQuran && _wantsPlayback;
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
        _wantsPlayback = true;
        await Settings.i.set('reciter', id);
        await _loadSurah(1, position: Duration.zero, resume: true);
      });

  Future<void> _loadSurah(
    int n, {
    required Duration position,
    required bool resume,
  }) async {
    if (n < 1 || n > 114) throw RangeError.range(n, 1, 114, 'n');
    final s = surahs[n - 1];
    final rec = reciterById(Settings.i.reciter);
    final tag = MediaItem(
      id: '${rec.id}-$n',
      title: 'سورة ${s.name}',
      artist: rec.name,
      album: 'القرآن الكريم - سكينة',
    );
    if (player.playing) await player.pause();
    final local = await QuranService.audioFile(rec.id, n);
    if (await local.exists() && await QuranService.isValidAudioFile(local)) {
      try {
        await _setSource(
          AudioSource.uri(Uri.file(local.path), tag: tag),
          position,
        );
      } catch (_) {
        // Remove a broken cache entry, then fall back to the network source.
        try {
          await local.delete();
        } catch (_) {}
        await _setSource(
          AudioSource.uri(Uri.parse(rec.urlFor(n)), tag: tag),
          position,
        );
      }
    } else {
      if (await local.exists()) {
        try {
          await local.delete();
        } catch (_) {}
      }
      await _setSource(
        AudioSource.uri(Uri.parse(rec.urlFor(n)), tag: tag),
        position,
      );
    }
    await player.setVolume(Settings.i.volume);
    await player.setLoopMode(Settings.i.intOf('quranRepeatMode', 0) == 1
        ? LoopMode.one
        : LoopMode.off);
    previewLabel.value = null;
    surah.value = n;
    if (resume) {
      _wantsPlayback = true;
      unawaited(
        player.play().catchError((Object _) {
          _wantsPlayback = false;
        }),
      );
    } else {
      _wantsPlayback = false;
      await player.pause();
    }
  }

  Future<void> _setSource(AudioSource source, Duration position) async {
    await player.setAudioSource(source);
    if (position > Duration.zero) {
      final duration = player.duration;
      final safePosition = duration == null || position < duration
          ? position
          : duration - const Duration(milliseconds: 250);
      await player.seek(
        safePosition < Duration.zero ? Duration.zero : safePosition,
      );
    }
  }

  Future<void> previewAdhan(Muezzin m, {bool fajr = false}) =>
      _serialize(() async {
        final file = await AdhanAudio.download(m, fajr: fajr);
        _wantsPlayback = false;
        final tag = MediaItem(
          id: 'adhan-${m.id}',
          title: fajr ? 'أذان الفجر' : 'الأذان',
          artist: m.label,
        );
        surah.value = null;
        previewLabel.value = m.label;
        await player.setVolume(Settings.i.volume);
        await player.setAudioSource(
          AudioSource.uri(Uri.file(file.path), tag: tag),
        );
        unawaited(player.play().catchError((Object _) {}));
      });

  Future<void> toggle() async {
    if (player.playing) {
      _wantsPlayback = false;
      await player.pause();
    } else {
      _wantsPlayback = true;
      await player.play();
    }
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    if (duration <= Duration.zero) return;
    _sleepDeadline = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      unawaited(stop());
      _sleepTimer = null;
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  Future<void> stop() => _serialize(() async {
        cancelSleepTimer();
        _positionSaveTimer?.cancel();
        final currentSurah = surah.value;
        if (currentSurah != null && previewLabel.value == null) {
          await QuranService.saveAudioPosition(
              Settings.i.reciter, currentSurah, player.position);
        }
        _memorizeSurah = null;
        memorizationRemaining.value = 0;
        await player.stop();
        _wantsPlayback = false;
        previewLabel.value = null;
        surah.value = null;
      });
}
