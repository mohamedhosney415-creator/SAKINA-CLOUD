import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين محلي بسيط. كل مفاتيح التطبيق تبدأ بـ "sk." لتُدرج في النسخ الاحتياطي.
/// إذا فشل التخزين الدائم لأي سبب نعمل مؤقتًا بالذاكرة كي لا يتعطل التطبيق.
class Store {
  static SharedPreferences? _prefs;
  static final Map<String, Object> _mem = {};
  static const prefix = 'sk.';
  static const _volatile = {'sched_key'};

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }
  }

  static String _k(String k) => '$prefix$k';

  static Object? _get(String k) =>
      _prefs != null ? _prefs!.get(_k(k)) : _mem[_k(k)];

  static Future<void> _put(String k, Object v) async {
    final key = _k(k);
    final p = _prefs;
    if (p == null) {
      _mem[key] = v;
      return;
    }
    if (v is String) {
      await p.setString(key, v);
    } else if (v is bool) {
      await p.setBool(key, v);
    } else if (v is int) {
      await p.setInt(key, v);
    } else if (v is double) {
      await p.setDouble(key, v);
    } else if (v is List) {
      await p.setStringList(key, v.map((x) => '$x').toList());
    }
  }

  static String str(String k, [String def = '']) {
    final v = _get(k);
    return v is String ? v : def;
  }

  static int integer(String k, [int def = 0]) {
    final v = _get(k);
    return v is int ? v : def;
  }

  static bool flag(String k, [bool def = false]) {
    final v = _get(k);
    return v is bool ? v : def;
  }

  static Future<void> setStr(String k, String v) => _put(k, v);
  static Future<void> setInt(String k, int v) => _put(k, v);
  static Future<void> setFlag(String k, bool v) => _put(k, v);

  static Future<void> remove(String k) async {
    if (_prefs != null) {
      await _prefs!.remove(_k(k));
    } else {
      _mem.remove(_k(k));
    }
  }

  static dynamic json(String k, [dynamic def]) {
    final s = _get(k);
    if (s is! String) return def;
    try {
      return jsonDecode(s);
    } catch (_) {
      return def;
    }
  }

  static Future<void> setJson(String k, dynamic v) => _put(k, jsonEncode(v));

  /// يُصدّر كل بيانات المستخدم (بدون الملفات المؤقتة).
  static Map<String, dynamic> exportAll() {
    final m = <String, dynamic>{};
    final keys = _prefs != null ? _prefs!.getKeys() : _mem.keys.toSet();
    for (final k in keys) {
      if (!k.startsWith(prefix)) continue;
      final name = k.substring(prefix.length);
      if (_volatile.contains(name)) continue;
      m[name] = _prefs != null ? _prefs!.get(k) : _mem[k];
    }
    return m;
  }

  static Future<void> importAll(Map<String, dynamic> m) async {
    for (final e in m.entries) {
      final v = e.value;
      if (v is String || v is bool || v is int || v is double || v is List) {
        await _put(e.key, v as Object);
      }
    }
  }
}
