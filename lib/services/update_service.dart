import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/cloud_service.dart';
import 'backup_service.dart';
import '../features/auth_page.dart';

class SakinaUpdateInfo {
  final String latestVersion;
  final int latestBuild;
  final String apkUrl;
  final String? minimumVersion;
  final String? notes;
  final bool showUpdate;
  final bool autoCheck;
  final bool mandatory;

  const SakinaUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.apkUrl,
    this.minimumVersion,
    this.notes,
    this.showUpdate = true,
    this.autoCheck = true,
    this.mandatory = false,
  });
}

class UpdateService {
  static const manifestUrl = 'https://sakina-2yy.pages.dev/update.json';

  static Future<void> reportInstall() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
        !CloudService.signedIn) return;
    try {
      final info = await PackageInfo.fromPlatform();
      await CloudService.recordAppInstall(
        version: info.version,
        buildNumber: int.tryParse(info.buildNumber) ?? 0,
      );
    } catch (_) {
      // Version reporting must never prevent the app from opening.
    }
  }

  static Future<SakinaUpdateInfo?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final settings = await CloudService.appUpdateSettings();
      if (settings != null) {
        return SakinaUpdateInfo(
          latestVersion: '${settings['latest_version'] ?? ''}',
          latestBuild: int.tryParse('${settings['latest_build'] ?? 0}') ?? 0,
          apkUrl: '${settings['apk_url'] ?? ''}',
          minimumVersion: settings['minimum_version']?.toString(),
          notes: settings['notes']?.toString(),
          showUpdate: settings['show_update'] == true,
          autoCheck: settings['auto_check'] != false,
          mandatory: settings['mandatory'] == true,
        );
      }
    } catch (_) {
      // Fall back to the public manifest if cloud settings are unavailable.
    }

    try {
      final response = await http
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final manifestVersion = (data['latestVersion'] ?? '').toString();
      final manifestParts = manifestVersion.split('+');
      final manifestBuild = data['latestBuild']?.toString() ??
          (manifestParts.length > 1 ? manifestParts.last : '0');
      return SakinaUpdateInfo(
        latestVersion: manifestParts.first,
        latestBuild: int.tryParse(manifestBuild) ?? 0,
        apkUrl: (data['apkUrl'] ?? '').toString(),
        minimumVersion: data['minimumVersion']?.toString(),
        notes: data['notes']?.toString(),
        showUpdate: data['showUpdate'] != false,
        autoCheck: data['autoCheck'] != false,
        mandatory: data['mandatory'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  static bool isOlder(
    String installedVersion,
    int installedBuild,
    String latestVersion,
    int latestBuild,
  ) {
    final versionResult = _compare(installedVersion, latestVersion);
    return versionResult < 0 ||
        (versionResult == 0 && installedBuild < latestBuild);
  }

  static int _compare(String a, String b) {
    final aa = a
        .split(RegExp(r'[^0-9]+'))
        .where((x) => x.isNotEmpty)
        .map(int.parse)
        .toList();
    final bb = b
        .split(RegExp(r'[^0-9]+'))
        .where((x) => x.isNotEmpty)
        .map(int.parse)
        .toList();
    final n = aa.length > bb.length ? aa.length : bb.length;
    for (var i = 0; i < n; i++) {
      final x = i < aa.length ? aa[i] : 0;
      final y = i < bb.length ? bb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static Future<void> showIfNeeded(BuildContext context) async {
    final info = await check();
    if (info == null || !context.mounted || info.apkUrl.trim().isEmpty) return;

    final package = await PackageInfo.fromPlatform();
    final outdated = isOlder(
      package.version,
      int.tryParse(package.buildNumber) ?? 0,
      info.latestVersion,
      info.latestBuild,
    );
    if (!outdated) return;

    final minimum = info.minimumVersion?.trim() ?? '';
    final belowMinimum =
        minimum.isNotEmpty && _compare(package.version, minimum) < 0;
    final mandatory = info.mandatory && (minimum.isEmpty || belowMinimum);
    if (!mandatory && (!info.autoCheck || !info.showUpdate)) return;

    final uri = Uri.tryParse(info.apkUrl);
    if (uri == null || !uri.hasScheme) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) {
        var busy = false;
        var backupDone = false;
        String? error;
        String? note;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !mandatory,
            child: AlertDialog(
              title: const Text('تحديث جديد لسَكِينَة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الإصدار الجديد: ${info.latestVersion}+${info.latestBuild}'),
                  if ((info.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(info.notes!),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    CloudService.enabled
                        ? 'لحماية بياناتك: سنحفظ نسخة من بيانات جهازك ونسخة من بيانات السحابة السابقة قبل اعتماد المزامنة. لن نتابع إذا لم نتأكد من نجاح الحفظ.'
                        : 'المزامنة السحابية غير مفعّلة في هذه النسخة؛ صدّر ملف النسخة الاحتياطية واحتفظ به لاستعادته يدويًا بعد التثبيت.',
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'بعد نجاح المزامنة: احذف النسخة القديمة ثم ثبّت الجديدة، وبعدها سجّل الدخول بنفس الحساب لاستعادة بياناتك.',
                    style: TextStyle(fontWeight: FontWeight.w700, height: 1.6),
                  ),
                  if (mandatory) ...[
                    const SizedBox(height: 8),
                    const Text('هذا التحديث إجباري للاستمرار في استخدام التطبيق.'),
                  ],
                  if (backupDone) ...[
                    const SizedBox(height: 10),
                    Text(
                      CloudService.enabled
                          ? 'تم حفظ النسخة الاحتياطية والتحقق منها. بياناتك السحابية جاهزة للاستعادة بعد التثبيت.'
                          : 'تم تصدير الملف. احتفظ به، ثم استعده يدويًا بعد تثبيت النسخة الجديدة.',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    Text(note!, style: const TextStyle(height: 1.5)),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                  ],
                  if (busy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    const Text('جارٍ حفظ البيانات والتحقق منها...'),
                  ],
                ],
              ),
              actions: [
                if (!mandatory)
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(dialogContext),
                    child: const Text('لاحقًا'),
                  ),
                if (CloudService.enabled && !CloudService.signedIn)
                  FilledButton(
                    onPressed: busy ? null : () {
                      Navigator.pop(dialogContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                      );
                    },
                    child: const Text('تسجيل الدخول أولًا'),
                  )
                else if (!CloudService.enabled)
                  OutlinedButton(
                    onPressed: busy ? null : () async {
                      setDialogState(() { busy = true; error = null; });
                      try {
                        await BackupService.share();
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          busy = false;
                          backupDone = true;
                          error = null;
                          note = 'بعد التثبيت، افتح النسخ الاحتياطي واختر استعادة من ملف.';
                        });
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          busy = false;
                          error = 'تعذر تصدير النسخة الاحتياطية؛ لن نبدأ التحديث حتى تحفظ بياناتك.';
                        });
                      }
                    },
                    child: const Text('تصدير نسخة احتياطية'),
                  ),
                if (CloudService.signedIn || !CloudService.enabled)
                  FilledButton(
                    onPressed: busy ? null : () async {
                      if (!backupDone) {
                        setDialogState(() { busy = true; error = null; });
                        try {
                          if (CloudService.enabled) {
                            await CloudService.prepareUpdateBackup();
                          } else {
                            // A manual export must be completed before proceeding without cloud.
                            setDialogState(() {
                              busy = false;
                              error = 'صدّر النسخة الاحتياطية أولًا ثم اضغط متابعة التحديث.';
                            });
                            return;
                          }
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            busy = false;
                            backupDone = true;
                            error = null;
                          });
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            busy = false;
                            error = 'فشلت المزامنة أو عملية التحقق. لم يتم بدء التحديث. حاول مرة أخرى. (${e.toString()})';
                          });
                        }
                        return;
                      }
                      final opened = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened && dialogContext.mounted) {
                        setDialogState(() => error = 'تم حفظ بياناتك، لكن تعذر فتح رابط التحديث.');
                      }
                    },
                    child: Text(backupDone ? 'متابعة إلى تنزيل التحديث' : 'مزامنة آمنة وحفظ بياناتي'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
