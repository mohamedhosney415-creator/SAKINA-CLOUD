#!/usr/bin/env python3
"""
يجهّز مشروع الأندرويد الذي أنشأه `flutter create` ليعمل به SAKINA:
  1) الأذونات + خدمات الصوت + مستقبلات التنبيهات والويدجت في AndroidManifest
  2) MainActivity تعتمد AudioServiceActivity (تشغيل القرآن بالخلفية)
  3) نسخ ويدجت Kotlin والموارد والأيقونات
  4) نسخ ملفات الأذان من assets/adhan إلى res/raw (صوت الإشعار)
  5) تفعيل core library desugaring المطلوب لمكتبة الإشعارات
شغّله من جذر المشروع بعد flutter create.
"""
import glob
import os
import re
import shutil
import sys

ROOT = os.getcwd()
APP = os.path.join(ROOT, 'android', 'app')
MAIN = os.path.join(APP, 'src', 'main')
MARK = 'SAKINA_PATCHED'


def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()


def write(p, s):
    with open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def fail(msg):
    print('ERROR:', msg)
    sys.exit(1)


if not os.path.isdir(MAIN):
    fail('android/ غير موجود. شغّل flutter create أولًا.')

# ---------------------------------------------------------------- 1) Manifest
mf = os.path.join(MAIN, 'AndroidManifest.xml')
s = read(mf)
if MARK not in s:
    perms = [
        'INTERNET', 'POST_NOTIFICATIONS', 'SCHEDULE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED',
        'VIBRATE', 'WAKE_LOCK', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
        'USE_FULL_SCREEN_INTENT',
    ]
    perm_xml = '    <!-- %s -->\n' % MARK + ''.join(
        '    <uses-permission android:name="android.permission.%s"/>\n' % p for p in perms)
    s = s.replace('<application', perm_xml + '    <application', 1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="سَكِينَة"', s, count=1)

    components = '''
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>

        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>

        <receiver android:name=".SakinaWidgetProvider"
            android:label="سَكِينَة - المواقيت"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data android:name="android.appwidget.provider"
                android:resource="@xml/sakina_widget_info"/>
        </receiver>
'''
    s = s.replace('</application>', components + '    </application>', 1)
    # Full-screen adhan experience: wake and show the Flutter activity when Android permits it.
    s, activity_count = re.subn(
        r'(<activity\b(?=[^>]*android:name=\"[^\"]*MainActivity\")[^>]*)(>)',
        lambda m: m.group(1) + ' android:showWhenLocked=\"true\" android:turnScreenOn=\"true\"' + m.group(2),
        s, count=1)
    if activity_count == 0:
        print('WARNING: MainActivity attributes for full-screen adhan were not found')
    write(mf, s)
    print('manifest patched')
else:
    print('manifest already patched')

# ---------------------------------------------------------------- OAuth deep link callback
# Supabase redirects Google OAuth back into the Android app.
if 'SAKINA_OAUTH_REDIRECT' not in s:
    oauth_filter = '''
            <!-- SAKINA_OAUTH_REDIRECT -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="com.hosny.sakina" android:host="login-callback"/>
            </intent-filter>
'''
    s, count = re.subn(
        r'(<activity\b(?=[^>]*android:name="[^"]*MainActivity")[^>]*>)(.*?)(</activity>)',
        lambda m: m.group(1) + m.group(2) + oauth_filter + m.group(3),
        s, count=1, flags=re.S)
    if count == 0:
        fail('تعذر إضافة رابط رجوع Google إلى MainActivity')
    write(mf, s)
    print('Google OAuth deep link added')

# ---------------------------------------------------------------- 2) MainActivity + widget provider
kt_files = glob.glob(os.path.join(MAIN, 'kotlin', '**', 'MainActivity.kt'), recursive=True)
if not kt_files:
    fail('MainActivity.kt غير موجود (هل المشروع بلغة Kotlin؟)')
main_kt = kt_files[0]
pkg = re.search(r'^package\s+([\w.]+)', read(main_kt), re.M).group(1)
write(main_kt,
      'package %s\n\nimport com.ryanheise.audioservice.AudioServiceActivity\n\n'
      'class MainActivity : AudioServiceActivity()\n' % pkg)
provider = read(os.path.join(ROOT, 'android_native', 'kotlin', 'SakinaWidgetProvider.kt'))
write(os.path.join(os.path.dirname(main_kt), 'SakinaWidgetProvider.kt'),
      provider.replace('{{PKG}}', pkg))
print('MainActivity + widget provider written for package', pkg)

# ---------------------------------------------------------------- 3) Resources
src_res = os.path.join(ROOT, 'android_native', 'res')
dst_res = os.path.join(MAIN, 'res')
for dirpath, _, files in os.walk(src_res):
    rel = os.path.relpath(dirpath, src_res)
    out = os.path.join(dst_res, rel)
    os.makedirs(out, exist_ok=True)
    for f in files:
        shutil.copy2(os.path.join(dirpath, f), os.path.join(out, f))
print('resources copied')

# ---------------------------------------------------------------- 4) Adhan audio -> res/raw
raw_dir = os.path.join(dst_res, 'raw')
adhan_src = os.path.join(ROOT, 'assets', 'adhan')
copied = []
seen = {}
if os.path.isdir(adhan_src):
    for f in sorted(os.listdir(adhan_src)):
        base, ext = os.path.splitext(f)
        if ext.lower() not in ('.mp3', '.ogg', '.wav'):
            continue
        if not re.fullmatch(r'[a-z][a-z0-9_]*', base):
            print('WARNING: اسم الملف غير صالح لأندرويد (حروف إنجليزية صغيرة وأرقام و _ فقط):', f)
            continue
        if base in seen:
            print('WARNING: تكرار الاسم', base, '- تم تجاهل', f)
            continue
        seen[base] = f
        os.makedirs(raw_dir, exist_ok=True)
        shutil.copy2(os.path.join(adhan_src, f), os.path.join(raw_dir, base + ext.lower()))
        copied.append(f)
print('adhan files -> res/raw:', copied if copied else 'none (default notification sound will be used)')

# ---------------------------------------------------------------- 5) Gradle desugaring
kts = os.path.join(APP, 'build.gradle.kts')
groovy = os.path.join(APP, 'build.gradle')
if os.path.exists(kts):
    g = read(kts)
    if 'isCoreLibraryDesugaringEnabled' not in g:
        g, n = re.subn(r'(compileOptions\s*\{)', r'\1\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
        if n == 0:
            fail('تعذر العثور على compileOptions في build.gradle.kts')
        g += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        write(kts, g)
    print('gradle (kts) desugaring ok')
elif os.path.exists(groovy):
    g = read(groovy)
    if 'coreLibraryDesugaringEnabled' not in g:
        g, n = re.subn(r'(compileOptions\s*\{)', r'\1\n        coreLibraryDesugaringEnabled true', g, count=1)
        if n == 0:
            fail('تعذر العثور على compileOptions في build.gradle')
        g += "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        write(groovy, g)
    print('gradle (groovy) desugaring ok')
else:
    fail('لم أجد build.gradle(.kts) داخل android/app')

# ---------------------------------------------------------------- 6) توقيع Release بمفتاح ثابت (اختياري أثناء اختبارات الفرع)
def configure_release_signing(path, kotlin_dsl):
    g = read(path)
    if 'SAKINA_RELEASE_SIGNING' in g:
        print('persistent release signing already configured')
        return
    if kotlin_dsl:
        # Kotlin DSL's generated "java" extension shadows the java package name;
        # use explicit imports so Properties/FileInputStream resolve reliably.
        imports = 'import java.util.Properties\nimport java.io.FileInputStream\n'
        if 'import java.util.Properties' not in g:
            g = imports + g
    props = '''
// SAKINA_RELEASE_SIGNING: load the persistent upload key from android/key.properties
val sakinaKeystoreProperties = Properties()
val sakinaKeystorePropertiesFile = rootProject.file("key.properties")
if (sakinaKeystorePropertiesFile.exists()) {
    sakinaKeystoreProperties.load(FileInputStream(sakinaKeystorePropertiesFile))
}
''' if kotlin_dsl else '''
// SAKINA_RELEASE_SIGNING: load the persistent upload key from android/key.properties
def sakinaKeystoreProperties = new Properties()
def sakinaKeystorePropertiesFile = rootProject.file('key.properties')
if (sakinaKeystorePropertiesFile.exists()) {
    sakinaKeystoreProperties.load(new FileInputStream(sakinaKeystorePropertiesFile))
}
'''
    android_open = re.search(r'^android\s*\{', g, re.M)
    if not android_open:
        fail('تعذر العثور على android block لإعداد توقيع الإصدار')
    g = g[:android_open.start()] + props + '\n' + g[android_open.start():]
    android_open = re.search(r'^android\s*\{', g, re.M)
    if kotlin_dsl:
        signing = '''
    signingConfigs {
        create("sakinaRelease") {
            if (sakinaKeystorePropertiesFile.exists()) {
                storeFile = file(sakinaKeystoreProperties["storeFile"] as String)
                storeType = sakinaKeystoreProperties["storeType"] as String
                storePassword = sakinaKeystoreProperties["storePassword"] as String
                keyAlias = sakinaKeystoreProperties["keyAlias"] as String
                keyPassword = sakinaKeystoreProperties["keyPassword"] as String
            } else {
                initWith(getByName("debug"))
            }
        }
    }
'''
        g = g[:android_open.end()] + signing + g[android_open.end():]
        g, n = re.subn(
            r"signingConfig\s*=\s*signingConfigs\.getByName\(['\"]debug['\"]\)",
            'signingConfig = signingConfigs.getByName("sakinaRelease")', g, count=1)
    else:
        signing = '''
    signingConfigs {
        sakinaRelease {
            if (sakinaKeystorePropertiesFile.exists()) {
                storeFile file(sakinaKeystoreProperties['storeFile'])
                storeType sakinaKeystoreProperties['storeType']
                storePassword sakinaKeystoreProperties['storePassword']
                keyAlias sakinaKeystoreProperties['keyAlias']
                keyPassword sakinaKeystoreProperties['keyPassword']
            } else {
                initWith signingConfigs.debug
            }
        }
    }
'''
        g = g[:android_open.end()] + signing + g[android_open.end():]
        g, n = re.subn(
            r"signingConfig\s*=\s*signingConfigs\.debug",
            'signingConfig signingConfigs.sakinaRelease', g, count=1)
    if n == 0:
        fail('تعذر ربط buildTypes.release بمفتاح SAKINA الثابت')
    write(path, g)
    print('persistent release signing configured (debug fallback only for branch validation)')


if os.path.exists(kts):
    configure_release_signing(kts, True)
else:
    configure_release_signing(groovy, False)

# ---------------------------------------------------------------- 6) تعطيل R8/التصغير في الإصدار
# مكتبات الإشعارات والصوت تستعمل reflection/Gson وقد تتعطل أو تغلق التطبيق مع R8.
def disable_shrink(path, groovy_syntax):
    g = read(path)
    if 'SAKINA_NOSHRINK' in g:
        return
    i = g.find('buildTypes')
    m = re.compile(r'release\s*\{').search(g, i if i >= 0 else 0)
    if not m:
        print('WARNING: لم أجد release داخل buildTypes، لم يُعطَّل التصغير')
        return
    if groovy_syntax:
        add = '\n            // SAKINA_NOSHRINK\n            minifyEnabled false\n            shrinkResources false'
    else:
        add = '\n            // SAKINA_NOSHRINK\n            isMinifyEnabled = false\n            isShrinkResources = false'
    g = g[:m.end()] + add + g[m.end():]
    write(path, g)
    print('release shrink disabled')

if os.path.exists(kts):
    disable_shrink(kts, False)
else:
    disable_shrink(groovy, True)

# ---------------------------------------------------------------- 7) رفع compileSdk لمكتبات الأندرويد القديمة
# بعض المكتبات (file_picker, share_plus, ...) مضبوطة على SDK 34 بينما مكتبات النظام الأحدث
# تشترط 36 فيفشل البناء في checkReleaseAarMetadata. نرفعها لـ 36 دون المساس بكودها.
KTS_SNIPPET = """
// SAKINA_COMPILESDK: يرفع compileSdk للمكتبات إلى 36 على الأقل (يجب أن يسبق evaluationDependsOn)
subprojects {
    if (name != "app") {
        val raise: (Project) -> Unit = { p ->
            val ext = p.extensions.findByName("android")
            if (ext != null) {
                try {
                    val getter = ext.javaClass.methods.firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
                    val current = try { getter?.also { it.isAccessible = true }?.invoke(ext) as? Int } catch (e: Exception) { null }
                    if (current == null || current < 36) {
                        val setter = ext.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                            ?: ext.javaClass.methods.firstOrNull {
                                it.name == "compileSdkVersion" && it.parameterCount == 1 && it.parameterTypes[0] == Int::class.javaPrimitiveType
                            }
                        if (setter != null) {
                            setter.isAccessible = true
                            setter.invoke(ext, 36)
                            println("SAKINA: compileSdk -> 36 for " + p.name)
                        }
                    }
                } catch (e: Exception) {
                    println("SAKINA: could not raise compileSdk for " + p.name + ": " + e)
                }
            }
        }
        if (state.executed) raise(this) else afterEvaluate { raise(this) }
    }
}
"""

GROOVY_SNIPPET = """
// SAKINA_COMPILESDK
subprojects { sp ->
    if (sp.name != 'app') {
        def raise = { p ->
            if (p.hasProperty('android')) {
                try {
                    def cur = p.android.compileSdkVersion
                    p.android.compileSdkVersion 36
                    println "SAKINA: compileSdk -> 36 for " + p.name
                } catch (Throwable t) {
                    println "SAKINA: could not raise compileSdk for " + p.name + ": " + t
                }
            }
        }
        if (sp.state.executed) { raise(sp) } else { sp.afterEvaluate { raise(sp) } }
    }
}
"""

def patch_root(path, snippet):
    g = read(path)
    if 'SAKINA_COMPILESDK' in g:
        print('root build file already patched')
        return
    m = re.search(r'^\s*subprojects\s*\{', g, re.M)
    if m:
        g = g[:m.start()] + snippet + '\n' + g[m.start():]
    else:
        g = g + '\n' + snippet
    write(path, g)
    print('root build file patched (compileSdk floor = 36)')

root_kts = os.path.join(ROOT, 'android', 'build.gradle.kts')
root_groovy = os.path.join(ROOT, 'android', 'build.gradle')
if os.path.exists(root_kts):
    patch_root(root_kts, KTS_SNIPPET)
elif os.path.exists(root_groovy):
    patch_root(root_groovy, GROOVY_SNIPPET)
else:
    print('WARNING: لم أجد android/build.gradle(.kts) الجذري')

print('DONE')
