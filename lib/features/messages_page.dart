import 'package:flutter/material.dart';
import '../cloud/cloud_service.dart';

class MessagesPage extends StatefulWidget { const MessagesPage({super.key}); @override State<MessagesPage> createState() => _MessagesPageState(); }
class _MessagesPageState extends State<MessagesPage> {
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){ super.initState(); future=CloudService.myMessages(); }
  @override Widget build(BuildContext context)=>Scaffold(appBar: AppBar(title: const Text('رسائل سكينة')),body: FutureBuilder<List<Map<String,dynamic>>>(future: future,builder:(context,s){
    if(s.connectionState!=ConnectionState.done) return const Center(child:CircularProgressIndicator());
    if(s.hasError) return const Center(child:Text('تعذر تحميل الرسائل.'));
    final rows=s.data??const []; if(rows.isEmpty) return const Center(child:Text('لا توجد رسائل.'));
    return ListView.builder(padding:const EdgeInsets.all(16),itemCount:rows.length,itemBuilder:(context,i){final m=rows[i];return Card(child:ListTile(leading:const Icon(Icons.mark_email_unread_rounded),title:Text('${m['title']??'رسالة'}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Padding(padding:const EdgeInsets.only(top:6),child:Text('${m['body']??''}\n\n${m['created_at']??''}')),isThreeLine:true));});
  }));
}