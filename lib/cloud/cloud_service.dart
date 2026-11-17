import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/store.dart';
import 'supabase_config.dart';

class CloudService {
  static SupabaseClient get client => Supabase.instance.client;
  static bool get enabled => SupabaseConfig.configured;
  static User? get user => enabled ? client.auth.currentUser : null;
  static bool get signedIn => user != null;

  static Future<void> init() async {
    if (!enabled) return;
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  static Future<AuthResponse> signUp(String email, String password) async {
    final r = await client.auth.signUp(email: email, password: password);
    return r;
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    final r = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return r;
  }

  static Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.hosny.sakina://login-callback/',
    );
  }

  static Future<void> signOut() => client.auth.signOut();

  /// Creates immutable local/cloud snapshots and verifies the cloud copy in one DB transaction.
  /// Both sides are preserved before the current local state becomes the restore point.
  static Future<Map<String, dynamic>> prepareUpdateBackup() async {
    final u = user;
    if (u == null) throw StateError('AUTH_REQUIRED');
    final response = await client.rpc(
      'prepare_sakina_update_backup',
      params: {'p_local_data': Store.exportAll()},
    );
    if (response is! Map) {
      throw StateError('INVALID_BACKUP_RESPONSE');
    }
    final result = Map<String, dynamic>.from(response);
    if (result['ok'] != true || result['verified'] != true) {
      throw StateError('BACKUP_NOT_VERIFIED');
    }
    return result;
  }

  static Future<bool> pushLocalData({bool allowOverwrite = false}) async {
    final u = user;
    if (u == null) return false;
    final local = Store.exportAll();
    final existing = await client
        .from('user_data')
        .select('data')
        .eq('user_id', u.id)
        .maybeSingle();
    if (existing != null && existing['data'] != null) {
      final remote = Map<String, dynamic>.from(existing['data'] as Map);
      if (!allowOverwrite && jsonEncode(local) != jsonEncode(remote))
        return false;
    }
    await client.from('user_data').upsert({
      'user_id': u.id,
      'data': local,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return true;
  }

  /// Returns false when no remote data exists or differing local data would be
  /// overwritten. Callers must explicitly opt in to replacing local state.
  static Future<bool> pullLocalData({bool allowOverwrite = false}) async {
    final u = user;
    if (u == null) return false;
    final row = await client
        .from('user_data')
        .select('data')
        .eq('user_id', u.id)
        .maybeSingle();
    if (row == null || row['data'] == null) return false;
    final data = Map<String, dynamic>.from(row['data'] as Map);
    final local = Store.exportAll();
    if (!allowOverwrite &&
        local.isNotEmpty &&
        jsonEncode(local) != jsonEncode(data)) {
      return false;
    }
    await Store.importAll(data);
    return true;
  }

  static Future<void> recordLogin() async {
    final u = user;
    if (u == null) return;
    await client.from('profiles').update({
      'email': u.email,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', u.id);
  }

  static Future<bool> isOwner() async {
    final u = user;
    if (u == null) return false;
    final row = await client
        .from('profiles')
        .select('role')
        .eq('id', u.id)
        .maybeSingle();
    return row?['role'] == 'owner';
  }

  static Future<List<Map<String, dynamic>>> adminUsers() async {
    final rows = await client
        .from('profiles')
        .select('id,email,display_name,role,created_at,last_seen_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> myMessages() async {
    final u = user;
    if (u == null) return const [];
    final rows = await client.from('user_messages').select('id,title,body,created_at,read_at').eq('recipient_id', u.id).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
  static Future<void> markMessageRead(String messageId) async {
    final u = user;
    if (u == null) return;
    await client.from('user_messages').update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId).eq('recipient_id', u.id);
  }

  static Future<void> sendMessage({required String recipientId, required String title, required String body}) async {
    final u = user;
    if (u == null || !await isOwner()) throw StateError('Owner access required');
    await client.from('user_messages').insert({'recipient_id': recipientId, 'sender_id': u.id, 'title': title, 'body': body});
  }

  static Future<void> broadcastMessage({required String title, required String body}) async {
    final u = user;
    if (u == null || !await isOwner()) throw StateError('Owner access required');
    final rows = await client.from('profiles').select('id').eq('role', 'user');
    final ids = List<Map<String, dynamic>>.from(rows).map((x) => x['id'].toString()).toList();
    if (ids.isEmpty) return;
    await client.from('user_messages').insert(ids.map((id) => {'recipient_id': id, 'sender_id': u.id, 'title': title, 'body': body}).toList());
  }

  static Future<void> blockUser(String userId, {String? reason}) async {
    final u = user;
    if (u == null || !await isOwner()) throw StateError('Owner access required');
    await client.from('user_blocks').upsert({'user_id': userId, 'blocked_by': u.id, 'reason': reason});
  }

  static Future<void> unblockUser(String userId) async {
    if (!await isOwner()) throw StateError('Owner access required');
    await client.from('user_blocks').delete().eq('user_id', userId);
  }

  static Future<bool> isBlocked() async {
    final u = user;
    if (u == null) return false;
    final row = await client.from('user_blocks').select('user_id,reason').eq('user_id', u.id).maybeSingle();
    return row != null;
  }

  static Future<void> recordAppInstall({
    required String version,
    required int buildNumber,
  }) async {
    final u = user;
    if (u == null) return;
    await client.from('app_installs').upsert({
      'user_id': u.id,
      'app_version': version,
      'build_number': buildNumber,
      'platform': 'android',
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> adminAppInstalls() async {
    if (!await isOwner()) throw StateError('Owner access required');
    final rows = await client
        .from('app_installs')
        .select('user_id,app_version,build_number,platform,last_seen_at')
        .order('last_seen_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>?> appUpdateSettings() async {
    final row = await client
        .from('app_update_settings')
        .select()
        .eq('id', 1)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  static Future<void> saveAppUpdateSettings(
    Map<String, dynamic> settings,
  ) async {
    final u = user;
    if (u == null || !await isOwner()) {
      throw StateError('Owner access required');
    }
    await client.from('app_update_settings').upsert({
      ...settings,
      'id': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': u.id,
    });
  }

  static String prettyJson(Object value) =>
      const JsonEncoder.withIndent('  ').convert(value);
}
