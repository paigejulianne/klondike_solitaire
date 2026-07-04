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
5. **Store listing** assets (all generated, in `assets/store/`):
   - App icon 512×512: `assets/icon/play_store_512.png`
   - Feature graphic 1024×500: `assets/store/feature_graphic.png`
   - Phone screenshots: `assets/store/phone_1.png` … `phone_3.png` (1080×1920)
   - Tablet screenshots: `assets/store/tablet_1.png`, `tablet_2.png` (1920×1200)
6. **Production** (or start with Internal testing) → **Create release** →
   upload `app-release.aab` → review → roll out.

## Regenerating the app icon and store assets

Everything is generated from vector code / device captures — no image editor:
```sh
flutter test tool/generate_app_icon.dart    # re-renders assets/icon/*.png
dart run flutter_launcher_icons              # regenerates all launcher densities
flutter test tool/generate_marketing.dart    # feature graphic + framed screenshots
```
The framed store screenshots are built from raw captures in `assets/store/raw/`.
Replace those raw PNGs and re-run the marketing generator to refresh them.

---

# Distributing the Windows app

Two packages are produced in `dist/windows/` (git-ignored build outputs):

| File | Use |
|---|---|
| `KlondikeSolitaire-1.0.0-windows-x64-portable.zip` | **Portable** — unzip and run `klondike_solitaire.exe`. No install, no prerequisites (the VC++ runtime is bundled). Easiest to share. |
| `KlondikeSolitaire-1.0.0-x64.msix` | **Installer** — installs the app with a Start Menu entry and an uninstaller. |
| `TRUST-THIS-CERT-FIRST.cer` | The certificate that signs the MSIX (see below). |

## Installing the MSIX (self-signed)

The MSIX is signed with a **self-signed** certificate, so Windows won't trust it
until that certificate is installed. On the target PC (one-time):

1. Right-click `TRUST-THIS-CERT-FIRST.cer` → **Install Certificate**.
2. Choose **Local Machine** → **Place all certificates in the following store**
   → **Trusted People** → Finish (requires admin).
3. Double-click the `.msix` → **Install**.

For public distribution without this trust step, sign the MSIX with a real
**code-signing certificate** from a CA (e.g. DigiCert, Sectigo) instead of the
self-signed one.

## Rebuilding the Windows packages

```sh
flutter build windows --release
```
Then repackage. The MSIX config lives in `pubspec.yaml` under `msix_config`.
The signing certificate is generated locally and **git-ignored**
(`windows/packaging/klondike-selfsign.pfx` + password in `.pfx_pw`). To recreate
it (PowerShell):
```powershell
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=Paige Julianne" `
  -KeyUsage DigitalSignature -CertStoreLocation "Cert:\CurrentUser\My" `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3") -NotAfter (Get-Date).AddYears(10)
```
Pack with the Windows SDK's `makeappx.exe pack` and sign with `signtool.exe sign`
(the bundled `msix` tool's packer fails on this machine with a VC++ SxS error, so
the SDK tools are used directly).

⚠️ Like the Android keystore, **back up the `.pfx` and its password** if you want
future MSIX updates to be signed by the same identity.
