# WildFrog Native iOS

WildFrog is now a native SwiftUI iOS app. Current development should start from:

- `ios/WildFrogNative/`
- `ios/WildFrogNative/Sources/WildFrogNative/`
- `ios/WildFrogNative/WildFrogNative.xcodeproj`

## Important

Do not use the old static web prototype for UI redesign or feature work.

The legacy web preview draft has been archived at:

```text
archive/web-preview-draft-20260608/
```

It is retained only for historical reference. New work should target the native iOS app on branch `wildfrog-recovery-20260607`.

## Build

```bash
xcodebuild -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'generic/platform=iOS Simulator' \
  build
```
