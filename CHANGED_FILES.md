# SwiftPM build fix

Updated `.github/workflows/build.yml`.

The diagnostic showed package resolution succeeded, then the build step deleted the exact `build/DerivedData` directory containing that resolved graph. Xcode 26.2 subsequently attempted to resolve/open the same packages again and encountered missing checkout containers, including GSACryptoKit and libdeflate.

This patch keeps the resolved DerivedData for the build and makes `-showBuildSettings` use the same DerivedData path.
