import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/widgets.dart';
import '../data/surahs.dart';
import '../services/audio_controller.dart';
import '../services/quran_service.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<DownloadedFile> files = [];
  int textCount = 0;
  int? progress; // سورة حالية أثناء تحميل النص
  int localView = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await QuranService.downloadedAudio();
    final t = await QuranService.cachedTextCount();
    if (mounted)
      setState(() {
        files = f;
        textCount = t;
      });
  }

  String _mb(int b) => '${ar((b / 1048576).toStringAsFixed(1))} م.ب';
  String _label(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return key;
    final n = int.tryParse(parts[1]);
    if (n == null || n < 1 || n > 114) return key;
    return '${surahs[n - 1].name} • ${reciterById(parts[0]).name}';
  }

  Future<void> _play(String reciter, int number) async {
    await AudioCtl.i.switchReciter(reciter);
    await AudioCtl.i.playSurah(number);
  }

  Future<void> _downloadText() async {
    setState(() => progress = 0);
    try {
      await QuranService.downloadAllText(onProgress: (n) {
        if (mounted) setState(() => progress = n);
      });
      if (mounted)
        toast(context, 'تم تحميل نص القرآن كاملًا للقراءة دون إنترنت');
    } catch (_) {
      if (mounted)
        toast(context, 'تعذر إكمال التحميل، تحقق من الاتصال وحاول ثانية');
    }
    if (mounted) setState(() => progress = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = files.fold<int>(0, (a, b) => a + b.bytes);
    return Scaffold(
      appBar: AppBar(title: const Text('الملفات المحمّلة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('نص القرآن (للقراءة دون إنترنت)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${ar(textCount)} من ١١٤ سورة محفوظة'),
            const SizedBox(height: 10),
            if (progress != null) ...[
              LinearProgressIndicator(value: progress! / 114),
              const SizedBox(height: 6),
              Text('جارٍ التحميل... ${ar(progress!)} / ١١٤'),
            ] else
              Row(children: [
                FilledButton.icon(
                    onPressed: textCount >= 114 ? null : _downloadText,
                    icon: const Icon(Icons.download),
                    label: const Text('تحميل كل السور')),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: textCount == 0
                        ? null
                        : () async {
                            await QuranService.clearText();
                            await _load();
                          },
                    child: const Text('حذف')),
              ]),
          ]),
        ),
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('مؤقت الإيقاف التلقائي',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final minutes in [15, 30, 45, 60])
              OutlinedButton(
                  onPressed: () => setState(() =>
                      AudioCtl.i.setSleepTimer(Duration(minutes: minutes))),
                  child: Text('${ar(minutes)} د')),
            TextButton(
                onPressed: () => setState(AudioCtl.i.cancelSleepTimer),
                child: const Text('إلغاء')),
          ]),
          Text(AudioCtl.i.sleepTimeLeft > Duration.zero
              ? 'الإيقاف بعد ${ar(AudioCtl.i.sleepTimeLeft.inMinutes)} دقيقة'
              : 'غير مفعّل'),
          const SizedBox(height: 8),
          Text(
              'إجمالي الاستماع: ${ar(QuranService.listenedSeconds ~/ 60)} دقيقة'),
        ])),
        const SectionTitle('قائمة التشغيل والمفضلة الصوتية'),
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('قائمة التشغيل'),
              selected: localView == 0,
              onSelected: (_) => setState(() => localView = 0)),
          ChoiceChip(
              label: const Text('المفضلة'),
              selected: localView == 1,
              onSelected: (_) => setState(() => localView = 1)),
        ]),
        for (final key in (localView == 0
            ? QuranService.audioPlaylist
            : QuranService.audioFavorites.toList()))
          ListTile(
            title: Text(_label(key)),
            leading: IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  final p = key.split(':');
                  if (p.length == 2) {
                    final n = int.tryParse(p[1]);
                    if (n != null) _play(p[0], n);
                  }
                }),
            trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () async {
                  final p = key.split(':');
                  if (p.length == 2) {
                    final n = int.tryParse(p[1]);
                    if (n != null) {
                      if (localView == 0)
                        await QuranService.removeFromAudioPlaylist(p[0], n);
                      else
                        await QuranService.toggleAudioFavorite(p[0], n);
                      setState(() {});
                    }
                  }
                }),
          ),
        const SectionTitle('التلاوات المحمّلة'),
        if (files.isEmpty)
          const SizedBox(
              height: 200,
              child: EmptyState(
                  icon: Icons.headphones_outlined,
                  text:
                      'لا توجد تلاوات محمّلة.\nحمّل أي سورة من صفحة القرآن لتسمعها دون إنترنت.'))
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('الإجمالي: ${_mb(total)} • ${ar(files.length)} سورة'),
          ),
          for (final f in files)
            ListTile(
              leading: const SakinaIconBadge(
                  icon: Icons.headphones_rounded, size: 42, iconSize: 21),
              title: Text('سورة ${surahs[f.surah - 1].name}'),
              subtitle:
                  Text('${reciterById(f.reciter).name} • ${_mb(f.bytes)}'),
              onTap: () => _play(f.reciter, f.surah),
              trailing: Wrap(spacing: 0, children: [
                IconButton(
                    tooltip: 'إضافة لقائمة التشغيل',
                    icon: const Icon(Icons.playlist_add),
                    onPressed: () async {
                      await QuranService.addToAudioPlaylist(f.reciter, f.surah);
                      if (mounted) setState(() {});
                    }),
                IconButton(
                    tooltip: 'المفضلة',
                    icon: Icon(QuranService.isAudioFavorite(f.reciter, f.surah)
                        ? Icons.favorite
                        : Icons.favorite_border),
                    onPressed: () async {
                      await QuranService.toggleAudioFavorite(
                          f.reciter, f.surah);
                      if (mounted) setState(() {});
                    }),
                IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await QuranService.deleteAudio(f.reciter, f.surah);
                      await _load();
                    }),
              ]),
            ),
        ],
      ]),
    );
  }
}
