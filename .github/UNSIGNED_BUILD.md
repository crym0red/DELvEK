# DELvEK unsigned GitHub build

The `build.yml` / `build-unsigned.yml` workflow compiles the iOS app with signing disabled:

- `CODE_SIGNING_ALLOWED=NO`
- `CODE_SIGNING_REQUIRED=NO`
- `CODE_SIGN_IDENTITY=""`
- `AD_HOC_CODE_SIGNING_ALLOWED=NO`

The workflow produces `DELvEK-unsigned.ipa` as a GitHub Actions artifact.

An unsigned IPA is a build artifact for inspection or later signing. It is not directly installable on a stock iOS device without an appropriate signing process.
