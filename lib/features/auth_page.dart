import 'package:flutter/material.dart';
import '../cloud/cloud_service.dart';
import 'quran_game/services/quran_game_service.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

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
  bool showPassword = false;
  String? error;

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'اكتب البريد الإلكتروني وكلمة المرور أولًا');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (register) {
        await CloudService.signUp(email.text.trim(), password.text);
      } else {
        await CloudService.signIn(email.text.trim(), password.text);
      }
      await CloudService.recordLogin();
      await CloudService.pullLocalData();
      // Game progress is synced separately so it can never overwrite
      // unrelated SAKINA data.
      await QuranGameService.syncFromCloud();
      await QuranGameService.loadRemoteQuestions();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => error = register
            ? 'تعذر إنشاء الحساب. تأكد من البيانات وحاول مرة أخرى.'
            : 'البريد الإلكتروني أو كلمة المرور غير صحيحة.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [cs.primary, const Color(0xFF123C32)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -28,
                    top: -38,
                    child: Icon(Icons.auto_awesome,
                        size: 160, color: gold.withAlpha(25)),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: gold.withAlpha(30),
                            border: Border.all(color: gold.withAlpha(150)),
                          ),
                          child: const Icon(Icons.nights_stay_rounded,
                              color: gold, size: 34),
                        ),
                        const SizedBox(height: 12),
                        const Text('سكينة',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900)),
                        Text('بياناتك معك أينما ذهبت',
                            style: TextStyle(
                                color: Colors.white.withAlpha(190),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(register ? 'إنشاء حساب جديد' : 'مرحبًا بك في سكينة',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              register
                  ? 'أنشئ حسابًا لحفظ موضع القراءة والتفضيلات بين أجهزتك.'
                  : 'سجّل دخولك لمزامنة موضع القراءة والتفضيلات بين أجهزتك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withAlpha(160), height: 1.7),
            ),
            const SizedBox(height: 24),
            Panel(
              child: Column(
                children: [
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: !showPassword,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                        icon: Icon(showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error, height: 1.5)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading ? null : submit,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.arrow_back_rounded),
                      label: Text(register ? 'إنشاء الحساب' : 'تسجيل الدخول'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: loading
                  ? null
                  : () => setState(() {
                        register = !register;
                        error = null;
                      }),
              child: Text(register ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد'),
            ),
            const SizedBox(height: 18),
            Text('لا إعلانات • لا تتبع • خصوصيتك أولًا',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(120))),
          ],
        ),
      ),
    );
  }
}
