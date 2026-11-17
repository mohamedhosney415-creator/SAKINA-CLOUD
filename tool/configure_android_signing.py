#!/usr/bin/env python3
"""Configure a persistent Android release signing key from GitHub Actions secrets."""
import base64
import os
import subprocess
from pathlib import Path

root = Path.cwd()
android = root / "android"
app = android / "app"
encoded = "".join(os.environ.get("SAKINA_KEYSTORE_BASE64", "").split())
store_password = os.environ.get("SAKINA_STORE_PASSWORD", "")
key_alias = os.environ.get("SAKINA_KEY_ALIAS", "")
key_password = os.environ.get("SAKINA_KEY_PASSWORD", "")

if not all((encoded, store_password, key_alias, key_password)):
    raise SystemExit("ERROR: Android release signing secrets are missing.")

try:
    keystore_bytes = base64.b64decode(encoded, validate=True)
except Exception as exc:
    raise SystemExit("ERROR: SAKINA_KEYSTORE_BASE64 is not valid base64.") from exc

if len(keystore_bytes) < 256:
    raise SystemExit("ERROR: decoded Android keystore is unexpectedly small.")

app.mkdir(parents=True, exist_ok=True)
keystore_path = app / "sakina-release.jks"
keystore_path.write_bytes(keystore_bytes)

check = subprocess.run(
    ["keytool", "-list", "-keystore", str(keystore_path),
     "-storepass", store_password, "-alias", key_alias],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.PIPE,
    text=True,
)
if check.returncode != 0:
    keystore_path.unlink(missing_ok=True)
    raise SystemExit("ERROR: Android keystore/password/alias validation failed.")

def prop_escape(value: str) -> str:
    return (value.replace("\\", "\\\\")
                 .replace("\n", "\\n")
                 .replace("\r", "\\r")
                 .replace(":", "\\:")
                 .replace("=", "\\="))

properties = (
    "storePassword=" + prop_escape(store_password) + "\n" +
    "keyPassword=" + prop_escape(key_password) + "\n" +
    "keyAlias=" + prop_escape(key_alias) + "\n" +
    "storeFile=sakina-release.jks\n"
    "storeType=JKS\n"
)
(android / "key.properties").write_text(properties, encoding="utf-8")

kts = app / "build.gradle.kts"
if not kts.exists():
    raise SystemExit("ERROR: android/app/build.gradle.kts was not generated.")

source = kts.read_text(encoding="utf-8")
if "SAKINA_RELEASE_SIGNING" in source:
    print("Android release signing already configured.")
    raise SystemExit(0)

source = "import java.util.Properties\nimport java.io.FileInputStream\n" + source

plugins_start = source.find("plugins {")
if plugins_start < 0:
    raise SystemExit("ERROR: Could not locate the Gradle plugins block.")
plugins_open = source.find("{", plugins_start)
plugins_end = source.find("}", plugins_open)
if plugins_open < 0 or plugins_end < 0:
    raise SystemExit("ERROR: Could not parse the Gradle plugins block.")

loader = """
// SAKINA_RELEASE_SIGNING
val sakinaKeystoreProperties = Properties()
val sakinaKeystoreFile = rootProject.file("key.properties")
if (!sakinaKeystoreFile.exists()) {
    throw GradleException("SAKINA release key.properties is missing")
}
sakinaKeystoreProperties.load(FileInputStream(sakinaKeystoreFile))
"""
source = source[:plugins_end + 1] + "\n" + loader + source[plugins_end + 1:]

android_start = source.find("android {")
if android_start < 0:
    raise SystemExit("ERROR: Could not locate the Android Gradle block.")
android_open = source.find("{", android_start)

signing = """
    signingConfigs {
        create("release") {
            keyAlias = sakinaKeystoreProperties["keyAlias"] as String
            keyPassword = sakinaKeystoreProperties["keyPassword"] as String
            storeFile = file(sakinaKeystoreProperties["storeFile"] as String)
            storeType = sakinaKeystoreProperties["storeType"] as String
            storePassword = sakinaKeystoreProperties["storePassword"] as String
        }
    }
"""
source = source[:android_open + 1] + signing + source[android_open + 1:]

build_types = source.find("buildTypes {")
release_start = source.find("release {", build_types)
if build_types < 0 or release_start < 0:
    raise SystemExit("ERROR: Could not locate release build type.")
release_end = release_start + len("release {")
debug_line = 'signingConfig = signingConfigs.getByName("debug")'
pos = source.find(debug_line, release_end)
if pos >= 0:
    source = source[:pos] + 'signingConfig = signingConfigs.getByName("release")' + source[pos + len(debug_line):]
else:
    source = (source[:release_end] +
              '\n            signingConfig = signingConfigs.getByName("release")' +
              source[release_end:])

kts.write_text(source, encoding="utf-8")
print("Stable Android release signing configured and validated; secret values were not printed.")
