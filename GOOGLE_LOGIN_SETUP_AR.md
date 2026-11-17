# إعداد تسجيل الدخول باستخدام Google في سَكِينَة

تمت إضافة زر Google في التطبيق ورابط الرجوع الخاص بأندرويد. يلزم إكمال إعداد المزود مرة واحدة قبل أن يعمل تسجيل الدخول فعليًا.

1. افتح Supabase Dashboard ثم Authentication → Sign In / Providers → Google وفعّل المزود.
2. أنشئ OAuth Client في Google Cloud Console من نوع Web application، وأدخل Callback URL الذي يعرضه Supabase حرفيًا ضمن Authorized redirect URIs.
3. ضع Google Client ID وClient Secret في إعدادات Google Provider داخل Supabase فقط. لا تضع Client Secret في Flutter أو GitHub.
4. في Authentication → URL Configuration أضف هذا الرابط إلى Redirect URLs:
   `com.hosny.sakina://login-callback/`
5. أعد بناء التطبيق من فرع `feature/sakina-5-upgrade`.

ملاحظات:
- اسم الحزمة في إعداد البناء هو `com.hosny.sakina`.
- استخدم SHA-1/SHA-256 الخاص بتوقيع Debug عند الحاجة لإعداد OAuth Android Client. بصمة Debug قد تختلف عن Release.
- إذا ظهر Provider not enabled أو redirect URL غير مسموح، راجع الخطوات السابقة؛ الزر وحده لا ينشئ بيانات اعتماد Google.
