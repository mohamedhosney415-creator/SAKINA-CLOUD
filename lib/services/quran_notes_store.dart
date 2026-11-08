import '../core/store.dart';

/// Local personal Quran annotations, stored independently from favorites.
class QuranNotesStore {
  static const _key = 'quran_notes_v1';

  static List<Map<String, dynamic>> get _items {
    final raw = Store.json(_key, []);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['s'] is int && item['a'] is int)
        .toList();
  }

  static String _id(int surah, int ayah) => '$surah:$ayah';

  static bool isBookmarked(int surah, int ayah) => _items.any((item) =>
      item['id'] == _id(surah, ayah) && item['bookmark'] == true);

  static String noteFor(int surah, int ayah) {
    for (final item in _items) {
      if (item['id'] == _id(surah, ayah)) return item['note'] as String? ?? '';
    }
    return '';
  }

  static Future<void> setBookmark(int surah, int ayah, bool value,
      {String surahName = ''}) async {
    final items = _items;
    final id = _id(surah, ayah);
    final index = items.indexWhere((item) => item['id'] == id);
    if (index >= 0) {
      items[index]['bookmark'] = value;
      items[index]['s'] = surah;
      items[index]['a'] = ayah;
      items[index]['name'] = surahName;
      items[index]['updated'] = DateTime.now().millisecondsSinceEpoch;
    } else if (value) {
      items.add({
        'id': id,
        's': surah,
        'a': ayah,
        'name': surahName,
        'bookmark': true,
        'note': '',
        'updated': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _save(items);
  }

  static Future<void> setNote(int surah, int ayah, String note,
      {String surahName = ''}) async {
    final items = _items;
    final id = _id(surah, ayah);
    final index = items.indexWhere((item) => item['id'] == id);
    if (index >= 0) {
      items[index]['note'] = note.trim();
      items[index]['updated'] = DateTime.now().millisecondsSinceEpoch;
      if (surahName.isNotEmpty) items[index]['name'] = surahName;
      if (items[index]['bookmark'] != true && note.trim().isEmpty) {
        items.removeAt(index);
      }
    } else if (note.trim().isNotEmpty) {
      items.add({
        'id': id,
        's': surah,
        'a': ayah,
        'name': surahName,
        'bookmark': false,
        'note': note.trim(),
        'updated': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _save(items);
  }

  static Future<void> remove(int surah, int ayah) async {
    final items = _items..removeWhere((item) => item['id'] == _id(surah, ayah));
    await _save(items);
  }

  static List<Map<String, dynamic>> get entries => _items
    ..sort((left, right) =>
        (right['updated'] as int? ?? 0).compareTo(left['updated'] as int? ?? 0));

  static List<Map<String, dynamic>> get marked =>
      entries.where((item) => item['bookmark'] == true).toList();

  static List<Map<String, dynamic>> get annotated => entries
      .where((item) => (item['note'] as String? ?? '').isNotEmpty)
      .toList();

  static Future<void> _save(List<Map<String, dynamic>> items) =>
      Store.setJson(_key, items);
}
