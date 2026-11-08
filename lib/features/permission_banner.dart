import 'package:flutter/material.dart';
import '../core/widgets.dart';
import '../services/notification_service.dart';
import 'adhan_settings_page.dart';

/// ينبّه المستخدم إذا كانت أذونات الإشعارات أو المنبهات الدقيقة ناقصة (تمنع الأذان).
class PermissionBanner extends StatefulWidget {
  const PermissionBanner({super.key});
  @override
  State<PermissionBanner> createState() => _PermissionBannerState();
}

class _PermissionBannerState extends State<PermissionBanner> with WidgetsBindingObserver {
  bool notifOk = true, exactOk = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    try {
      final n = await NotificationService.notificationsAllowed();
      final e = await NotificationService.exactAllowed();
      if (mounted) setState(() { notifOk = n; exactOk = e; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (notifOk && exactOk) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Panel(
        color: Colors.orange.withAlpha(38),
        onTap: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AdhanSettingsPage()));
          _check();
        },
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                !notifOk
                    ? 'الإشعارات متوقفة، لن يعمل الأذان. اضغط للإصلاح.'
                    : 'فعّل «المنبهات الدقيقة» ليعمل الأذان في موعده بالضبط. اضغط للإصلاح.',
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
          ),
          const Icon(Icons.chevron_left),
        ]),
      ),
    );
  }
}
