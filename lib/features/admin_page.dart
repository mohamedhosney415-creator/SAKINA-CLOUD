import 'package:flutter/material.dart';
import '../cloud/cloud_service.dart';

class AdminPage extends StatefulWidget { const AdminPage({super.key}); @override State<AdminPage> createState() => _AdminPageState(); }
class _AdminPageState extends State<AdminPage> {
  bool loading = true; List<Map<String,dynamic>> users=[]; String? error;
  @override void initState(){super.initState(); load();}
  Future<void> load() async { try { final x=await CloudService.adminUsers(); if(mounted)setState(()=>users=x); } catch(e){ if(mounted)setState(()=>error='$e'); } finally {if(mounted)setState(()=>loading=false);} }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('لوحة المالك')),body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[Card(child:ListTile(leading:const Icon(Icons.people_alt),title:const Text('إجمالي الحسابات'),trailing:Text('${users.length}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)))),const SizedBox(height:10),for(final u in users)Card(child:ListTile(leading:const Icon(Icons.person_outline),title:Text('${u['email'] ?? 'بدون بريد'}'),subtitle:Text('آخر ظهور: ${u['last_seen_at'] ?? '—'}\nتاريخ التسجيل: ${u['created_at'] ?? '—'}')))])));
}
