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

  static Future<AuthResponse> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => client.auth.signOut();

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
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static String prettyJson(Object value) =>
      const JsonEncoder.withIndent('  ').convert(value);
}
