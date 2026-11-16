# تجهيز SAKINA لنظام iOS

أضيف Workflow باسم `Build SAKINA iOS` يعمل على macOS ويقوم تلقائيًا بإنشاء ملفات iOS الناقصة، ثم يجري `flutter pub get` والاختبارات والتحليل ويبني نسخة iOS غير موقعة للتأكد من سلامة التوافق.

## ما تم تجهيزه

- توليد مشروع iOS تلقائيًا عبر `flutter create --platforms=ios`.
- تشغيل اختبارات Flutter على macOS.
- تشغيل `flutter analyze`.
- بناء `Runner.app` غير موقعة ورفعها كـArtifact.
- حماية فتح إعدادات Android حتى لا تُستدعى على iPhone.
- منع استدعاء تحديث Android Widget على iOS.

## ما يلزم لإخراج IPA قابل للتثبيت

إخراج IPA موقعة يحتاج حساب Apple Developer، وBundle Identifier، وشهادة توزيع وProvisioning Profile أو إعدادات signing داخل مشروع iOS. هذه الخطوة لا يمكن تنفيذها من Ubuntu ولا بدون أسرار Apple.

بعد تجهيز حساب Apple، يمكن إضافة Secrets إلى GitHub ثم تطوير Workflow ليستخدم `flutter build ipa --release` مع signing مناسب. لا تضع شهادات Apple أو كلمات المرور داخل المستودع.

## ملاحظات توافق

وظائف الأذان والإشعارات والويدجت تم تطويرها أساسًا لـAndroid في هذه المرحلة. سيعمل التطبيق الأساسي والقرآن والحسابات على iOS بعد نجاح Workflow، لكن يجب اختبار الإشعارات، الصوت في الخلفية، الأذان، ومشاركة الملفات على جهاز iPhone حقيقي قبل النشر في App Store.
