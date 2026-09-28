#!/bin/bash 
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

WORK="$ROOT/build/StikJITSource"
WORK_BUILD="$WORK/build"
ARCHIVE="$WORK_BUILD/StikJIT.xcarchive"

OUT_DIR="$ROOT/build/StikJIT"
OUT="$OUT_DIR/StikJIT.xcframework"

TAG="1.8.0"
REPO="https://github.com/StikDebug/StikJIT.git"

echo "========================================"
echo "StikJIT build"
echo "========================================"

echo
echo "Xcode:"
xcodebuild -version

echo
echo "Swift:"
swift --version

# =========================================================
# CLEAN
# =========================================================

echo
echo "Cleaning previous StikJIT build..."

rm -rf "$WORK"
rm -rf "$OUT_DIR"

mkdir -p "$OUT_DIR"

# =========================================================
# FETCH STIKJIT
# =========================================================

echo
echo "========================================"
echo "Fetching StikJIT $TAG"
echo "========================================"

git clone \
  --depth 1 \
  --branch "$TAG" \
  "$REPO" \
  "$WORK"

cd "$WORK"

echo
echo "StikJIT revision:"
git rev-parse HEAD

# =========================================================
# XCODEGEN
# =========================================================

if ! command -v xcodegen >/dev/null 2>&1; then
  echo
  echo "Installing XcodeGen..."
  brew install xcodegen
fi

echo
echo "XcodeGen:"
xcodegen --version

echo
echo "Generating Xcode project..."

xcodegen generate

if [ ! -f "$WORK/StikJIT.xcodeproj/project.pbxproj" ]; then
  echo "::error::StikJIT.xcodeproj was not generated."
  exit 1
fi

# =========================================================
# ARCHIVE
# =========================================================

echo
echo "========================================"
echo "Archiving StikJIT"
echo "========================================"

rm -rf "$WORK_BUILD"

mkdir -p "$WORK_BUILD"

xcodebuild archive \
  -project "$WORK/StikJIT.xcodeproj" \
  -scheme StikJIT \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

# =========================================================
# VERIFY ARCHIVE
# =========================================================

echo
echo "========================================"
echo "Inspecting StikJIT archive"
echo "========================================"

if [ ! -d "$ARCHIVE" ]; then
  echo "::error::StikJIT archive was not created:"
  echo "$ARCHIVE"
  exit 1
fi

echo
echo "Archive contents:"

find "$ARCHIVE" \
  -maxdepth 10 \
  -print \
  2>/dev/null \
  | head -500

# =========================================================
# FIND FRAMEWORK
#
# Do NOT assume:
#
# Products/Library/Frameworks/StikJIT.framework
#
# Xcode can place the framework differently depending on
# the generated project configuration.
# =========================================================

echo
echo "========================================"
echo "Locating StikJIT.framework"
echo "========================================"

FRAMEWORK="$(
  find "$ARCHIVE" \
    -type d \
    -name 'StikJIT.framework' \
    -print \
    -quit \
    2>/dev/null || true
)"

if [ -z "$FRAMEWORK" ]; then
  echo "::error::StikJIT.framework was not found in archive."

  echo
  echo "Framework-like products:"
  find "$ARCHIVE" \
    -type d \
    \( \
      -name '*.framework' \
      -o -name '*.xcframework' \
    \) \
    -print \
    2>/dev/null || true

  exit 1
fi

echo
echo "StikJIT.framework:"
echo "$FRAMEWORK"

# =========================================================
# FRAMEWORK VALIDATION
# =========================================================

echo
echo "========================================"
echo "Validating framework"
echo "========================================"

if [ ! -d "$FRAMEWORK" ]; then
  echo "::error::Framework directory does not exist."
  exit 1
fi

BINARY="$FRAMEWORK/StikJIT"

if [ ! -f "$BINARY" ]; then
  echo "::error::StikJIT framework binary was not found:"
  echo "$BINARY"

  echo
  echo "Framework contents:"
  find "$FRAMEWORK" \
    -maxdepth 5 \
    -print \
    2>/dev/null || true

  exit 1
fi

# Info.plist can be generated differently by the project.
# Do not fail merely because the bundle has no physical
# Info.plist at the expected path if the framework is otherwise
# a valid framework.

if [ -f "$FRAMEWORK/Info.plist" ]; then
  echo "Framework Info.plist found."
else
  echo "Framework Info.plist is not present at the standard path."
  echo "Continuing because the framework binary exists."
fi

echo
echo "Framework binary:"
file "$BINARY"

echo
echo "Framework architecture:"
lipo -info "$BINARY" 2>/dev/null || true

# =========================================================
# CREATE XCFRAMEWORK
# =========================================================

echo
echo "========================================"
echo "Creating StikJIT XCFramework"
echo "========================================"

rm -rf "$OUT"

xcodebuild -create-xcframework \
  -framework "$FRAMEWORK" \
  -output "$OUT"

# =========================================================
# VERIFY XCFRAMEWORK
# =========================================================

echo
echo "========================================"
echo "Verifying XCFramework"
echo "========================================"

if [ ! -d "$OUT" ]; then
  echo "::error::StikJIT.xcframework was not created."
  exit 1
fi

if [ ! -f "$OUT/Info.plist" ]; then
  echo "::error::StikJIT.xcframework is missing Info.plist."
  exit 1
fi

echo
echo "XCFramework:"
echo "$OUT"

echo
echo "XCFramework contents:"

find "$OUT" \
  -maxdepth 6 \
  -print \
  2>/dev/null

# =========================================================
# SWIFT INTERFACE CHECK
# =========================================================

echo
echo "========================================"
echo "Checking Swift interfaces"
echo "========================================"

INTERFACES="$(
  find "$OUT" \
    -type f \
    -name '*.swiftinterface' \
    -print \
    2>/dev/null || true
)"

if [ -n "$INTERFACES" ]; then

  echo "Swift interfaces found:"
  echo "$INTERFACES"

  while IFS= read -r FILE; do
    [ -n "$FILE" ] || continue

    echo
    echo "Inspecting:"
    echo "$FILE"

    if grep -nE \
      'StikJIT\.(DDIPaths|DeveloperDiskImageService|StikJIT)' \
      "$FILE" \
      >/dev/null 2>&1; then

      echo "Normalizing problematic StikJIT module references."

      cp "$FILE" "$FILE.before-normalization"

      sed -i '' \
        -e 's/StikJIT\.DDIPaths/DDIPaths/g' \
        -e 's/StikJIT\.DeveloperDiskImageService/DeveloperDiskImageService/g' \
        -e 's/StikJIT\.StikJIT/StikJIT/g' \
        "$FILE"
    fi

  done <<< "$INTERFACES"

else
  echo "No textual Swift interfaces found."
fi

# =========================================================
# FINAL VALIDATION
# =========================================================

echo
echo "========================================"
echo "Final StikJIT validation"
echo "========================================"

test -d "$OUT"
test -f "$OUT/Info.plist"

if grep -R \
  -nE \
  'StikJIT\.(DDIPaths|DeveloperDiskImageService|StikJIT)' \
  "$OUT" \
  --include='*.swiftinterface' \
  >/dev/null 2>&1; then

  echo "::error::Invalid StikJIT-qualified references remain."

  grep -R \
    -nE \
    'StikJIT\.(DDIPaths|DeveloperDiskImageService|StikJIT)' \
    "$OUT" \
    --include='*.swiftinterface' \
    || true

  exit 1
fi

echo
echo "StikJIT XCFramework successfully generated:"
echo "$OUT"

# =========================================================
# REMOVE TEMPORARY SOURCE
# =========================================================

echo
echo "Removing temporary StikJIT source..."

rm -rf "$WORK"

if [ -d "$WORK" ]; then
  echo "::error::Failed to remove StikJITSource."
  exit 1
fi

echo
echo "========================================"
echo "StikJIT build completed successfully"
echo "========================================"
