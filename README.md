# derick247

Flutter app for the Derick247 commerce platform.

## Android App Links / iOS Universal Links

Deep links need to pass OS verification so users are not forced to toggle “Open supported links” manually.

### Android

1. **Manifest intent filters** – already configured in `android/app/src/main/AndroidManifest.xml` for `derick247://`, `https://derick247.com`, and `https://www.derick247.com`.
2. **Digital Asset Links** – host `web/.well-known/assetlinks.json` (same file is mirrored in `backend-config/assetlinks.json` for reference) at `https://derick247.com/.well-known/assetlinks.json`.
3. **Release signing** – update `android/app/build.gradle.kts` with your release keystore and set `applicationId` to the production package (e.g., `com.derick247.app`). Use the release keystore SHA-256 fingerprint inside the assetlinks file.
4. **Verification** – after publishing the updated file and installing a build signed with the matching certificate, Android will auto-verify during install. Users won’t need to visit App Info.

### iOS

1. Configure associated domains in `ios/Runner/Runner.entitlements` (e.g., `applinks:derick247.com`).
2. Host `backend-config/apple-app-site-association` at `https://derick247.com/.well-known/apple-app-site-association` (no extension, served as `application/json`).
3. Archive with the same bundle identifier referenced in the AASA file.

### Testing tips

- Use `adb shell am start -a android.intent.action.VIEW -d "https://derick247.com/path"` to confirm Android link handling.
- Use `adb shell dumpsys package domain-preferred-apps` to inspect Android’s verification state.
- On iOS, use `xcrun simctl openurl booted https://derick247.com/...` in Simulator or the Notes tap link workflow on device.
