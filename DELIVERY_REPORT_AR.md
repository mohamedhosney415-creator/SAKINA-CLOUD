# تقرير تسليم SAKINA — feature/sakina-5-upgrade

## ما تم تنفيذه

تم تطبيق حزمة التعديلات المرفقة على نسخة فرع `feature/sakina-5-upgrade` من مستودع SAKINA-CLOUD.

- إعادة اللعبة إلى الموضع الأوسط في شريط التنقل مع اختبار موضعها ونقرها.
- تحسين منطق التحدي اليومي: تغيير التاريخ، منع احتساب السؤال مرتين، اختيار أسئلة مختلفة، وإتاحة الرجوع بعد انتهاء التحدي.
- منح مكافأة إكمال التحدي بعد حل الأسئلة الخمسة بغض النظر عن صحة الإجابات، مرة واحدة يوميًا.
- تحسين التحقق من أسئلة لوحة المالك وجعل السؤال الجديد غير منشور افتراضيًا حتى المراجعة.
- تحديث استعلام مستخدمي لوحة المالك ليطلب الحقول المسموح بها فقط بدل `select('*')`.
- تنظيم ملفات Supabase migrations بأسماء وإصدارات متوافقة.
- إضافة اختبار موضع اللعبة في شريط التنقل.
- إضافة اختيار نمط عرض القرآن داخل صفحة القراءة، مع ثلاثة أنماط محفوظة محليًا: العرض المتصل، بطاقة مستقلة لكل آية، والقراءة المريحة ذات التباعد الأكبر.

## الملفات المعدلة

- `lib/app.dart`
- `lib/cloud/cloud_service.dart`
- `lib/core/widgets.dart`
- `lib/features/admin_page.dart`
- `lib/features/home_page.dart`
- `lib/features/quran_game/pages/quran_game_page.dart`
- `lib/features/quran_game/services/quran_game_service.dart`
- `lib/features/readiness_page.dart`
- `lib/features/reader_page.dart`
- `test/quran_game_logic_test.dart`
- `test/sakina_nav_bar_test.dart`
- `supabase/migrations/20261110000102_game_cloud_v1.sql`
- `supabase/migrations/20261116141423_game_cloud_v2.sql`
- `supabase/migrations/20261116141553_game_question_types.sql`

تم حذف اسم migration القديم المتعارض:

- `supabase/migrations/20261116_game_question_types.sql`

## نتائج التحقق المتاحة

- `git apply --check`: ناجح.
- `git diff --check`: ناجح.
- `python3 tool/verify_project.py`: ناجح — المشروع يحتوي على 78 ملف Dart.
- `git diff --check` بعد إضافة أنماط القرآن: ناجح.

## فحوصات لم تُشغّل في هذه البيئة

بيئة التنفيذ الحالية لا تحتوي على Flutter SDK، لذلك لم يتم تشغيل:

- `flutter pub get`
- `flutter test`
- `flutter analyze`
- `flutter build apk --release`

يجب تشغيلها بعد تنزيل Flutter على جهازك أو عبر GitHub Actions. ملف workflow موجود في `.github/workflows/android-apk.yml`.

## خطوات الرفع على GitHub

بعد فك الضغط:

```bash
git init
git remote add origin https://github.com/mohamedhosney415-creator/SAKINA-CLOUD.git
git switch -c feature/sakina-5-upgrade
flutter pub get
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
git add .
git commit -m "feat: complete SAKINA game and navigation upgrade"
git push -u origin feature/sakina-5-upgrade
```

إذا كان لديك نسخة Git محلية أصلًا، انسخ الملفات فوقها بدل تنفيذ `git init`، ثم نفّذ أوامر الفحص والـcommit والـpush.

## تنبيه Supabase

لا يوجد في هذه الحزمة Service Role Key داخل التطبيق. يجب تطبيق migrations الجديدة على مشروع Supabase بعد مراجعة حالة قاعدة البيانات الحالية، وعدم تشغيل migration سبق تطبيقها يدويًا.

## حدود المراجعة الحالية

تمت إضافة أنماط قراءة حقيقية مبنية على نص الآيات المحفوظ، لكن لم يتم اختلاق نظام صفحات المصحف الـ604؛ فهذا يتطلب ملف تخطيط صفحات موثوقًا يربط كل آية بصفحتها. كما بقي اختبار Flutter وبناء APK معلقين إلى حين توفر Flutter وAndroid SDK أو تشغيل GitHub Actions.
