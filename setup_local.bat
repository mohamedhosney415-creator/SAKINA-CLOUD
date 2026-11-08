@echo off
chcp 65001 >nul
REM للبناء على ويندوز (يتطلب Flutter و Python مثبتين)
python tool\verify_project.py || exit /b 1
call flutter create --org com.hosny --project-name sakina --platforms=android . || exit /b 1
if exist test rmdir /s /q test
python tool\patch_android.py || exit /b 1
call flutter pub get || exit /b 1
call flutter build apk --release || exit /b 1
echo APK: build\app\outputs\flutter-apk\app-release.apk
