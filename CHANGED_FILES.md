# DELvEK SwiftPM/Xcode 26.2 fix

Updated:
- `.github/workflows/build.yml`

Changes:
- Remove the stale shared `Package.resolved` during CI package resolution.
- Preserve a copy for diagnostics.
- Use one explicit `build/SourcePackages` checkout directory.
- Pass the same `-clonedSourcePackagesDirPath` to resolve, build-settings, and build commands.
- Keep the existing clean DerivedData behavior without deleting the resolved package graph between resolution and compilation.
- This addresses the Xcode 26.2 errors involving missing `swift-crypto`/`Kingfisher` checkouts, duplicate package identities, and stale package containers.
