# DELvEK SwiftPM build fix

This archive updates the GitHub Actions build workflow to prevent the Xcode/SwiftPM checkout-container failures seen during package resolution.

Changes:
- Keeps DerivedData and SwiftPM source checkouts in separate locations.
- Uses `$RUNNER_TEMP/DELvEK-SPM/SourcePackages` for SwiftPM checkouts instead of placing checkouts inside the repository's `build` directory.
- Passes the same `-clonedSourcePackagesDirPath` to package resolution, build-settings inspection, and the final build.
- Keeps the resolved DerivedData directory intact between resolution and compilation.
- Disables automatic package re-resolution during the final build so Xcode uses the graph that was explicitly resolved.
- Moves the StikJIT build after the clean-build step so the clean step cannot delete generated StikJIT output.

Primary affected file:
- `.github/workflows/build.yml`
