# Publishing Klondike Solitaire to the Google Play Store

## ⚠️ Back up your signing key — this is critical

Your app is signed with an **upload keystore**. If you lose it, **you can never
update the app on the Play Store again** (you'd have to publish a brand-new
listing). Back these two files up somewhere safe and private (password manager,
encrypted cloud, etc.) **before** you publish:

| File | What it is |
|---|---|
| `android/upload-keystore.jks` | The keystore (the actual signing key) |
| `android/key.properties` | The alias + passwords that unlock it |

Both are git-ignored so they won't be committed. **They are the only copies.**

- Key alias: `upload`
- Keystore type: PKCS12, RSA 2048, valid until **2053**
- The store/key password is stored in `android/key.properties`.
- SHA-256 fingerprint:
  `8E:6F:A0:51:B2:63:2E:5E:73:32:1F:33:F1:EA:5E:32:94:05:9D:37:75:67:6A:07:11:69:B7:BB:57:15:03:BD`

To print fingerprints again (e.g. if a service asks for SHA-1):
```sh
keytool -list -v -keystore android/upload-keystore.jks -alias upload
```

## The artifact to upload

Google Play requires an **Android App Bundle (`.aab`)**, not an APK:

```
build/app/outputs/bundle/release/app-release.aab
```

Rebuild it any time with:
```sh
flutter build appbundle --release
```

(The signed APK at `build/app/outputs/flutter-apk/app-release.apk` is for
sideloading / direct install and testing — not for the Play Store.)

## App identity

- **Application ID:** `com.paigejulianne.unitaire` (permanent once published)
- **App name:** Klondike Solitaire
- **Version:** `1.0.0` (versionCode 1) — set in `pubspec.yaml` (`version: 1.0.0+1`)

For each new release, bump the version in `pubspec.yaml`. The number after `+`
is the **versionCode** and must increase every upload, e.g. `1.0.1+2`.

## Step-by-step on the Play Console

1. Create a developer account at https://play.google.com/console (one-time $25 fee).
2. **Create app** → fill in name (Klondike Solitaire), language, "Game", free/paid.
3. Use **Play App Signing** (recommended default) — you upload with your upload
   key and Google re-signs with an app-signing key it manages. Your keystore
   above is the *upload* key.
4. Complete the required declarations: privacy policy, data safety, content
   rating questionnaire, target audience, ads (this app has none).
5. **Store listing** assets you'll need to provide:
   - App icon 512×512: `assets/icon/play_store_512.png` (already generated)
   - Feature graphic 1024×500 (not yet created — tell me if you want one)
   - At least 2 phone screenshots and, ideally, tablet screenshots
     (you can capture these from the running app)
6. **Production** (or start with Internal testing) → **Create release** →
   upload `app-release.aab` → review → roll out.

## Regenerating the app icon

The icon is generated from vector code, no image editor needed:
```sh
flutter test tool/generate_app_icon.dart   # re-renders assets/icon/*.png
dart run flutter_launcher_icons             # regenerates all launcher densities
```
