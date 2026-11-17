import 'package:flutter/material.dart';

import '../cloud/cloud_service.dart';
import '../core/widgets.dart';
import '../services/update_service.dart';

class AdminUpdateManagementPanel extends StatefulWidget {
  const AdminUpdateManagementPanel({super.key});

  @override
  State<AdminUpdateManagementPanel> createState() =>
      _AdminUpdateManagementPanelState();
}

class _AdminUpdateManagementPanelState extends State<AdminUpdateManagementPanel> {
  final _version = TextEditingController(text: '4.9.2');
  final _build = TextEditingController(text: '19');
  final _minimum = TextEditingController();
  final _apk = TextEditingController(
    text: 'https://github.com/mohamedhosney415-creator/SAKINA-CLOUD/releases/latest/download/app-release.apk',
  );
  final _notes = TextEditingController();
  Map<String, dynamic> settings = {};
  List<Map<String, dynamic>> installs = [];
  List<Map<String, dynamic>> profiles = [];
  int get unreportedCount {
    final ids = installs.map((row) => row['user_id']?.toString()).toSet();
    return profiles.where((profile) => !ids.contains(profile['id']?.toString())).length;
  }
  bool loading = true;
  bool busy = false;
  String? error;
  int get outdatedCount => _oldRows.length;

  List<Map<String, dynamic>> get _oldRows => installs.where((row) {
        return UpdateService.isOlder(
          row['app_version']?.toString() ?? '0',
          int.tryParse(row['build_number']?.toString() ?? '0') ?? 0,
          settings['latest_version']?.toString() ?? _version.text,
          int.tryParse(settings['latest_build']?.toString() ?? _build.text) ?? 0,
        );
      }).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _version.dispose();
    _build.dispose();
    _minimum.dispose();
    _apk.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        CloudService.appUpdateSettings(),
        CloudService.adminAppInstalls(),
        CloudService.adminUsers(),
      ]);
      final remote = Map<String, dynamic>.from((values[0] as Map?) ?? {});
      final rows = List<Map<String, dynamic>>.from(values[1] as List);
      final accounts = List<Map<String, dynamic>>.from(values[2] as List);
      _version.text = remote['latest_version']?.toString() ?? '4.9.2';
      _build.text = remote['latest_build']?.toString() ?? '19';
      _minimum.text = remote['minimum_version']?.toString() ?? '';
      _apk.text = remote['apk_url']?.toString() ?? _apk.text;
      _notes.text = remote['notes']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        settings = remote;
        installs = rows;
        profiles = accounts;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'تعذر تحميل بيانات تحديثات التطبيق.';
        });
      }
    }
  }

  Future<void> _checkVersions() async {
    setState(() => busy = true);
    try {
      final rows = await CloudService.adminAppInstalls();
      if (!mounted) return;
      setState(() {
        installs = rows;
        busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم فحص ' + rows.length.toString() + ' حسابًا؛ ' +
                outdatedCount.toString() + ' على إصدار أقدم.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فحص الإصدارات.')),
        );
      }
    }
  }

  Future<void> _save({
    bool? showUpdate,
    bool? autoCheck,
    bool? mandatory,
  }) async {
    setState(() => busy = true);
    try {
      final version = _version.text.trim();
      final build = int.tryParse(_build.text.trim());
      final url = _apk.text.trim();
      if (version.isEmpty || build == null || build < 0 ||
          Uri.tryParse(url)?.hasScheme != true) {
        throw const FormatException('تحقق من رقم الإصدار والبناء ورابط APK.');
      }
      final forceUpdate = mandatory ?? (settings['mandatory'] == true);
      if (forceUpdate && _minimum.text.trim().isEmpty) {
        _minimum.text = version + '+' + build.toString();
      }
      if (!forceUpdate) _minimum.clear();
      final values = <String, dynamic>{
        'latest_version': version,
        'latest_build': build,
        'apk_url': url,
        'minimum_version':
            forceUpdate ? _minimum.text.trim() : null,
        'notes': _notes.text.trim(),
        'show_update': showUpdate ?? (settings['show_update'] == true),
        'auto_check': autoCheck ?? (settings['auto_check'] != false),
        'mandatory': forceUpdate,
      };
      await CloudService.saveAppUpdateSettings(values);
      if (!mounted) return;
      setState(() {
        settings = values;
        busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات التحديث.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: ' + e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Panel(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error!),
            TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إدارة تحديثات التطبيق',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'حسابات أرسلت إصدارها: ' + installs.length.toString() +
                ' • قديمة: ' + outdatedCount.toString() +
                ' • لم ترسل بعد: ' + unreportedCount.toString(),
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _version,
            decoration: const InputDecoration(labelText: 'أحدث إصدار'),
          ),
          TextField(
            controller: _build,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'رقم البناء Build'),
          ),
          TextField(
            controller: _apk,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رابط ملف APK'),
          ),
          TextField(
            enabled: settings['mandatory'] == true,
            controller: _minimum,
            decoration: const InputDecoration(labelText: 'أقل إصدار مسموح به (مثال 4.9.2+19)'),
          ),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظات التحديث'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : () => _save(),
              child: const Text('حفظ بيانات الإصدار'),
            ),
          ),
          const Divider(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : _checkVersions,
              icon: const Icon(Icons.manage_search_rounded),
              label: Text(busy ? 'جارٍ الفحص...' : 'فحص إصدارات المستخدمين'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => _save(showUpdate: true, autoCheck: true),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('إظهار التحديث للمستخدمين'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('فحص تلقائي عند فتح التطبيق'),
            subtitle: const Text('يعرض التحديث عند توفر إصدار أحدث.'),
            value: settings['auto_check'] != false,
            onChanged: busy ? null : (value) => _save(autoCheck: value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إجبار المستخدمين على التحديث'),
            subtitle: const Text('يمنع تخطي شاشة التحديث للإصدارات الأقل من الحد الأدنى.'),
            value: settings['mandatory'] == true,
            onChanged: busy ? null : (value) => _save(mandatory: value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إظهار إشعار التحديث للمستخدمين'),
            value: settings['show_update'] == true,
            onChanged: busy ? null : (value) => _save(showUpdate: value),
          ),
          if (_oldRows.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'حسابات على إصدار قديم (' + _oldRows.length.toString() + ')',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final row in _oldRows.take(15))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.system_update_alt_rounded),
                title: Text(
                  'حساب ' + (row['user_id']?.toString() ?? '').substring(0, 8),
                ),
                subtitle: Text(
                  'الإصدار ' + (row['app_version']?.toString() ?? '-') +
                      '+' + (row['build_number']?.toString() ?? '0'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
