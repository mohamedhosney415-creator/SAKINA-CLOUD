import '../core/format.dart';
import '../core/store.dart';
import '../data/surahs.dart';

/// Offline-first khatma plans. Legacy single-plan fields remain readable/writable.
class KhatmaStore {
  static const _plansKey = 'khatma_plans_v2';
  static const _activeKey = 'khatma_active_v2';

  static List<Map<String, dynamic>> plans() {
    final raw = Store.json(_plansKey);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final legacy = Store.json('khatma');
    if (legacy is Map) {
      final p = _normalize(Map<String, dynamic>.from(legacy), legacyId: true);
      // Persist the upgraded representation without removing the original key.
      Store.setJson(_plansKey, [p]);
      Store.setStr(_activeKey, p['id'] as String);
      return [p];
    }
    return [];
  }

  static Map<String, dynamic>? plan() {
    final all = plans();
    if (all.isEmpty) return null;
    final id = Store.str(_activeKey);
    for (final p in all) {
      if (p['id'] == id) return p;
    }
    return all.first;
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> p,
      {bool legacyId = false}) {
    final start = _parseDate(p['start']) ?? onlyDate(DateTime.now());
    final end = _parseDate(p['end']) ??
        start.add(Duration(days: ((p['days'] as num?)?.toInt() ?? 30) - 1));
    final duration = (daysBetween(start, end) + 1).clamp(1, 3650);
    return {
      ...p,
      'id': (p['id'] as String?) ??
          (legacyId
              ? 'legacy-khatma'
              : 'khatma-${DateTime.now().microsecondsSinceEpoch}'),
      'name': (p['name'] as String?)?.trim().isNotEmpty == true
          ? p['name']
          : 'ختمة',
      'type': _validType(p['type'] as String? ?? 'ordinary'),
      'start': dayKey(start),
      'end': dayKey(start.add(Duration(days: duration - 1))),
      'days': duration,
      'log': p['log'] is Map
          ? Map<String, dynamic>.from(p['log'] as Map)
          : <String, dynamic>{},
    };
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]),
        m = int.tryParse(parts[1]),
        d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  static String _validType(String type) =>
      const {'ordinary', 'memorization', 'ramadan'}.contains(type)
          ? type
          : 'ordinary';

  static Future<void> _save(List<Map<String, dynamic>> all) async {
    await Store.setJson(_plansKey, all);
    final active = planFrom(all, Store.str(_activeKey));
    if (active == null) {
      await Store.remove('khatma');
      await Store.remove(_activeKey);
    } else {
      await Store.setStr(_activeKey, active['id'] as String);
      // Keep legacy consumers and backup readers aligned to the selected plan.
      await Store.setJson('khatma', active);
    }
  }

  static Map<String, dynamic>? planFrom(
      List<Map<String, dynamic>> all, String id) {
    for (final p in all) {
      if (p['id'] == id) return p;
    }
    return all.isEmpty ? null : all.first;
  }

  static Future<void> select(String id) async {
    final all = plans();
    if (!all.any((p) => p['id'] == id)) return;
    await Store.setStr(_activeKey, id);
    await Store.setJson('khatma', all.firstWhere((p) => p['id'] == id));
  }

  static int completed() => Store.integer('khatma_done', 0);

  static Future<void> create(int days,
      {String name = 'ختمة جديدة',
      String type = 'ordinary',
      DateTime? start,
      DateTime? end}) async {
    final from = onlyDate(start ?? DateTime.now());
    final to =
        onlyDate(end ?? from.add(Duration(days: days.clamp(1, 3650) - 1)));
    if (to.isBefore(from))
      throw ArgumentError('End date must not precede start date');
    final normalized = _normalize({
      'id': 'khatma-${DateTime.now().microsecondsSinceEpoch}',
      'name': name.trim().isEmpty ? 'ختمة جديدة' : name.trim(),
      'type': _validType(type),
      'start': dayKey(from),
      'end': dayKey(to),
      'days': daysBetween(from, to) + 1,
      'log': <String, dynamic>{},
    });
    final all = plans()..add(normalized);
    await Store.setStr(_activeKey, normalized['id'] as String);
    await _save(all);
  }

  static Future<void> cancel() async {
    final active = plan();
    if (active == null) return;
    final all = plans()..removeWhere((p) => p['id'] == active['id']);
    if (all.isNotEmpty)
      await Store.setStr(_activeKey, all.first['id'] as String);
    await _save(all);
  }

  static Future<void> finish() async {
    final active = plan();
    if (active == null) return;
    await Store.setInt('khatma_done', completed() + 1);
    await cancel();
  }

  static DateTime startOf(Map<String, dynamic> p) =>
      _parseDate(p['start']) ?? DateTime.now();
  static DateTime endOf(Map<String, dynamic> p) =>
      _parseDate(p['end']) ?? startOf(p).add(Duration(days: daysOf(p) - 1));
  static int daysOf(Map<String, dynamic> p) =>
      (p['days'] as num?)?.toInt() ?? daysBetween(startOf(p), endOf(p)) + 1;
  static Map<String, dynamic> _log(Map<String, dynamic> p) =>
      p['log'] is Map ? Map<String, dynamic>.from(p['log'] as Map) : {};
  static int pagesRead(Map<String, dynamic> p) => _log(p)
      .values
      .fold<int>(0,
          (t, v) => t + (v is num ? v.toInt().clamp(0, totalMushafPages) : 0))
      .clamp(0, totalMushafPages);
  static int readOn(Map<String, dynamic> p, DateTime d) =>
      ((_log(p)[dayKey(d)] as num?)?.toInt() ?? 0);
  static int daysLeft(Map<String, dynamic> p, DateTime today) =>
      (daysBetween(onlyDate(today), endOf(p)) + 1).clamp(1, 100000);
  static int remainingPages(Map<String, dynamic> p) =>
      (totalMushafPages - pagesRead(p)).clamp(0, totalMushafPages);
  static int overduePages(Map<String, dynamic> p, DateTime today) =>
      (expectedPagesByNow(p, today) - pagesRead(p)).clamp(0, totalMushafPages);
  static int catchUpPagesPerDay(Map<String, dynamic> p, DateTime today) =>
      (remainingPages(p) / daysLeft(p, today)).ceil();
  static int wirdToday(Map<String, dynamic> p, DateTime today) =>
      catchUpPagesPerDay(p, today);

  static Future<void> addPages(int delta, DateTime today) async {
    final active = plan();
    if (active == null) return;
    final log = _log(active), key = dayKey(today);
    final current = (log[key] as num?)?.toInt() ?? 0;
    final others = pagesRead(active) - current;
    log[key] = (current + delta).clamp(0, totalMushafPages - others);
    active['log'] = log;
    await _replace(active);
  }

  static Future<void> _replace(Map<String, dynamic> item) async {
    final all = plans();
    final index = all.indexWhere((p) => p['id'] == item['id']);
    if (index < 0) return;
    all[index] = item;
    await _save(all);
  }

  static int expectedPagesByNow(Map<String, dynamic> p, DateTime today) {
    final totalDays = daysOf(p);
    final elapsed =
        (daysBetween(startOf(p), onlyDate(today)) + 1).clamp(0, totalDays);
    return (totalMushafPages * elapsed / totalDays).ceil();
  }
}
