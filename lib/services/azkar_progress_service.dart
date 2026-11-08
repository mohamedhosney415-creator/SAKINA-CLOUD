import '../core/store.dart';

/// Additional local-only Azkar state. Daily counts remain in `azkar_prog`.
class AzkarProgressService {
  static Map<String, dynamic> _map(String key) {
    final value = Store.json(key, {});
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  static Map<String, dynamic> get last => _map('azkar_last');

  static Future<void> saveLast(
      {required String categoryId, String? zikrId, int? count}) {
    final previous = last;
    final sameCategory = previous['categoryId'] == categoryId;
    return Store.setJson('azkar_last', {
      'categoryId': categoryId,
      if (zikrId != null || sameCategory && previous['zikrId'] != null)
        'zikrId': zikrId ?? previous['zikrId'],
      if (count != null || sameCategory && previous['count'] != null)
        'count': count ?? previous['count'],
    });
  }

  static List<Map<String, dynamic>> get groups => _map('azkar_groups')
      .entries
      .where((e) => e.value is Map)
      .map((e) => <String, dynamic>{
            'id': e.key,
            ...Map<String, dynamic>.from(e.value as Map)
          })
      .toList();

  static Future<void> saveGroup(
      String id, String name, List<String> zikrIds) async {
    final values = _map('azkar_groups');
    values[id] = {'name': name, 'zikrIds': zikrIds.toSet().toList()};
    await Store.setJson('azkar_groups', values);
  }

  static Future<void> deleteGroup(String id) async {
    final values = _map('azkar_groups')..remove(id);
    await Store.setJson('azkar_groups', values);
  }
}
