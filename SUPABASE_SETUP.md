# SAKINA + Supabase

## 1) Flutter dependency
المشروع يستخدم `supabase_flutter: ^2.14.2` لأنه متوافق مع Dart 3.3.

## 2) إنشاء المشروع
أنشئ مشروعًا مجانيًا في Supabase ثم انسخ:
- Project URL
- Publishable key

لا تضع Secret/Service Role key داخل التطبيق.

## 3) بناء التطبيق
```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 4) SQL
نفّذ ملف `supabase/schema.sql` في SQL Editor.

## 5) Owner
بعد إنشاء حسابك، نفّذ:
```sql
update public.profiles set role = 'owner' where email = 'YOUR_OWNER_EMAIL';
```

مهم: لا نعتمد على email داخل التطبيق لمنح الصلاحيات؛ صلاحية الإدارة محمية بـRLS في قاعدة البيانات.
