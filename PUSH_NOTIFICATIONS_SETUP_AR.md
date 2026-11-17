# إعداد إشعارات Push لتطبيق سَكِينَة

إرسال الرسائل الجماعية والفردية داخل التطبيق يعمل من لوحة المالك، وتظهر الرسائل في «المزيد ← رسائل سَكِينَة». أما وصول إشعار للهاتف وهو مغلق فيحتاج Firebase Cloud Messaging (FCM)، ولا يمكن تفعيله بمجرد إعداد جدول الرسائل.

## المطلوب قبل ربط Push

1. إنشاء مشروع Firebase وربط تطبيق Android بمعرّف الحزمة `com.hosny.sakina`.
2. تنزيل ملف `google-services.json` الخاص بالتطبيق وإضافته إلى `android/app/google-services.json` في فرع العمل.
3. تفعيل Firebase Cloud Messaging للمشروع.
4. إنشاء Service Account مخصص لإرسال FCM HTTP v1، وحفظ بياناته كـ Secret في إعدادات Supabase Edge Functions. لا تضع ملف Service Account أو مفتاحه في Flutter أو مستودع GitHub أو المحادثة.
5. بعد توفير ملف إعداد Android، نضيف تهيئة Firebase Messaging وتسجيل رموز الأجهزة، ثم ننشر Edge Function محمية تتحقق من صلاحية المالك وترسل الإشعارات.

## تنبيه أمني

ملف `google-services.json` خاص بإعداد تطبيق Android، أما مفتاح Service Account فهو سر حساس ويجب حفظه في Supabase Secrets فقط. لا تستخدم مفتاح `service_role` داخل التطبيق.
