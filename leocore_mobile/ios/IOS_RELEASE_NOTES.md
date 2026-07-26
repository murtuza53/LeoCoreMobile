# LeoCore ERP — iOS / App Store setup

This project is configured for App Store submission. The steps below can only be
done on a **Mac with Xcode** (signing, pods, archive). Everything else is done.

## Already configured (in the repo)
- **Bundle identifier:** `sek.leocore.erp` (Runner target, Debug + Release)
- **Display name:** LeoCore ERP
- **Version:** driven by `pubspec.yaml` (`2.6.0+7`) → `CFBundleShortVersionString` / `CFBundleVersion`
- **Deployment target:** iOS 13.0 (Runner + Podfile + AppFrameworkInfo)
- **App icons:** generated, 1024×1024 is RGB with **no alpha** (App Store requirement)
- **Privacy usage strings** in `Runner/Info.plist`:
  - `NSCameraUsageDescription` — barcode scanning + product photos
  - `NSPhotoLibraryUsageDescription` — choosing a product photo
  - `NSFaceIDUsageDescription` — biometric unlock
- **`LSApplicationQueriesSchemes`** — tel / whatsapp / maps etc. for Call/WhatsApp/Navigate
- **`CFBundleLocalizations`** — en, ar (Arabic RTL supported)
- **`ITSAppUsesNonExemptEncryption = false`** — standard TLS only, skips the export-compliance prompt
- **Podfile** — pins iOS 13.0 for all pods

## On the Mac — one time
```bash
cd leocore_mobile
flutter pub get          # regenerates ios/Flutter/Generated.xcconfig for this machine
cd ios && pod install    # installs plugin pods (uses the committed Podfile)
open Runner.xcworkspace   # ALWAYS the .xcworkspace, never .xcodeproj
```
> `ios/Flutter/Generated.xcconfig` in the repo was generated on Windows and shows an
> old version — `flutter pub get` on the Mac overwrites it. This is expected.

## In Xcode — signing (only thing left to decide)
1. Select the **Runner** target → **Signing & Capabilities**.
2. Set **Team** to your Apple Developer account (SEK Solution).
3. Leave **Automatically manage signing** on — it creates the provisioning profile
   for `sek.leocore.erp`. (Register that bundle ID in App Store Connect first if new.)

No special capabilities/entitlements are required (no push, no App Groups, no
in-app purchase). Face ID, camera and photos work from the Info.plist strings alone.

## Build & upload
```bash
flutter build ipa --release
# → build/ios/archive/Runner.xcarchive  and  build/ios/ipa/*.ipa
```
Then upload with **Xcode Organizer** or **Transporter**, or archive from Xcode
(Product → Archive → Distribute App → App Store Connect).

## App Store Connect metadata to have ready
- Same screenshots concept as Play, but iPhone 6.7" (1290×2796) and 6.5" sizes.
- Privacy "Nutrition Label": app collects business data you type; camera/photos are
  used **on-device** for scanning/attaching and are not used for tracking.
- Support URL + privacy-policy URL (reuse the Play privacy policy).

## Notes / open items
- **HTTPS only:** App Transport Security is left at Apple's secure default (no
  arbitrary loads). The app talks to the server over HTTPS. If any customer must
  point at a plain-HTTP on-prem server, that connection will be blocked until an
  ATS exception is added — tell us and we'll scope one narrowly.
- **Not yet run on a physical iPhone / simulator.** The Dart analyzes clean and the
  config is complete, but camera/Face ID/photo-picker behave differently on real iOS
  and should be smoke-tested once pods are installed.
- `in_app_update` is Android-only and is correctly absent from the iOS plugin
  registrant — update prompts simply don't run on iOS (the App Store handles updates).
