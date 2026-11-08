#!/usr/bin/env bash
# للبناء على جهازك (يتطلب Flutter مثبّتًا): ينشئ مجلد android ويجهّزه ثم يبني الـ APK.
set -e
python3 tool/verify_project.py
flutter create --org com.hosny --project-name sakina --platforms=android .
rm -rf test
python3 tool/patch_android.py
flutter pub get
flutter build apk --release
echo "الـ APK هنا: build/app/outputs/flutter-apk/app-release.apk"
