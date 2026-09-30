# Changed files

- `.github/workflows/build.yml`

SwiftPM/Xcode 26.2 fix:
- Pins CI back to Xcode 26.2.0.
- Cleans the package checkout and DerivedData before dependency resolution.
- Temporarily removes the workspace `Package.resolved` only during CI resolution so stale checkout-state references cannot point at missing directories such as `TextTable`.
- Resolves a fresh package graph into the dedicated checkout directory.
- Verifies that SwiftPM actually created package checkouts before compilation.
- Restores the repository's original `Package.resolved` after resolution.
- Keeps the same DerivedData/package directories for subsequent build steps.
- Does not delete the resolved package graph immediately before compilation.
