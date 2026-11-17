import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/diag.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'features/azkar_page.dart';
import 'features/diagnostics_page.dart';
import 'features/home_page.dart';
import 'features/more_page.dart';
import 'features/messages_page.dart';
import 'features/prayer_page.dart';
import 'features/quran_page.dart';
import 'features/quran_game/pages/quran_game_page.dart';
import 'services/notification_service.dart';
import 'services/backup_service.dart';
import 'cloud/cloud_service.dart';
import 'features/auth_page.dart';
import 'features/onboarding_page.dart';
import 'services/update_service.dart';

class SakinaApp extends StatefulWidget {
  const SakinaApp({super.key});
  @override
  State<SakinaApp> createState() => _SakinaAppState();
}

class _SakinaAppState extends State<SakinaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  Future<void> _startup() async {
    await Diag.guard('update-check', () => UpdateService.showIfNeeded(sakinaNavigatorKey.currentContext ?? context));
    await Diag.guard('automatic-backup', BackupService.ensureDailyAutoBackup);
    await Diag.guard(
        'audio-background',
        () => JustAudioBackground.init(
              androidNotificationChannelId: 'com.hosny.sakina.audio',
              androidNotificationChannelName: 'تشغيل القرآن',
              androidNotificationOngoing: true,
            ));
    await Diag.guard('notifications-init', NotificationService.init);
    await Diag.guard('notification-permissions', () async {
      await NotificationService.requestPermissions();
      await NotificationService.requestNotificationsOnly();
    });
    await Diag.guard(
        'notification-launch', NotificationService.handleAppLaunchDetails);
    await Diag.guard('schedule', () => NotificationService.ensureScheduled());
    await Diag.guard(
        'adhan-auto-download', AdhanAudio.ensureSelectedDownloaded);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Diag.guard(
          'resume-schedule', () => NotificationService.ensureScheduled());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.i,
      builder: (context, _) {
        final s = Settings.i;
        return MaterialApp(
          navigatorKey: sakinaNavigatorKey,
          title: 'سَكِينَة',
          debugShowCheckedModeBanner: false,
          locale: Locale(s.language, s.language == 'ar' ? 'EG' : 'US'),
          supportedLocales: const [
            Locale('ar', 'EG'),
            Locale('ar'),
            Locale('en', 'US'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: const [
            ThemeMode.system,
            ThemeMode.light,
            ThemeMode.dark
          ][s.themeMode.clamp(0, 2)],
          theme: buildTheme(Brightness.light, s.accent, s.font),
          darkTheme: buildTheme(Brightness.dark, s.accent, s.font),
          builder: (context, child) => Directionality(
            textDirection: s.isEnglish ? TextDirection.ltr : TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(s.fontScale)),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: CloudService.enabled ? const CloudGate() : const Shell(),
        );
      },
    );
  }
}

class BlockGate extends StatelessWidget {
  const BlockGate({super.key});
  @override Widget build(BuildContext context) => FutureBuilder<bool>(
    future: CloudService.isBlocked(),
    builder: (context, snap) {
      if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snap.data == true) return Scaffold(appBar: AppBar(title: const Text('الحساب محظور')),body: const Center(child: Padding(padding: EdgeInsets.all(28),child: Text('تم حظر هذا الحساب من قبل مالك SAKINA. تواصل مع المالك إذا كنت تعتقد أن هذا حدث بالخطأ.',textAlign: TextAlign.center,style: TextStyle(fontSize: 16,height: 1.8)))));
      return const Shell();
    },
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  bool onboardingDone = Store.flag('onboardingComplete');
  late Future<Map<String, dynamic>?> _announcementFuture;

  @override
  void initState() {
    super.initState();
    _announcementFuture = CloudService.latestMessage();
  }

  Future<void> _openAnnouncement(Map<String, dynamic> message) async {
    final id = message['id']?.toString();
    if (id != null) await CloudService.markMessageRead(id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MessagesPage()),
    );
    if (mounted) setState(() => _announcementFuture = CloudService.latestMessage());
  }

  Widget _announcementBanner(Map<String, dynamic> message) {
    final cs = Theme.of(context).colorScheme;
    final title = '${message['title'] ?? 'إعلان من سَكِينَة'}'.trim();
    final body = '${message['body'] ?? ''}'.trim();
    return Material(
      color: Color.alphaBlend(cs.primary.withAlpha(22), cs.surface),
      child: InkWell(
        onTap: () => _openAnnouncement(message),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            Icon(Icons.campaign_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (body.isNotEmpty)
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: cs.onSurface.withAlpha(180))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left_rounded, color: cs.primary),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Settings.i;
    if (!onboardingDone) {
      return OnboardingPage(onComplete: () {
        if (mounted) setState(() => onboardingDone = true);
      });
    }
    const pages = <Widget>[
      HomePage(),
      PrayerPage(),
      QuranGamePage(),
      QuranPage(),
      AzkarPage(),
      MorePage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          FutureBuilder<bool>(
            future: CloudService.isOwner(),
            builder: (context, access) {
              if (access.data != true) return const SizedBox.shrink();
              return ListenableBuilder(
                listenable: Diag.i,
                builder: (context, _) {
                  if (Diag.i.errors.isEmpty) return const SizedBox.shrink();
                  return Material(
                    color: const Color(0x33FF9800),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const DiagnosticsPage())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'يوجد ${Diag.i.errors.length} تنبيهات تشخيصية (للمالك)',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: _announcementFuture,
            builder: (context, announcement) {
              final message = announcement.data;
              return message == null
                  ? const SizedBox.shrink()
                  : _announcementBanner(message);
            },
          ),
          Expanded(child: IndexedStack(index: index, children: pages)),
        ]),
      ),
      bottomNavigationBar: SakinaNavBar(
        index: index,
        centerIndex: 2,
        onTap: (i) => setState(() => index = i),
        items: [
          SakinaNavItem(s.isEnglish ? 'Home' : 'الرئيسية', Icons.home_outlined,
              Icons.home_rounded),
          SakinaNavItem(s.isEnglish ? 'Prayer' : 'الصلاة',
              Icons.access_time_rounded, Icons.access_time_filled_rounded),
          SakinaNavItem(s.isEnglish ? 'Game' : 'اللعبة',
              Icons.sports_esports_outlined, Icons.sports_esports_rounded),
          SakinaNavItem(s.isEnglish ? 'Quran' : 'القرآن',
              Icons.menu_book_outlined, Icons.menu_book_rounded),
          SakinaNavItem(s.isEnglish ? 'Adhkar' : 'الأذكار',
              Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
          SakinaNavItem(s.isEnglish ? 'Tools' : 'المزيد',
              Icons.grid_view_outlined, Icons.grid_view_rounded),
        ],
      ),
    );
  }
}

class CloudGate extends StatelessWidget {
  const CloudGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: CloudService.client.auth.onAuthStateChange,
      builder: (context, snap) {
        if (CloudService.user != null) return const BlockGate();
        return const AuthPage();
      },
    );
  }
}
