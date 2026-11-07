import 'dart:async';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/audio_controller.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';

/// شاشة الأذان التي تفتح عند الضغط على إشعار الصلاة.
/// ينزّل ملف الأذان عند الحاجة ثم يشغّله من التخزين المحلي.
class AdhanExperiencePage extends StatefulWidget {
  final String prayerKey;
  const AdhanExperiencePage({super.key, required this.prayerKey});
  @override
  State<AdhanExperiencePage> createState() => _AdhanExperiencePageState();
}

class _AdhanExperiencePageState extends State<AdhanExperiencePage> with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  StreamSubscription? playerSub;
  bool audioAvailable = false;
  bool finished = false;
  bool loading = true;
  String muezzinName = 'مؤذن سكينة';

  Prayer get prayer => Prayer.values.firstWhere(
      (p) => p.name == widget.prayerKey,
      orElse: () => Prayer.fajr);

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
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
          if (state.processingState.name == 'completed' && mounted) setState(() => finished = true);
        });
      } catch (_) {
        audioAvailable = false;
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    playerSub?.cancel();
    pulse.dispose();
    if (AudioCtl.i.previewLabel.value != null) AudioCtl.i.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final next = PrayerService.next(cairoNow());
    final prayerName = prayerAr[prayer] ?? 'الصلاة';
    return Scaffold(
      backgroundColor: const Color(0xFF102A25),
      body: SafeArea(child: Stack(children: [
        Positioned(top: -90, left: -70, child: _orb(260, gold.withAlpha(18))),
        Positioned(bottom: -100, right: -80, child: _orb(300, Colors.white.withAlpha(8))),
        ListView(padding: const EdgeInsets.fromLTRB(24, 28, 24, 32), children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('SAKINA', style: TextStyle(color: gold, letterSpacing: 4, fontWeight: FontWeight.w900)),
            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
          ]),
          const SizedBox(height: 36),
          Text('حان الآن وقت صلاة', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 18)),
          const SizedBox(height: 8),
          Text(prayerName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
          const SizedBox(height: 34),
          Center(child: AnimatedBuilder(animation: pulse, builder: (context, _) => Container(
            width: 220 + pulse.value * 18, height: 220 + pulse.value * 18,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold.withAlpha(90), width: 1.5), color: gold.withAlpha(10)),
            child: Center(child: Container(width: 174, height: 174, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF31594D), Color(0xFF183A32)]), boxShadow: [BoxShadow(color: gold.withAlpha(35), blurRadius: 35)]), child: const Icon(Icons.mosque_rounded, size: 82, color: gold))),
          ))),
          const SizedBox(height: 30),
          Text(muezzinName, textAlign: TextAlign.center, style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (loading) const Center(child: CircularProgressIndicator(color: gold))
          else if (!audioAvailable) Panel(color: Colors.white.withAlpha(12), child: const Text('تعذر تنزيل ملف الأذان. تأكد من اتصال الإنترنت أول مرة، ثم سيُحفظ على الجهاز ليعمل دون إنترنت.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, height: 1.8)))
          else Panel(color: Colors.white.withAlpha(12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.graphic_eq, color: gold), const SizedBox(width: 8), Text(finished ? 'انتهى الأذان' : 'الأذان يعمل الآن', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))])),
          const SizedBox(height: 24),
          if (audioAvailable && !finished) FilledButton.icon(onPressed: () async { await AudioCtl.i.stop(); if (mounted) setState(() => finished = true); }, icon: const Icon(Icons.stop_circle_outlined), label: const Text('إيقاف الأذان'), style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF102A25), padding: const EdgeInsets.symmetric(vertical: 15))),
          if (finished || !audioAvailable) OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withAlpha(90)), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('إغلاق الشاشة')),
          const SizedBox(height: 26),
          Panel(color: Colors.white.withAlpha(10), child: Column(children: [const Text('الصلاة التالية', style: TextStyle(color: Colors.white70)), const SizedBox(height: 5), Text('${prayerAr[next.prayer]} • ${fmtTime(next.at)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 4), Text('باقي ${fmtDurWords(next.at.difference(cairoNow()))}', style: const TextStyle(color: gold))])),
          const SizedBox(height: 16),
          Text('اللهم أعنّا على ذكرك وشكرك وحسن عبادتك', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withAlpha(190), height: 1.8)),
        ]),
      ])),
    );
  }

  Widget _orb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}
