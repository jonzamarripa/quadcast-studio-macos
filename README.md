# QuadCast Studio v0.2.1 — audited source snapshot

Unofficial native macOS lighting controller for the original HyperX QuadCast S. Not affiliated with HP or HyperX.

This reconstructed publication snapshot preserves the owner-supplied application/build inputs exactly. Private development history remains local. See SOURCE_PROVENANCE.json for file hashes.

## Build

Use full Xcode on Apple Silicon, then run from this directory:

```bash
swift test
./build-app.sh
```

Builds locally to `dist/QuadCast Studio.app` with ad-hoc signing. No Developer ID signed/notarized installer is supplied. Other macOS releases and Intel installation are not certified. Existing package deployment target is macOS 13; automated validation used macOS 27.2/Xcode 27.1.

Requires separately installed Homebrew QuadcastRGB 1.0.5 (`brew install quadcastrgb`). It is not bundled. Stop Terminal controllers yourself with Control+C before applying. Never disable Gatekeeper system-wide. Device detection/process activity is not LED-state readback; user observation is separate.

Profiles, native color/hex editing, menu-bar control, explicit Apply/Off, login opt-in and reconnect/wake opt-in are preserved. There is no audio recording/processing, physical gain/mute control or firmware function.

The owner reported 8/8 manual checks for this version. Historical automation passed 30 tests; publication validation is recorded on the main branch. These are single-configuration results.

## Attribution and rights

QuadcastRGB by Ors1mer is GPL-2.0-only: https://github.com/Ors1mer/QuadcastRGB. The app invokes the separately installed tool without copying its implementation. Original app code is MIT-licensed. Resources artwork is excluded from that grant pending provenance confirmation. Public binary distribution awaits license review, Developer ID signing, notarization and another-Mac installation testing.
