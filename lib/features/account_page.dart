import 'package:flutter/material.dart';
import '../cloud/cloud_service.dart';
import 'auth_page.dart';
import 'admin_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool owner = false;
  @override void initState() { super.initState(); _loadOwner(); }
  Future<void> _loadOwner() async { if (CloudService.signedIn) { final v = await CloudService.isOwner(); if (mounted) setState(() => owner = v); } }


  Future<void> _sync(BuildContext context) async {
    try {
      await CloudService.pushLocalData();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت مزامنة بياناتك')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل المزامنة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = CloudService.user;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        if (!CloudService.enabled)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Cloud غير مفعّل في نسخة البناء الحالية.')))
        else if (u == null) ...[
          const Icon(Icons.account_circle_outlined, size: 76),
          const SizedBox(height: 12),
          const Text('أنت غير مسجل الدخول', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage())), icon: const Icon(Icons.login), label: const Text('تسجيل الدخول / إنشاء حساب')),
        ] else ...[
          ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(u.email ?? 'مستخدم'), subtitle: Text('ID: ${u.id}')),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () => _sync(context), icon: const Icon(Icons.cloud_upload_rounded), label: const Text('مزامنة الآن')),
          OutlinedButton.icon(onPressed: () async { await CloudService.signOut(); if (context.mounted) Navigator.pop(context); }, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
          if (owner) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage())), icon: const Icon(Icons.admin_panel_settings), label: const Text('لوحة المالك')),
          ],
        ],
      ]),
    );
  }
}
