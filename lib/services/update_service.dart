import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/cloud_service.dart';

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
      return SakinaUpdateInfo(
        latestVersion: (data['latestVersion'] ?? '').toString(),
        latestBuild: int.tryParse('${data['latestBuild'] ?? 0}') ?? 0,
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
    final mandatory = info.mandatory && (belowMinimum || outdated);
    if (!mandatory && (!info.autoCheck || !info.showUpdate)) return;

    final uri = Uri.tryParse(info.apkUrl);
    if (uri == null || !uri.hasScheme) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) => PopScope(
        canPop: !mandatory,
        child: AlertDialog(
          title: const Text('تحديث جديد لسَكِينَة'),
          content: Text([
            'الإصدار الجديد: ${info.latestVersion}+${info.latestBuild}',
            if ((info.notes ?? '').trim().isNotEmpty) '',
            if ((info.notes ?? '').trim().isNotEmpty) info.notes!,
            if (mandatory) '',
            if (mandatory) 'هذا التحديث إجباري للاستمرار في استخدام التطبيق.',
          ].join('\n')),
          actions: [
            if (!mandatory)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('لاحقًا'),
              ),
            FilledButton(
              onPressed: () async {
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر فتح رابط التحديث.')),
                  );
                }
              },
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
