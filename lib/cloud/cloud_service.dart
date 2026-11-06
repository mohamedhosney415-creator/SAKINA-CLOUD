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

  static Future<void> pushLocalData() async {
    final u = user;
    if (u == null) return;
    await client.from('user_data').upsert({
      'user_id': u.id,
      'data': Store.exportAll(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<bool> pullLocalData() async {
    final u = user;
    if (u == null) return false;
    final row = await client.from('user_data').select('data').eq('user_id', u.id).maybeSingle();
    if (row == null || row['data'] == null) return false;
    final data = Map<String, dynamic>.from(row['data'] as Map);
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
    final row = await client.from('profiles').select('role').eq('id', u.id).maybeSingle();
    return row?['role'] == 'owner';
  }

  static Future<List<Map<String, dynamic>>> adminUsers() async {
    final rows = await client.from('profiles').select('*').order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static String prettyJson(Object value) => const JsonEncoder.withIndent('  ').convert(value);
}
