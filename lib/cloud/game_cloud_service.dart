import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/store.dart';
import 'cloud_service.dart';

/// Cloud persistence for the "أكمل الآية" game.
///
/// The client keeps working offline. This service stores only qgame_*
/// keys, so syncing the game can never overwrite unrelated SAKINA data.
class GameCloudService {
  static bool get enabled => CloudService.enabled && CloudService.signedIn;
  static SupabaseClient get client => CloudService.client;

  static Map<String, dynamic> localSnapshot() {
    final all = Store.exportAll();
    return Map<String, dynamic>.fromEntries(
      all.entries.where((e) => e.key.startsWith('qgame_')),
    );
  }

  static Future<void> sync({bool preferRemote = false}) async {
    if (!enabled) return;
    final uid = client.auth.currentUser!.id;
    final local = localSnapshot();
    final remote = await client
        .from('game_progress')
        .select('data, updated_at, version')
        .eq('user_id', uid)
        .maybeSingle();

    if (remote == null) {
      await _push(uid, local);
      return;
    }

    final remoteData = Map<String, dynamic>.from(remote['data'] as Map? ?? {});
    final remoteAt = DateTime.tryParse('${remote['updated_at'] ?? ''}');
    final localAt = DateTime.tryParse(
      Store.str('qgame_local_changed_at', ''),
    );

    if (preferRemote ||
        (remoteAt != null && (localAt == null || remoteAt.isAfter(localAt)))) {
      await Store.mergeImport(remoteData);
      await Store.setStr(
        'qgame_cloud_updated_at',
        remoteAt?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
      );
      return;
    }

    await _push(uid, local);
  }

  static Future<void> _push(String uid, Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc();
    await client.from('game_progress').upsert({
      'user_id': uid,
      'data': data,
      'version': 1,
      'updated_at': now.toIso8601String(),
    });
    await Store.setStr('qgame_cloud_updated_at', now.toIso8601String());
  }

  /// Writes an immutable local event to the cloud ledger when online.
  /// The ledger is diagnostic/audit data; authoritative reward validation
  /// remains server-side and can be tightened without changing the app API.
  static Future<void> recordEvent({
    required String type,
    required int amount,
    Map<String, dynamic>? metadata,
  }) async {
    if (!enabled) return;
    await client.from('game_events').insert({
      'user_id': client.auth.currentUser!.id,
      'event_type': type,
      'amount': amount,
      'metadata': metadata ?? const {},
      'idempotency_key':
          '${type}_${DateTime.now().microsecondsSinceEpoch}_${amount.abs()}',
    });
  }

  static Future<void> upsertDailyChallenge({
    required String dateKey,
    required String questionId,
    required int reward,
  }) async {
    if (!enabled) return;
    await client.from('game_daily_challenges').upsert({
      'date_key': dateKey,
      'question_id': questionId,
      'reward': reward,
      'active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'date_key');
  }

  static Future<List<Map<String, dynamic>>> fetchQuestions() async {
    if (!enabled) return const [];
    final rows = await client
        .from('game_questions')
        .select('id,surah_number,surah_name,ayah_number,full_ayah,hidden_word,options,correct_option,difficulty,level,recitation_audio,global_ayah_number,explanation,question_type,question_text,context_text,source_name,source_reference')
        .eq('active', true)
        .order('level')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<int> fetchQuestionMix() async {
    if (!enabled) return 50;
    final row = await client
        .from('game_settings')
        .select('setting_value')
        .eq('setting_key', 'question_mix')
        .maybeSingle();
    if (row == null || row['setting_value'] is! Map) return 50;
    final value = Map<String, dynamic>.from(row['setting_value'] as Map);
    final percent = value['quran_percent'];
    return (percent is num ? percent.toInt() : 50).clamp(0, 100).toInt();
  }

  static Future<void> ownerSetQuestionMix(int quranPercent) async {
    if (!enabled || !await CloudService.isOwner()) {
      throw Exception('Owner access required');
    }
    final quran = quranPercent.clamp(0, 100).toInt();
    await client.from('game_settings').upsert({
      'setting_key': 'question_mix',
      'setting_value': {
        'quran_percent': quran,
        'islamic_percent': 100 - quran,
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': client.auth.currentUser!.id,
    }, onConflict: 'setting_key');
    await Store.setInt('qgame_quran_mix', quran);
  }

  static Future<Map<String, dynamic>?> dailyChallenge(String dateKey) async {
    if (!enabled) return null;
    final row = await client
        .from('game_daily_challenges')
        .select('date_key, question_id, reward, active')
        .eq('date_key', dateKey)
        .eq('active', true)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  static Future<void> markQuestionSeen(String questionId) async {
    if (!enabled) return;
    await client.from('game_question_history').upsert({
      'user_id': client.auth.currentUser!.id,
      'question_id': questionId,
      'seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,question_id');
  }

  static Future<Map<String, dynamic>> ownerSummary() async {
    if (!enabled || !await CloudService.isOwner()) {
      throw Exception('Owner access required');
    }
    final overview = await client.rpc('game_admin_overview');
    final events = await client
        .from('game_events')
        .select('user_id, amount, event_type, metadata, created_at')
        .order('created_at', ascending: false)
        .limit(1000);
    return {
      ...Map<String, dynamic>.from(overview as Map),
      'recent_events': List<Map<String, dynamic>>.from(events),
    };
  }

  static Future<List<Map<String, dynamic>>> ownerPlayers() async {
    if (!enabled || !await CloudService.isOwner()) throw Exception('Owner access required');
    final rows = await client
        .from('game_admin_player_stats')
        .select('user_id,email,display_name,updated_at,level,score,noor,total_questions,correct_answers,streak,stars')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> ownerQuestions({int? level}) async {
    if (!enabled || !await CloudService.isOwner()) throw Exception('Owner access required');
    var q = client.from('game_questions').select('*');
    if (level != null) q = q.eq('level', level);
    final rows = await q.order('level').order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> ownerUpsertQuestion(Map<String, dynamic> data) async {
    if (!enabled || !await CloudService.isOwner()) throw Exception('Owner access required');
    await client.from('game_questions').upsert(data, onConflict: 'id');
  }

  static Future<void> ownerDeleteQuestion(String id) async {
    if (!enabled || !await CloudService.isOwner()) {
      throw Exception('Owner access required');
    }
    await client.from('game_questions').delete().eq('id', id);
  }

  static Future<void> ownerSetQuestionActive(String id, bool active) async {
    if (!enabled || !await CloudService.isOwner()) throw Exception('Owner access required');
    await client.from('game_questions').update({
      'active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_at': active ? DateTime.now().toUtc().toIso8601String() : null,
      'reviewed_by': active ? client.auth.currentUser!.id : null,
    }).eq('id', id);
  }

  static Future<void> ownerSetDailyChallenge({required String dateKey, required String questionId, int reward = 30}) async {
    if (!enabled || !await CloudService.isOwner()) throw Exception('Owner access required');
    await client.from('game_daily_challenges').upsert({
      'date_key': dateKey, 'question_id': questionId, 'reward': reward, 'active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'date_key');
  }

  static Future<List<Map<String, dynamic>>> ownerDailyChallenges() async {
    if (!enabled || !await CloudService.isOwner()) throw Exception('Owner access required');
    final rows = await client.from('game_daily_challenges').select('*').order('date_key', ascending: false).limit(60);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<int> ownerAdjustNoor({required String userId, required int delta, required String reason}) async {
    if (!enabled || !await CloudService.isOwner()) throw Exception('Owner access required');
    final result = await client.rpc('game_owner_adjust_noor', params: {
      'target_user': userId, 'delta': delta, 'reason': reason,
    });
    return (result as num).toInt();
  }
}
