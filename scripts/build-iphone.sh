#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
xcodebuild -version | tee artifacts/xcode-version.log
mkdir -p build
swiftc ShoulderBack/MotivationLibrary.swift tests/MotivationLibraryTests.swift -o build/MotivationLibraryTests
build/MotivationLibraryTests 2>&1 | tee artifacts/motivation-tests.log

# iLoader on Windows signs this device build with the user's Apple account.
# No Apple credentials or signing certificates are sent to GitHub.
xcodebuild -project ShoulderBack.xcodeproj -scheme ShoulderBack \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build 2>&1 | tee artifacts/xcode-build.log

app="build/DerivedData/Build/Products/Release-iphoneos/ShoulderBack.app"
test -d "$app"
test -f "$app/ShoulderBack"
test -f "$app/Plan.json"
test -f "$app/Assets.car"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist"
python3 - "$app" <<'PY'
import pathlib, plistlib
app = pathlib.Path(__import__('sys').argv[1])
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleDisplayName'] == '训练', info
assert info['CFBundleIdentifier'] == 'com.example.ShoulderBack', info
assert info['CFBundleShortVersionString'] == '1.1.1', info
assert info['CFBundleVersion'] == '3', info
primary = info['CFBundleIcons']['CFBundlePrimaryIcon']
assert primary['CFBundleIconName'] == 'AppIcon', primary
assert primary['CFBundleIconFiles'], primary
for icon in primary['CFBundleIconFiles']:
    assert list(app.glob(icon + '*.png')), icon
print('PASS: app name, version, bundle ID and packaged AppIcon')
PY
lipo -archs "$app/ShoulderBack" | grep -q arm64

# mktemp keeps repeated local runs isolated without deleting existing data.
stage=$(mktemp -d "$PWD/build/ipa-stage.XXXXXX")
mkdir -p "$stage/Payload"
ditto "$app" "$stage/Payload/ShoulderBack.app"
ipa="$PWD/artifacts/ShoulderBack-unsigned.ipa"
(cd "$stage" && zip -qry "$ipa" Payload)
unzip -t "$ipa"
echo "IPA created: $ipa (unsigned; sign with iLoader before installation)"
