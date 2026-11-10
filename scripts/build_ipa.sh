#!/bin/bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
mkdir -p build dist
swift scripts/generate_icon.swift Conjugation/Assets.xcassets/AppIcon.appiconset/AppIcon.png
swift scripts/validate_icon.swift Conjugation/Assets.xcassets/AppIcon.appiconset/AppIcon.png
python3 scripts/generate_lexicon.py
python3 scripts/generate_project.py

xcodebuild \
  -project Conjugation.xcodeproj \
  -scheme Conjugation \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/Device \
  -archivePath build/Conjugation.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive > build/archive.log 2>&1

TASK_APP="build/Conjugation.xcarchive/Products/Applications/Conjugation.app"
swift scripts/validate_icon.swift "$TASK_APP"/AppIcon*.png

STAGING="$(mktemp -d -t conjugation-ipa)"
trap 'rm -rf "$STAGING"' EXIT
mkdir "$STAGING/Payload"
ditto build/Conjugation.xcarchive/Products/Applications/Conjugation.app "$STAGING/Payload/Conjugation.app"
# An unsigned device-arm64 app, ready for the user's signing tool.
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$STAGING/Payload" dist/MyConju-unsigned.ipa
python3 scripts/verify_ipa.py dist/MyConju-unsigned.ipa
cp dist/MyConju-unsigned.ipa dist/MyConju-SpeechFix.ipa
(cd dist && shasum -a 256 MyConju-unsigned.ipa MyConju-SpeechFix.ipa > MyConju-iOS-SHA256SUMS.txt)
echo "Built: $TASK_ROOT/dist/MyConju-unsigned.ipa"
