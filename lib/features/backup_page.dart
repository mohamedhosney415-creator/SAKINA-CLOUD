import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/widgets.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool busy = false;
  bool autoBackup = BackupService.autoBackupEnabled;

  Future<void> _export() async {
    setState(() => busy = true);
    try {
      await BackupService.share();
    } catch (_) {
      if (mounted) toast(context, 'تعذر إنشاء النسخة الاحتياطية');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _import() async {
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.any, withData: true);
      if (res == null || res.files.isEmpty) return;
      final bytes = res.files.first.bytes;
      if (bytes == null) throw const FormatException('empty');
      BackupService.validate(utf8.decode(bytes));
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('استعادة النسخة'),
          content: const Text(
              'سيتم استبدال بيانات التطبيق الحالية (الإعدادات والمفضلة والسجلات) ببيانات النسخة. هل تريد المتابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('استعادة')),
          ],
        ),
      );
      if (ok != true) return;
      setState(() => busy = true);
      await BackupService.restore(utf8.decode(bytes));
      await NotificationService.ensureScheduled(force: true);
      if (mounted) toast(context, 'تمت الاستعادة بنجاح');
    } catch (_) {
      if (mounted) toast(context, 'الملف غير صالح أو ليس نسخة من سكينة');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          color: Theme.of(context).colorScheme.primary.withAlpha(18),
          child: Row(children: [
            const Icon(Icons.history_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                BackupService.lastAutoBackup == null
                    ? 'لم يتم إنشاء نسخة تلقائية بعد'
                    : 'آخر نسخة تلقائية: ${BackupService.lastAutoBackup!.day}/${BackupService.lastAutoBackup!.month}/${BackupService.lastAutoBackup!.year}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const Panel(
          child: Text(
              'تشمل النسخة: المفضلة، تقدّم القرآن والختمة، علامات وملاحظات الآيات، الأذكار والتسبيح ومجموعاتك، سجل الصلوات، وقوائم الصوت والإعدادات.\n\n'
              'عند تغيير الهاتف: ثبّت سكينة ثم استعد الملف من هنا. الصوتيات المحمّلة تُحمَّل من جديد.',
              style: TextStyle(height: 1.8)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : _export,
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('تصدير نسخة احتياطية'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : _import,
          icon: const Icon(Icons.restore),
          label: const Text('استعادة من ملف'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('نسخ تلقائي محلي'),
          subtitle: const Text(
              'يحفظ ملف JSON في مساحة التطبيق الخاصة مرة يوميًا، دون رفعه للسحابة. ليس مشفرًا.'),
          value: autoBackup,
          onChanged: busy
              ? null
              : (value) async {
                  setState(() => busy = true);
                  try {
                    await BackupService.setAutoBackup(value);
                    if (mounted) setState(() => autoBackup = value);
                  } catch (_) {
                    if (mounted) toast(context, 'تعذر إعداد النسخ المحلي');
                  }
                  if (mounted) setState(() => busy = false);
                },
        ),
        if (busy)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
