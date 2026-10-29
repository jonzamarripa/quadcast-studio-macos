# Installation — source builds only

No ready-to-install public app package is offered. Developer ID signing, notarization and installation on a second compatible Mac have not been verified. An ad-hoc local build is not a notarized installer. Do not disable Gatekeeper or SIP, strip quarantine as an installation policy, install drivers or run the app with elevated privileges.

## Requirements and build

Use an original QuadCast S, a USB data cable, Apple Silicon and full Xcode. Automation was tested on macOS 27.2/Xcode 27.1; macOS 13 is the deployment minimum, not a complete tested compatibility matrix.

Install Homebrew separately if desired, then separately install `quadcastrgb`. v0.2.1 accepts exact version 1.0.5; future Homebrew versions are not silently treated as compatible.

```bash
brew install quadcastrgb
quadcastrgb --version
swift test
./build-app.sh
open 'dist/QuadCast Studio.app'
```

Run these from the extracted version's source directory. The historical v0.1.1 packaging script retains its original toolchain assumptions; `swift build -c release --product QuadCastStudio` builds its executable if packaging paths differ. Select full Xcode through Xcode's settings; this project does not install Xcode or change system settings automatically.

For v0.2.1, `QUADCAST_CHECK_INSTALLED_BACKEND=1 swift test` additionally performs read-only installed-dependency checks. Other tests mock lighting or use a harmless owned sleep process.

Quit another Studio version before launching. Stop your Terminal lighting controller yourself with Control+C. Preview edits are local; Apply/Test cyan/RGB off send commands. Observe the real LEDs before confirming a physical change. Check normal audio and physical tap-to-mute afterwards in your usual audio application.

Profiles are local UserDefaults under the unchanged app bundle ID. Export JSON before experimenting if you need a user-data backup. Source archives do not contain your preferences. Login support requires the app bundle; the supported OS approval flow may require System Settings.
