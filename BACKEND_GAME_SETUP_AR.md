# SAKINA Game Cloud — إعداد الباك إند

## 1) Supabase
في مشروع Supabase الحالي نفّذ الملف:

`supabase/migration_game_cloud_v1.sql`

الملف لا يحذف الجداول الحالية، ويضيف:
- game_progress
- game_question_history
- game_events
- game_daily_challenges
- game_questions
- RLS policies
- server-side sanity validation
- بنك اللعبة الحالي 1000 سؤال

## 2) Owner
استخدم حسابك الحالي ثم نفّذ في SQL Editor:

```sql
update public.profiles
set role = 'owner'
where email = 'YOUR_EMAIL@example.com';
```

## 3) ما الذي يحدث داخل التطبيق؟
- اللعبة تعمل Offline.
- عند تسجيل الدخول يتم مزامنة تقدم اللعبة منفصلًا عن بيانات SAKINA الأخرى.
- عند وجود بنك أسئلة محدث في Supabase يستخدمه التطبيق بدل البنك المدمج.
- البنك المدمج يبقى fallback عند عدم وجود إنترنت.
- سجل الأحداث يسجل الإجابات والمكافآت والمشتريات للمراجعة.
- RLS يمنع المستخدم من قراءة بيانات مستخدم آخر.
- لوحة المالك تعرض عدد لاعبي اللعبة والأحداث الأخيرة.

## ملاحظة
التحقق الحالي على الخادم هو sanity validation للقيم والتسلسل. لا يُعتبر نظام اقتصاد تنافسي مقاومًا بالكامل للغش؛ الوصول إلى هذا المستوى يتطلب جعل كل عمليات احتساب النقاط/النور authoritative عبر RPC/server functions بدل قبول snapshot من العميل.
