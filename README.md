# QuadCast Studio v0.2.0 — audited source snapshot

Unofficial native macOS lighting controller for the original HyperX QuadCast S. Not affiliated with HP or HyperX.

This reconstructed publication snapshot preserves actual accepted v0.2.0 source/build inputs. Private development history remains local. File hashes are in SOURCE_PROVENANCE.json.

Use full Xcode on Apple Silicon, then run `swift test` and `./build-app.sh`. The app is assembled in `dist/` with local ad-hoc signing. No notarized installer is distributed. Package deployment target is macOS 13; automation was tested on macOS 27.2 with Xcode 27.1, not every supported deployment release.

Requires separately installed Homebrew QuadcastRGB 1.0.5 (`brew install quadcastrgb`). No CLI is bundled. Quit competing Terminal lighting controllers with Control+C. Preserve normal microphone audio; there is no audio processing, firmware, gain or physical mute control. Preview/process activity is not LED readback.

This version adds menu-bar controls, native colors/hex editing, profiles with validated JSON import/export, owned-process recovery, optional login and explicit reconnect-restore consent. Owner reported 8/8 physical checks; the accepted run passed 24 automated tests. These are single-configuration observations.

QuadcastRGB by Ors1mer is GPL-2.0-only: https://github.com/Ors1mer/QuadcastRGB. Original app code is MIT-licensed; Resources artwork is excluded pending provenance confirmation. Developer ID signing, notarization and another-Mac installation testing remain outstanding. Do not disable Gatekeeper system-wide.
