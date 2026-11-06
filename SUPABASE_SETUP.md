# SAKINA 3.2.1 + Supabase

## بيانات المشروع
- Project URL: `https://gjvqewyuqkmgvcpzsssc.supabase.co`
- استخدم Publishable Key فقط داخل تطبيق Flutter.
- لا تضع Secret/Service Role key في التطبيق أو GitHub.

## 1) تجهيز قاعدة البيانات الحالية

هذا الإصدار يحتوي على ترحيل آمن لأن قاعدة البيانات أُنشئت بالفعل بجداول أولية.

1. افتح Supabase ثم SQL Editor ثم New query.
2. افتح الملف `supabase/migrations_20261106_align_existing_schema.sql` وانسخ محتواه كاملًا.
3. الصقه في SQL Editor واضغط Run.
4. يجب أن تظهر رسالة `Success. No rows returned`.

الترحيل لا يحذف الجداول أو بيانات المستخدمين. يضيف أعمدة `email`, `role`, `last_seen_at` إلى `profiles`، وينشئ `user_data` للمزامنة، ويضبط سياسات RLS. كما يمنع المستخدم العادي من تعديل صلاحية `role`.

## 2) إنشاء حساب المالك

1. شغّل التطبيق بعد ربطه ببيانات Supabase.
2. من شاشة حساب سكينة أنشئ حسابك باستخدام بريدك الإلكتروني.
3. بعد نجاح التسجيل، ارجع إلى Supabase SQL Editor ونفّذ هذا الاستعلام بعد استبدال البريد ببريد حسابك الحقيقي:

```sql
update public.profiles
set role = 'owner'
where email = 'YOUR_EMAIL@example.com';
```

4. سجّل الخروج من التطبيق ثم سجّل الدخول مرة أخرى. يجب أن يظهر زر «لوحة المالك» في صفحة الحساب.

لا تنفّذ استعلام ترقية المالك قبل إنشاء الحساب. لا تجعل حسابات أخرى `owner` إلا إذا كنت تريد منحها صلاحيات الإدارة.

## 3) ربط GitHub وبناء APK السحابي (الطريقة الأسهل)

1. افتح مستودع SAKINA على GitHub.
2. افتح Settings → Secrets and variables → Actions → New repository secret.
3. أضف السر الأول:
   - Name: `SUPABASE_URL`
   - Secret: `https://gjvqewyuqkmgvcpzsssc.supabase.co`
4. أضف السر الثاني:
   - Name: `SUPABASE_PUBLISHABLE_KEY`
   - Secret: انسخ Publishable key من Supabase → Project Settings → API Keys.
5. ارفع ملفات هذه النسخة إلى المستودع (مع استبدال الملفات القديمة).
6. افتح Actions → Build SAKINA APK → Run workflow.
7. بعد نجاح البناء، حمّل Artifact باسم `SAKINA-apk`.

**مهم:** استخدم Publishable key فقط. لا تستخدم `secret` أو `service_role` داخل التطبيق أو GitHub Actions.

## 4) بناء التطبيق محليًا

من داخل مجلد `Sakina`:

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://gjvqewyuqkmgvcpzsssc.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

استبدل `YOUR_PUBLISHABLE_KEY` بالمفتاح الذي نسخته من Supabase.

## 5) المزامنة والنسخ الاحتياطي

- زر «مزامنة الآن» يرفع بيانات التطبيق إلى جدول `user_data` الخاص بالحساب.
- عند تسجيل الدخول، يحاول التطبيق استعادة بيانات الحساب من `user_data`.
- صفحة النسخ الاحتياطي الحالية تصدّر/تستعيد ملف JSON محليًا. هذا مختلف عن النسخ السحابي التلقائي في Storage؛ لم يتم إنشاء Storage bucket في هذا الترحيل.

## ملاحظات أمنية

- لا تشارك كلمة مرور قاعدة البيانات أو مفاتيح `secret` و`service_role`.
- صلاحية المالك تُمنح من SQL Editor فقط، وليس من داخل التطبيق.
- RLS يمنع المستخدم من قراءة بيانات مزامنة حساب آخر.
