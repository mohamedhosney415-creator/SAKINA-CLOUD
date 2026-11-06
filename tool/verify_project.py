#!/usr/bin/env python3
"""يتأكد أن كل ملفات المشروع موجودة قبل البناء، ويُظهر بوضوح أي ملف ناقص."""
import glob
import os
import re
import sys

ROOT = os.getcwd()
required = [
    'pubspec.yaml',
    'lib/main.dart', 'lib/app.dart',
    'tool/patch_android.py',
    'android_native/kotlin/SakinaWidgetProvider.kt',
    'android_native/res/layout/sakina_widget.xml',
    'android_native/res/xml/sakina_widget_info.xml',
    'android_native/res/drawable/widget_bg.xml',
    'android_native/res/values/sakina_widget_styles.xml',
    'android_native/res/mipmap-mdpi/ic_launcher.png',
    'android_native/res/mipmap-hdpi/ic_launcher.png',
    'android_native/res/mipmap-xhdpi/ic_launcher.png',
    'android_native/res/mipmap-xxhdpi/ic_launcher.png',
    'android_native/res/mipmap-xxxhdpi/ic_launcher.png',
    'assets/adhan/README.txt',
    'assets/google_fonts/README.txt',
]
missing = [f for f in required if not os.path.isfile(os.path.join(ROOT, f))]

n = 0
for f in glob.glob(os.path.join(ROOT, 'lib', '**', '*.dart'), recursive=True):
    n += 1
    src = open(f, encoding='utf-8').read()
    for m in re.finditer(r"(?:import|export)\s+'([^':]+\.dart)'", src):
        target = os.path.normpath(os.path.join(os.path.dirname(f), m.group(1)))
        if not os.path.isfile(target):
            missing.append('%s  (مستورد من %s)' % (os.path.relpath(target, ROOT), os.path.relpath(f, ROOT)))

for d in ('assets/adhan', 'assets/google_fonts'):
    p = os.path.join(ROOT, d)
    if not os.path.isdir(p) or not os.listdir(p):
        missing.append(d + '/  (مجلد فارغ أو غير موجود — GitHub لا يرفع المجلدات الفارغة)')

if missing:
    print('ملفات ناقصة في المشروع:')
    for m in missing:
        print('  -', m)
    sys.exit(1)
print('OK: المشروع كامل (%d ملف Dart)' % n)
