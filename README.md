# QuadCast Studio v0.1.1 — historical source snapshot

Unofficial SwiftUI lighting utility for the original HyperX QuadCast S. Not affiliated with HP or HyperX.

This tag preserves the actual v0.1.1 build inputs supplied by the owner. Publication is a reconstructed, privacy-audited snapshot, not an original development commit. Sources, Tests, Package.swift, Info.plist, build-app.sh and Resources are unchanged. Private development history remains local.

## Build

Use full Xcode on Apple Silicon. From this source directory:

```bash
swift test
swift build -c release --product QuadCastStudio
```

The historical `build-app.sh` is also supplied unchanged. Its packaging paths/toolchain assumptions can differ on newer SwiftPM versions; do not treat a build from source as a notarized installer.

Hardware control needs separately installed Homebrew QuadcastRGB (`brew install quadcastrgb`). The executable is not included. Quit other lighting controllers before applying. No LED-state readback exists. No audio processing, gain, physical mute or firmware controls are implemented.

QuadcastRGB by Ors1mer is GPL-2.0-only: https://github.com/Ors1mer/QuadcastRGB. Original app code is MIT-licensed; Resources artwork is excluded pending provenance confirmation. See LICENSE and THIRD_PARTY_NOTICES.md. No ready-to-install binary is distributed. Developer ID signing, notarization and second-Mac install testing remain outstanding.
