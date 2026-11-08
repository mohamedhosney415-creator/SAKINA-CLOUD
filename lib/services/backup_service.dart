import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import 'favorites.dart';
import 'prayer_service.dart';

/// نسخ محلية قابلة للنقل: البيانات الأساسية مخزنة في JSON فقط.
class BackupService {
  static const format = 2;
  static const _autoBackupKey = 'backup_auto_local';
  static const _lastAutoBackupKey = 'backup_auto_local_at';
  static bool get autoBackupEnabled => Store.flag(_autoBackupKey);

  static String buildJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'SAKINA',
        'format': format,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'data': Store.exportAll(),
      });

  static Future<Directory> _backupDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/sakina_backups');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _writeLocalBackup() async {
    final dir = await _backupDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/sakina_backup_$stamp.json');
    await file.writeAsString(buildJson(), flush: true);
    final backups = dir
        .listSync()
        .whereType<File>()
        .where((item) => item.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final old in backups.skip(7)) {
      await old.delete();
    }
    return file;
  }

  static Future<void> setAutoBackup(bool enabled) async {
    await Store.setFlag(_autoBackupKey, enabled);
    if (enabled) {
      await createLocalBackup();
      await Store.setInt(
          _lastAutoBackupKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// ينشئ نسخة خاصة بالتطبيق في مجلد مستنداته؛ لا تُرفع ولا تُشارك تلقائياً.
  static Future<void> createLocalBackup() => _writeLocalBackup();

  /// Called once on app startup; creates at most one automatic backup per day.
  static Future<void> ensureDailyAutoBackup() async {
    if (!autoBackupEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = Store.integer(_lastAutoBackupKey);
    if (last > 0 && now - last < const Duration(hours: 24).inMilliseconds)
      return;
    await _writeLocalBackup();
    await Store.setInt(_lastAutoBackupKey, now);
  }

  static Future<File> exportFile() async {
    if (autoBackupEnabled) await _writeLocalBackup();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/sakina_backup_${dayKey(DateTime.now())}.json');
    await f.writeAsString(buildJson(), flush: true);
    return f;
  }

  static Future<void> share() async {
    final f = await exportFile();
    await Share.shareXFiles([XFile(f.path)],
        text: 'النسخة الاحتياطية لتطبيق سكينة');
  }

  /// يرفض الإصدارات المستقبلية والبيانات غير المتوافقة قبل لمس التخزين المحلي.
  static Map<String, dynamic> validate(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['app'] != 'SAKINA' ||
        decoded['data'] is! Map) {
      throw const FormatException('ملف غير صالح');
    }
    final version = decoded['format'];
    // صيغة الإصدار 1 مقبولة للتوافق مع النسخ القديمة.
    if (version is! int || (version != 1 && version != format)) {
      throw const FormatException('إصدار النسخة غير مدعوم');
    }
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    for (final entry in data.entries) {
      final value = entry.value;
      if (entry.key.isEmpty ||
          !(value is String ||
              value is bool ||
              value is int ||
              value is double ||
              value is List)) {
        throw const FormatException('محتوى النسخة غير صالح');
      }
      if (value is List && value.any((item) => item is! String)) {
        throw const FormatException('قائمة بيانات غير صالحة');
      }
    }
    return data;
  }

  static Future<int> restore(String raw) async {
    final data = validate(raw); // تحقق كامل قبل تغيير أي قيمة.
    await Store.importAll(data);
    await Store.remove('sched_key');
    Settings.i.load();
    Favorites.i.load();
    PrayerService.clearCache();
    if (autoBackupEnabled) await _writeLocalBackup();
    return data.length;
  }
}
