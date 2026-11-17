import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SakinaUpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String apkUrl;
  final String? minimumVersion;
  final int? minimumBuildNumber;
  final String? notes;

  const SakinaUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.apkUrl,
    this.minimumVersion,
    this.minimumBuildNumber,
    this.notes,
  });
}

class UpdateService {
  static const manifestUrl =
      'https://raw.githubusercontent.com/mohamedhosney415-creator/SAKINA-CLOUD/main/update.json';

  static Future<SakinaUpdateInfo?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final response = await http
          .get(Uri.parse(manifestUrl), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final version = data['latestVersion']?.toString() ?? '';
      final apkUrl = data['apkUrl']?.toString() ?? '';
      if (version.isEmpty || Uri.tryParse(apkUrl)?.hasAbsolutePath != true) {
        return null;
      }
      return SakinaUpdateInfo(
        latestVersion: version,
        latestBuildNumber:
            int.tryParse(data['latestBuildNumber']?.toString() ?? '') ?? 0,
        apkUrl: apkUrl,
        minimumVersion: data['minimumVersion']?.toString(),
        minimumBuildNumber:
            int.tryParse(data['minimumBuildNumber']?.toString() ?? ''),
        notes: data['notes']?.toString(),
      );
    } catch (_) {
      return null;
    }
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
    final length = aa.length > bb.length ? aa.length : bb.length;
    for (var i = 0; i < length; i++) {
      final x = i < aa.length ? aa[i] : 0;
      final y = i < bb.length ? bb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static bool isOutdatedInstall(
    String? installedVersion,
    int? installedBuild,
    SakinaUpdateInfo latest,
  ) {
    if (installedVersion == null || installedVersion.trim().isEmpty) {
      return false;
    }
    final versionComparison = _compare(installedVersion, latest.latestVersion);
    if (versionComparison != 0) return versionComparison < 0;
    return (installedBuild ?? 0) < latest.latestBuildNumber;
  }

  static Future<bool> shouldUpdate(SakinaUpdateInfo info) async {
    final package = await PackageInfo.fromPlatform();
    return isOutdatedInstall(
      package.version,
      int.tryParse(package.buildNumber) ?? 0,
      info,
    );
  }

  static Future<bool> isMandatory(SakinaUpdateInfo info) async {
    final package = await PackageInfo.fromPlatform();
    final minimum = info.minimumVersion;
    if (minimum == null || minimum.trim().isEmpty) return false;
    final comparison = _compare(package.version, minimum);
    if (comparison != 0) return comparison < 0;
    final minimumBuild = info.minimumBuildNumber;
    return minimumBuild != null &&
        (int.tryParse(package.buildNumber) ?? 0) < minimumBuild;
  }

  static Future<void> showIfNeeded(BuildContext context) async {
    final info = await check();
    if (info == null || !await shouldUpdate(info) || !context.mounted) return;
    final mandatory = await isMandatory(info);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تحديث جديد لـ سَكِينَة'),
        content: Text([
          'الإصدار الجديد: ' +
              info.latestVersion +
              '+' +
              info.latestBuildNumber.toString(),
          if ((info.notes ?? '').trim().isNotEmpty) '',
          if ((info.notes ?? '').trim().isNotEmpty) info.notes!,
          if (mandatory) '',
          if (mandatory) 'هذا التحديث مطلوب للاستمرار.',
          'بعد تنزيل الملف، افتحه واضغط «تثبيت» لإكمال التحديث.',
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
                Uri.parse(info.apkUrl),
                mode: LaunchMode.externalApplication,
              );
              if (dialogContext.mounted && !opened) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تعذر فتح رابط التحديث.')),
                );
              } else if (dialogContext.mounted && opened) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('تنزيل التحديث'),
          ),
        ],
      ),
    );
  }
}
