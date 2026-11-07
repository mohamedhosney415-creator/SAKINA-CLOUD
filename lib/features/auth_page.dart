import 'package:flutter/material.dart';
import '../cloud/cloud_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool loading = false;
  String? error;

  Future<void> submit() async {
    setState(() { loading = true; error = null; });
    try {
      if (register) {
        await CloudService.signUp(email.text.trim(), password.text);
      } else {
        await CloudService.signIn(email.text.trim(), password.text);
      }
      await CloudService.recordLogin();
      await CloudService.pullLocalData();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('حساب سكينة')),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        Icon(Icons.shield_moon_rounded, size: 64, color: cs.primary),
        const SizedBox(height: 12),
        Text(register ? 'إنشاء حساب' : 'تسجيل الدخول', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('الحساب اختياري، ويُستخدم لمزامنة بياناتك بين أجهزتك.', textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withAlpha(160))),
        const SizedBox(height: 24),
        TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: password, obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder())),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: TextStyle(color: cs.error, fontSize: 12)),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: loading ? null : submit,
            icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
            label: Text(register ? 'إنشاء الحساب' : 'دخول')),
        TextButton(onPressed: loading ? null : () => setState(() { register = !register; error = null; }),
            child: Text(register ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد')),
      ]),
    );
  }
}
