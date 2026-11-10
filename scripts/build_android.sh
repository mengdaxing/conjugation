#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Prefer a JDK supported by both Gradle and the Android plugin.
if [[ -z "${JAVA_HOME:-}" ]]; then
    for candidate in /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
        if [[ -x "$candidate/bin/java" ]]; then export JAVA_HOME="$candidate"; break; fi
    done
fi
if [[ -z "${ANDROID_HOME:-}" ]]; then
    for candidate in "$HOME/Library/Android/sdk" /opt/homebrew/share/android-commandlinetools; do
        if [[ -d "$candidate/platform-tools" ]]; then export ANDROID_HOME="$candidate"; break; fi
    done
fi
if [[ -z "${ANDROID_NDK_HOME:-}" && -d "$HOME/Library/Developer/SwiftAndroid/ndk-r30-arm64" ]]; then
    export ANDROID_NDK_HOME="$HOME/Library/Developer/SwiftAndroid/ndk-r30-arm64"
fi
export PATH="${JAVA_HOME:+$JAVA_HOME/bin:}/opt/homebrew/bin:$PATH"
export SKIP_COMMAND_OVERRIDE="$PWD/scripts/skip_with_ndk.sh"
command -v skip >/dev/null || { echo 'Install Skip with: brew install skip'; exit 1; }

configuration="${1:-release}"
case "$configuration" in debug|release) ;; *) echo 'Usage: bash scripts/build_android.sh [debug|release]'; exit 2;; esac
if [[ "$configuration" == release ]]; then
    python3 scripts/create_android_keystore.py
fi
mkdir -p build dist
swift scripts/generate_icon.swift --android
skip export "--$configuration" --no-ios --arch aarch64 --no-export-project --dir "build/android-$configuration" 2>&1 | tee "build/android-$configuration.log"
if [[ "$configuration" == release ]]; then
    source_apk=build/android-release/Conjugation-release.apk
else
    source_apk=build/android-debug/Conjugation-debug.apk
fi
if [[ ! -f "$source_apk" ]]; then
    echo "Expected APK was not generated: $source_apk"
    exit 1
fi
if [[ "$configuration" == release ]]; then
    output_apk=dist/MyConju.apk
else
    output_apk=dist/MyConju-debug.apk
fi
cp "$source_apk" "$output_apk"
"$ANDROID_HOME/build-tools/$(ls "$ANDROID_HOME/build-tools" | sort -V | tail -n 1)/apksigner" verify --verbose "$output_apk"
python3 scripts/verify_apk.py "$output_apk"
(cd dist && shasum -a 256 "$(basename "$output_apk")" > "MyConju-Android-$configuration-SHA256SUMS.txt")
