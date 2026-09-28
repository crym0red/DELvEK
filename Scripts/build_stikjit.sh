#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/StikJITSource"
OUT="$ROOT/build/StikJIT/StikJIT.xcframework"
TAG="1.8.0"
rm -rf "$WORK" "$ROOT/build/StikJIT"
mkdir -p "$ROOT/build/StikJIT"
git clone --depth 1 --branch "$TAG" https://github.com/StikDebug/StikJIT.git "$WORK"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
cd "$WORK"
xcodegen generate
xcodebuild archive -scheme StikJIT -destination 'generic/platform=iOS' -archivePath build/StikJIT BUILD_LIBRARY_FOR_DISTRIBUTION=YES SKIP_INSTALL=NO
xcodebuild -create-xcframework \
  -framework build/StikJIT.xcarchive/Products/Library/Frameworks/StikJIT.framework \
  -output "$OUT"
test -f "$OUT/Info.plist"
