import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SakinaUpdateInfo {
  final String latestVersion;
  final String apkUrl;
  final String? minimumVersion;
  final String? notes;
  const SakinaUpdateInfo({required this.latestVersion, required this.apkUrl, this.minimumVersion, this.notes});
}

class UpdateService {
  static const manifestUrl = 'https://sakina-2yy.pages.dev/update.json';
  static Future<SakinaUpdateInfo?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final r = await http.get(Uri.parse(manifestUrl)).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return SakinaUpdateInfo(latestVersion: '\${data['latestVersion'] ?? ''}', apkUrl: '\${data['apkUrl'] ?? ''}', minimumVersion: data['minimumVersion']?.toString(), notes: data['notes']?.toString());
    } catch (_) { return null; }
  }
  static Future<bool> shouldUpdate(SakinaUpdateInfo info) async { final p = await PackageInfo.fromPlatform(); return _compare(p.version, info.latestVersion) < 0; }
  static Future<bool> isMandatory(SakinaUpdateInfo info) async { final p = await PackageInfo.fromPlatform(); final min = info.minimumVersion; return min != null && min.trim().isNotEmpty && _compare(p.version, min) < 0; }
  static int _compare(String a, String b) {
    final aa = a.split(RegExp(r'[^0-9]+')).where((x) => x.isNotEmpty).map(int.parse).toList();
    final bb = b.split(RegExp(r'[^0-9]+')).where((x) => x.isNotEmpty).map(int.parse).toList();
    final n = aa.length > bb.length ? aa.length : bb.length;
    for (var i = 0; i < n; i++) { final x = i < aa.length ? aa[i] : 0; final y = i < bb.length ? bb[i] : 0; if (x != y) return x.compareTo(y); }
    return 0;
  }
  static Future<void> showIfNeeded(BuildContext context) async {
    final info = await check();
    if (info == null || !await shouldUpdate(info) || !context.mounted) return;
    final mandatory = await isMandatory(info);
    await showDialog<void>(context: context, barrierDismissible: !mandatory, builder: (_) => AlertDialog(
      title: const Text('تحديث جديد لـ SAKINA'),
      content: Text(['الإصدار الجديد: \${info.latestVersion}', if ((info.notes ?? '').trim().isNotEmpty) '', if ((info.notes ?? '').trim().isNotEmpty) info.notes!, if (mandatory) '', if (mandatory) 'هذا التحديث مطلوب للاستمرار.'].join('\n')),
      actions: [if (!mandatory) TextButton(onPressed: () => Navigator.pop(context), child: const Text('لاحقًا')), FilledButton(onPressed: () async { final ok = await launchUrl(Uri.parse(info.apkUrl), mode: LaunchMode.externalApplication); if (context.mounted && !ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط التحديث.'))); }, child: const Text('تحديث الآن'))],
    ));
  }
}