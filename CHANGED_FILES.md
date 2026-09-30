DELvEK upstream API + SwiftPM resolution update

Changed:
- .github/workflows/build.yml
  - Clears Xcode/SwiftPM caches completely.
  - Resolves packages into build/DerivedData explicitly.
  - Verifies the resulting checkout graph before compilation.
  - Emits package-resolution diagnostics for swift-crypto identity conflicts.

The project dependency graph itself was not duplicated or rewritten. SideSign/Minimuxer remain the upstream package references; the workflow now uses one clean DerivedData/SourcePackages graph for both resolution and build.
