#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

WORK="$ROOT/build/StikJITSource"
STIKJIT_BUILD="$WORK/build"
ARCHIVE="$STIKJIT_BUILD/StikJIT.xcarchive"
FRAMEWORK="$ARCHIVE/Products/Library/Frameworks/StikJIT.framework"
OUT_DIR="$ROOT/build/StikJIT"
OUT="$OUT_DIR/StikJIT.xcframework"

TAG="1.8.0"
REPO="https://github.com/StikDebug/StikJIT.git"

echo "========================================"
echo "StikJIT build"
echo "========================================"

echo "Root:"
echo "$ROOT"

echo
echo "Xcode:"
xcodebuild -version

echo
echo "Swift:"
swift --version

# ---------------------------------------------------------
# Clean previous generated StikJIT state
# ---------------------------------------------------------

echo
echo "Cleaning previous StikJIT build..."

rm -rf "$WORK"
rm -rf "$OUT_DIR"

mkdir -p "$OUT_DIR"

# ---------------------------------------------------------
# Clone pinned StikJIT source
# ---------------------------------------------------------

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

# ---------------------------------------------------------
# XcodeGen
# ---------------------------------------------------------

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
  echo "::error::XcodeGen did not produce StikJIT.xcodeproj"
  exit 1
fi

# ---------------------------------------------------------
# Build configuration
# ---------------------------------------------------------

ARCHIVE_PARENT="$STIKJIT_BUILD"

rm -rf "$ARCHIVE_PARENT"
mkdir -p "$ARCHIVE_PARENT"

echo
echo "========================================"
echo "Archiving StikJIT"
echo "========================================"

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

# ---------------------------------------------------------
# Verify archive
# ---------------------------------------------------------

echo
echo "========================================"
echo "Verifying StikJIT archive"
echo "========================================"

if [ ! -d "$ARCHIVE" ]; then
  echo "::error::StikJIT archive was not created:"
  echo "$ARCHIVE"
  exit 1
fi

if [ ! -d "$FRAMEWORK" ]; then
  echo "::error::StikJIT.framework was not found:"
  echo "$FRAMEWORK"

  find "$ARCHIVE" \
    -maxdepth 8 \
    -print \
    2>/dev/null || true

  exit 1
fi

if [ ! -f "$FRAMEWORK/Info.plist" ]; then
  echo "::error::StikJIT.framework is missing Info.plist."
  exit 1
fi

echo "Framework:"
echo "$FRAMEWORK"

# ---------------------------------------------------------
# Create XCFramework
# ---------------------------------------------------------

echo
echo "========================================"
echo "Creating XCFramework"
echo "========================================"

rm -rf "$OUT"

xcodebuild -create-xcframework \
  -framework "$FRAMEWORK" \
  -output "$OUT"

# ---------------------------------------------------------
# Verify XCFramework
# ---------------------------------------------------------

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

# ---------------------------------------------------------
# Inspect Swift interfaces
# ---------------------------------------------------------

echo
echo "========================================"
echo "Checking Swift module interfaces"
echo "========================================"

INTERFACES="$(
  find "$OUT" \
    -type f \
    -name '*.swiftinterface' \
    -print \
    2>/dev/null || true
)"

if [ -n "$INTERFACES" ]; then
  echo "Found Swift interfaces:"
  echo "$INTERFACES"

  while IFS= read -r FILE; do
    [ -n "$FILE" ] || continue

    echo
    echo "Checking:"
    echo "$FILE"

    # The StikJIT module/type naming collision can produce
    # invalid references such as:
    #
    # StikJIT.DDIPaths
    # StikJIT.DeveloperDiskImageService
    # StikJIT.StikJIT
    #
    # Normalize only those generated references.

    if grep -nE \
      'StikJIT\.(DDIPaths|DeveloperDiskImageService|StikJIT)' \
      "$FILE" \
      >/dev/null 2>&1; then

      echo "Normalizing module-qualified StikJIT references..."

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

# ---------------------------------------------------------
# Final interface validation
# ---------------------------------------------------------

echo
echo "========================================"
echo "Final StikJIT validation"
echo "========================================"

if grep -R \
  -nE \
  'StikJIT\.(DDIPaths|DeveloperDiskImageService|StikJIT)' \
  "$OUT" \
  --include='*.swiftinterface' \
  >/dev/null 2>&1; then

  echo "::error::Invalid StikJIT-qualified references remain in Swift interfaces."

  grep -R \
    -nE \
    'StikJIT\.(DDIPaths|DeveloperDiskImageService|StikJIT)' \
    "$OUT" \
    --include='*.swiftinterface' \
    || true

  exit 1
fi

# ---------------------------------------------------------
# Display final framework metadata
# ---------------------------------------------------------

echo
echo "========================================"
echo "StikJIT XCFramework"
echo "========================================"

echo "Output:"
echo "$OUT"

echo
echo "Info.plist:"
/usr/libexec/PlistBuddy \
  -c 'Print :' \
  "$OUT/Info.plist"

echo
echo "Contents:"
find "$OUT" \
  -maxdepth 5 \
  -print

# ---------------------------------------------------------
# Remove source tree
#
# The main LiveContainer project synchronizes its build/
# directory. Keeping StikJITSource there can cause Xcode to
# discover generated JS/resources a second time.
# ---------------------------------------------------------

echo
echo "Removing temporary source tree..."

rm -rf "$WORK"

if [ -d "$WORK" ]; then
  echo "::error::Failed to remove temporary StikJIT source tree."
  exit 1
fi

# ---------------------------------------------------------
# Final existence check
# ---------------------------------------------------------

test -d "$OUT"
test -f "$OUT/Info.plist"

echo
echo "========================================"
echo "StikJIT build completed successfully"
echo "========================================"

echo "$OUT"
