# Changed files

- `.github/workflows/build.yml`

Swift Package Manager / DerivedData fix for Xcode 26.x:
- Clean build state before package resolution.
- Uses explicit `DERIVED_DATA` and `SOURCE_PACKAGES` paths.
- Resolves packages into the same checkout directory used by build settings and compilation.
- Does not delete DerivedData after package resolution.
- Preserves the repository's `Package.resolved` instead of deleting it during CI.
