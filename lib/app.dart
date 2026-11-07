import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/diag.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'features/azkar_page.dart';
import 'features/diagnostics_page.dart';
import 'features/home_page.dart';
import 'features/more_page.dart';
import 'features/prayer_page.dart';
import 'features/quran_page.dart';
import 'services/notification_service.dart';
import 'cloud/cloud_service.dart';
import 'features/auth_page.dart';
import 'features/account_page.dart';
import 'features/onboarding_page.dart';

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
    await Diag.guard('audio-background', () => JustAudioBackground.init(
          androidNotificationChannelId: 'com.hosny.sakina.audio',
          androidNotificationChannelName: 'تشغيل القرآن',
          androidNotificationOngoing: true,
        ));
    await Diag.guard('notifications-init', NotificationService.init);
    await Diag.guard('notification-launch', NotificationService.handleAppLaunchDetails);
    if (!Store.flag('permAsked')) {
      await Store.setFlag('permAsked', true);
      await Diag.guard('notification-permission',
          NotificationService.requestNotificationsOnly);
    }
    await Diag.guard('schedule', () => NotificationService.ensureScheduled());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Diag.guard('resume-schedule', () => NotificationService.ensureScheduled());
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
          title: 'سكينة',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: const [
            ThemeMode.system, ThemeMode.light, ThemeMode.dark
          ][s.themeMode.clamp(0, 2)],
          theme: buildTheme(Brightness.light, s.accent, s.font),
          darkTheme: buildTheme(Brightness.dark, s.accent, s.font),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
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

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  bool onboardingDone = Store.flag('onboardingComplete');

  @override
  Widget build(BuildContext context) {
    if (!onboardingDone) {
      return OnboardingPage(onComplete: () {
        if (mounted) setState(() => onboardingDone = true);
      });
    }
    const pages = <Widget>[
      HomePage(),
      PrayerPage(),
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
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DiagnosticsPage())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('يوجد ${Diag.i.errors.length} تنبيهات تشخيصية (للمالك)',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Expanded(child: IndexedStack(index: index, children: pages)),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.access_time),
              selectedIcon: Icon(Icons.access_time_filled),
              label: 'الصلاة'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'القرآن'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'الأذكار'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'المزيد'),
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
        if (CloudService.user != null) return const Shell();
        return const AuthPage();
      },
    );
  }
}
