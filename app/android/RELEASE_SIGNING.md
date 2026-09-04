# Release signing — DIKASIR / DPOS Android

This app's release builds are signed with a dedicated **upload/release keystore**.
This file records **where that key lives** so it is never lost. It contains **no
secrets** — the keystore file and its password are intentionally kept out of git.

> ⚠️ **If the keystore or its password is lost, you can never update the app** for
> anyone who already installed it (nor upload updates to the Play Store later). Keep
> the two files below backed up in a password manager / encrypted company storage.

## Where the keystore lives (this build machine)

| Item | Location |
|------|----------|
| Keystore file | `C:\Users\EGan\keys\dpos-release.jks` |
| Password file | `C:\Users\EGan\keys\dpos-release.password.txt` (store password = key password) |
| Key alias | `dpos` |
| Validity | 10000 days (~27 years) from 2026-08-31 |

These paths are **local to this machine** and are **not** in the repository. Copy both
files to secure, backed-up storage.

## How signing is wired

- `android/key.properties` (git-ignored) holds `storePassword`, `keyPassword`,
  `keyAlias`, and `storeFile` pointing at the keystore above.
- `android/app/build.gradle.kts` loads `key.properties` when present and signs the
  `release` build type with it. On a machine **without** `key.properties`, it falls
  back to debug signing so `flutter run --release` still works (that build is **not**
  distributable).
- `.gitignore` already excludes `key.properties`, `**/*.jks`, and `**/*.keystore`.

## Certificate fingerprints (not secret — safe to share/record)

- **DN:** `CN=PT Dika, OU=DPOS, O=PT Dika, L=Jakarta, ST=DKI Jakarta, C=ID`
- **SHA-256:** `CD:05:B1:87:E3:45:38:FD:21:20:27:66:3C:66:CE:D7:6A:EE:5A:79:50:65:7C:DA:77:7A:C9:49:65:C9:C3:DB`
- **SHA-1:** `C8:EB:CB:3A:87:1E:F2:48:FA:87:C9:73:F7:2B:FC:13:6A:D1:77:1B`

## Recreating `key.properties` on a new machine

After restoring the keystore from backup to some path, create `android/key.properties`:

```
storePassword=<the keystore password>
keyPassword=<same password>
keyAlias=dpos
storeFile=C:/absolute/path/to/dpos-release.jks
```

## Build a distributable, signed APK

```
cd app
flutter build apk --release \
  --build-number=<n> \
  --dart-define=API_BASE_URL=https://dikapos.ptdika.com/api/v1
```

Output: `app/build/app/outputs/flutter-apk/app-release.apk` (universal, ~74 MB).

Verify the signer:

```
"$ANDROID_SDK/build-tools/<ver>/apksigner" verify --print-certs app-release.apk
```

The SHA-256 above must match. Any APK signed with a **different** key cannot update an
install made from this key — recipients would have to uninstall first.
