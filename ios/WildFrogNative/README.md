# WildFrog Native iOS Draft

This is the active SwiftUI-native WildFrog app.

Current screens:

- `HomeMapListView`: map/list/search/filter home screen
- `MountainDetailView`: mountain detail, record stats, certificate preview
- `CheckInCameraView`: GPS + camera/photo proof flow with watermark-style overlay
- `RecordsCalendarView`: photo-calendar check-in history

Run a local compile check:

```bash
cd ios/WildFrogNative
swift build
```

Build the generated iOS app project:

```bash
xcodebuild -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/WildFrogNative/.build/xcodeproj-derived \
  build
```

Notes:

- The current package is a compileable native SwiftUI foundation and now also includes a generated Xcode app project.
- The legacy static web prototype is archived under `archive/web-preview-draft-20260608/` and should not be used for current UI redesign or implementation decisions.
- GPS permissions, live camera capture, MapKit clustering, and real photo export are intentionally left for the next native phase.
