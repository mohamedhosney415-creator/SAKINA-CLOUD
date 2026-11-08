import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/art.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/audio_controller.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';

/// شاشة الأذان التي تفتح عند الضغط على إشعار الصلاة (أو تلقائيًا على شاشة القفل).
/// تشغّل الأذان، وعند انتهائه تُزيل الإشعار وتُغلق نفسها بعد ثوانٍ قليلة.
class AdhanExperiencePage extends StatefulWidget {
  final String prayerKey;

  /// عند فتح التطبيق من الإشعار وهو مغلق: نُنهي التطبيق بعد الأذان
  /// ليعود الهاتف لما كان عليه بدل أن يبقى التطبيق مفتوحًا.
  final bool exitAppWhenDone;
  const AdhanExperiencePage(
      {super.key, required this.prayerKey, this.exitAppWhenDone = false});
  @override
  State<AdhanExperiencePage> createState() => _AdhanExperiencePageState();
}

class _AdhanExperiencePageState extends State<AdhanExperiencePage>
    with SingleTickerProviderStateMixin {
  static const _closeDelaySeconds = 4;

  late final AnimationController pulse;
  StreamSubscription? playerSub;
  Timer? _closeTimer;
  bool audioAvailable = false;
  bool finished = false;
  bool loading = true;
  bool _closed = false;
  int _closeIn = _closeDelaySeconds;
  String muezzinName = 'مؤذن سكينة';

  Prayer get prayer => Prayer.values
      .firstWhere((p) => p.name == widget.prayerKey, orElse: () => Prayer.fajr);

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _start();
  }

  Future<void> _start() async {
    Muezzin? selected;
    if (prayer == Prayer.fajr) {
      for (final voice in AdhanAudio.muezzins()) {
        if (voice.id == Settings.i.fajrMuezzin) selected = voice;
      }
    }
    selected ??= await AdhanAudio.selected();
    if (!mounted) return;
    if (selected != null) {
      muezzinName = selected.label;
      try {
        await AudioCtl.i.previewAdhan(selected, fajr: prayer == Prayer.fajr);
        audioAvailable = true;
        playerSub = AudioCtl.i.player.playerStateStream.listen((state) {
          if (state.processingState.name == 'completed') _markFinished();
        });
      } catch (_) {
        audioAvailable = false;
      }
    }
    if (!mounted) return;
    setState(() => loading = false);
    // لا يوجد صوت لننتظره: نترك رسالة الخطأ ظاهرة قليلًا ثم نغلق.
    if (!audioAvailable) _scheduleClose(seconds: 10);
  }

  /// الأذان انتهى (أو أوقفه المستخدم): أزل الإشعار وابدأ الإغلاق التلقائي.
  void _markFinished() {
    if (!mounted || finished) return;
    setState(() => finished = true);
    NotificationService.dismissAdhanNotifications();
    _scheduleClose(seconds: _closeDelaySeconds);
  }

  void _scheduleClose({required int seconds}) {
    _closeTimer?.cancel();
    _closeIn = seconds;
    if (mounted) setState(() {});
    _closeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_closeIn <= 1) {
        t.cancel();
        _close();
      } else {
        setState(() => _closeIn--);
      }
    });
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    _closeTimer?.cancel();
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
    if (widget.exitAppWhenDone) {
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    playerSub?.cancel();
    pulse.dispose();
    if (AudioCtl.i.previewLabel.value != null) AudioCtl.i.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = PrayerService.next(cairoNow());
    final prayerName = prayerAr[prayer] ?? 'الصلاة';
    return Scaffold(
      backgroundColor: const Color(0xFF0B1E26),
      body: Stack(children: [
        // سماء ليلية متدرجة
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B1E26), Color(0xFF123A3D), Color(0xFF0E2C2E)],
              ),
            ),
            child: CustomPaint(
                painter: StarsPainter(color: Colors.white, count: 46)),
          ),
        ),
        // مئذنة وقبة في الأسفل
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 190,
          child: CustomPaint(
              painter: SkylinePainter(color: Colors.black.withAlpha(70))),
        ),
        SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SAKINA',
                          style: TextStyle(
                              color: gold,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w900)),
                      IconButton(
                          tooltip: 'إغلاق',
                          onPressed: _close,
                          icon: const Icon(Icons.close, color: Colors.white)),
                    ]),
                const SizedBox(height: 24),
                Text('حان الآن وقت صلاة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withAlpha(210), fontSize: 18)),
                const SizedBox(height: 6),
                Text(prayerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 28),
                Center(
                    child: AnimatedBuilder(
                        animation: pulse,
                        builder: (context, _) => Container(
                              width: 220 + pulse.value * 18,
                              height: 220 + pulse.value * 18,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: gold.withAlpha(90), width: 1.5),
                                  color: gold.withAlpha(10)),
                              child: Center(
                                  child: Container(
                                      width: 174,
                                      height: 174,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF31594D),
                                                Color(0xFF183A32)
                                              ]),
                                          boxShadow: [
                                            BoxShadow(
                                                color: gold.withAlpha(45),
                                                blurRadius: 38)
                                          ]),
                                      child: Center(
                                          child: PrayerGlyph(
                                              prayer: prayer,
                                              size: 84,
                                              color: gold)))),
                            ))),
                const SizedBox(height: 26),
                Text(muezzinName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: gold, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (loading)
                  const Center(child: CircularProgressIndicator(color: gold))
                else if (!audioAvailable)
                  Panel(
                      color: Colors.white.withAlpha(14),
                      child: const Text(
                          'تعذر تنزيل ملف الأذان. تأكد من اتصال الإنترنت أول مرة، ثم سيُحفظ على الجهاز ليعمل دون إنترنت.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, height: 1.8)))
                else
                  Panel(
                      color: Colors.white.withAlpha(14),
                      child: Column(children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.graphic_eq_rounded, color: gold),
                              const SizedBox(width: 8),
                              Text(finished ? 'انتهى الأذان' : 'الأذان يعمل الآن',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800))
                            ]),
                        const SizedBox(height: 12),
                        _progress(),
                      ])),
                const SizedBox(height: 20),
                if (audioAvailable && !finished)
                  FilledButton.icon(
                      onPressed: () async {
                        await AudioCtl.i.stop();
                        _markFinished();
                      },
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('إيقاف الأذان'),
                      style: FilledButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: const Color(0xFF102A25),
                          padding: const EdgeInsets.symmetric(vertical: 15))),
                if (finished || !audioAvailable)
                  OutlinedButton(
                      onPressed: _close,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withAlpha(90)),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(
                          'إغلاق الآن • يُغلق تلقائيًا بعد ${ar(_closeIn)} ث')),
                const SizedBox(height: 22),
                Panel(
                    color: Colors.white.withAlpha(12),
                    child: Column(children: [
                      const Text('الصلاة التالية',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 5),
                      Text('${prayerAr[next.prayer]} • ${fmtTime(next.at)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('باقي ${fmtDurWords(next.at.difference(cairoNow()))}',
                          style: const TextStyle(color: gold))
                    ])),
                const SizedBox(height: 16),
                Text('اللهم أعنّا على ذكرك وشكرك وحسن عبادتك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withAlpha(190), height: 1.8)),
              ]),
        ),
      ]),
    );
  }

  /// شريط تقدم الأذان.
  Widget _progress() {
    return StreamBuilder<Duration>(
      stream: AudioCtl.i.player.positionStream,
      builder: (context, snap) {
        final d = AudioCtl.i.player.duration;
        final pos = snap.data ?? Duration.zero;
        final double? v = (d == null || d.inMilliseconds == 0)
            ? null
            : (pos.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0).toDouble();
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              value: finished ? 1.0 : v,
              minHeight: 6,
              color: gold,
              backgroundColor: Colors.white.withAlpha(30)),
        );
      },
    );
  }
}
