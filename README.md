# QuadCast Studio for macOS

**A native macOS lighting-control app for the original HyperX QuadCast S microphone.**

> **Unofficial community project.** QuadCast Studio is not affiliated with, endorsed by, or supported by HP or HyperX. HyperX and QuadCast are trademarks of their respective owners.

QuadCast Studio gives owners of the **original HyperX QuadCast S** a Mac-native way to control RGB lighting through a local SwiftUI interface. Built with SwiftUI, it integrates with the independently maintained, open-source [QuadcastRGB](https://github.com/Ors1mer/QuadcastRGB) controller to communicate with the microphone over USB.

## What it does

- Control RGB lighting from a native macOS interface, including independent upper and lower lighting zones.
- Set solid colors, brightness, and compatible effects such as cycle, wave, blink, lightning, and pulse.
- Save and restore local lighting profiles.
- Access common functions from the menu bar (v0.2).
- Manage profiles with validated JSON import/export (v0.2).
- Detect compatible USB devices and report controller status.
- Recover from USB reconnect and Mac sleep/wake events on the tested configuration (v0.2).
- Optional start-at-login, diagnostics, and accessible controls (v0.2).

**Hardware validation:** The creator reports that the v0.2 app successfully applied cyan lighting to an original QuadCast S while microphone audio and physical tap-to-mute continued working. The owner later reported 8/8 v0.2 and v0.2.1 smoke checks: detection, independent zones, two effects, profile persistence, USB reconnect, sleep/wake, audio/mute integrity, and clean owned-process shutdown. Login approval and VoiceOver certification were not part of those eight checks. Codex reported 24 passing automated tests, successful release compilation, and verification of an ad-hoc signature. These are **single-configuration test results**, not universal compatibility certification.

## Downloads and versions

The verified [GitHub Releases](https://github.com/jonzamarripa/quadcast-studio-macos/releases) provide source archives and SHA-256 checksums. **No ready-to-install app binary is offered.**

| Release | Description | Status |
|---|---|---|
| [**v0.2.0**](https://github.com/jonzamarripa/quadcast-studio-macos/releases/tag/v0.2.0) | Menu bar, profiles, improved reliability, diagnostics, accessibility labels | Published source release; accepted on creator’s tested configuration |
| [**v0.1.1**](https://github.com/jonzamarripa/quadcast-studio-macos/releases/tag/v0.1.1) | First functioning SwiftUI prototype | Published historical source release |
| [**v0.2.1**](https://github.com/jonzamarripa/quadcast-studio-macos/releases/tag/v0.2.1) | Dependency preflight, wake-recovery fix, diagnostic privacy | Latest accepted source release; 30 passing tests |

> **For macOS users:** An ad-hoc signed build is *not* Developer ID notarized, and macOS Gatekeeper may block running downloaded builds. A signed/notarized package is required for a smooth public installation experience. Never disable macOS security system-wide to run this application. A source build may be an option for advanced users while distribution signing is pending.

### Direct source downloads

- [v0.2.1 source ZIP](https://github.com/jonzamarripa/quadcast-studio-macos/releases/download/v0.2.1/QuadCastStudio-v0.2.1-source.zip) — recommended source version.
- [v0.2.0 source ZIP](https://github.com/jonzamarripa/quadcast-studio-macos/releases/download/v0.2.0/QuadCastStudio-v0.2.0-source.zip).
- [v0.1.1 source ZIP](https://github.com/jonzamarripa/quadcast-studio-macos/releases/download/v0.1.1/QuadCastStudio-v0.1.1-source.zip).
- [SHA-256 checksums](https://github.com/jonzamarripa/quadcast-studio-macos/releases/download/v0.2.1/SHA256SUMS.txt).

These ZIPs contain audited source, not a macOS installer. All six release downloads were fetched after publication and verified against SHA-256 values; each source archive's manifest matches the accepted original build inputs.

## Compatibility

- **Confirmed:** Original HyperX QuadCast S, Apple Silicon Mac, direct USB data connection, macOS/Xcode environment used in the initial validation.
- **Unsupported by this app:** DuoCast, QuadCast 2 and QuadCast 2 S.
- **Untested:** Intel Macs, other original-S revisions, additional macOS versions and USB hubs/docks.
- **Build/test host:** Apple Silicon, macOS 27.2 (26B118), Xcode 27.1 (27A9275), Swift 6.4. The deployment target is macOS 13; this does not mean every macOS 13+ release was tested.
- **Original-S controller allowlist:** `0951:171F`, `03F0:0F8B`, `03F0:028C`, `03F0:048C`, `03F0:068C`. Exact physical VID/PID of the owner-tested unit was not captured in the release record.
- **Important:** This controls microphone **lighting**, not physical gain, polar-pattern hardware, firmware, or physical tap-to-mute state. macOS continues handling microphone audio.
- **Not a live LED readback:** Device detection, backend process health, and a successful command do not prove the physical LED state without observing the microphone.

## Requirements

1. A supported original HyperX QuadCast S connected through a **USB data cable**. If the microphone is missing under macOS Sound > Input or System Information > USB, troubleshoot the cable/hub first.
2. macOS on Apple Silicon for the tested configuration.
3. [Homebrew](https://brew.sh/) and the separately installed `quadcastrgb` utility, **version 1.0.5 for v0.2.1**:

   ```bash
   brew install quadcastrgb
   ```

4. Full Xcode for a local source build. A public installer has not been validated.

### Build from source (advanced users)

Follow the version-specific instructions in its release and repository source tree. In the early source package, `bash build-app.sh` builds an app in `dist/` with full Xcode selected. **Do not assume a packaged binary or build script works across all macOS versions; inspect the release notes.**

## How it works

```text
QuadCast Studio (SwiftUI)
   └── validated options and owned process management
       └── separately installed QuadcastRGB executable
           └── USB control protocol
               └── original HyperX QuadCast S RGB hardware
```

QuadCast Studio does not require an internet connection or cloud account for lighting control. The existing integration does **not** include a bundled firmware updater or copy of the QuadcastRGB executable.

## Safety and known limitations

- Do not run a separate `quadcastrgb` command in Terminal while using the app; the controller may hold exclusive USB interfaces.
- The application should stop only controller processes **it** owns, not unrelated processes.
- Audio remains managed by macOS. This project should not silently modify audio devices or firmware.
- The initial version is tested on one known hardware configuration; issue reports should include macOS version, microphone USB vendor/product IDs, and a redacted diagnostic summary. **Never post private logs or serial numbers.**
- Before releasing binaries publicly, perform an open-source license review, confirm signing/notarization and test installation on a second Mac.

## Version history

See [CHANGELOG.md](CHANGELOG.md) and the release notes for specific capabilities. Git tags should map to **the exact version source**, not multiple releases made from the same source commit.

## Reporting bugs and contributing

Use GitHub Issues and include steps to reproduce, expected versus observed behavior, device revision and macOS version. Consult [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## Open-source credits and licensing

**QuadcastRGB**, created by [Ors1mer](https://github.com/Ors1mer/QuadcastRGB), is an independent project licensed **GPL-2.0-only**. QuadCast Studio invokes a user-installed copy and does not claim to own or relicense that upstream project.

**Application source license:** Original app code is [MIT-licensed](LICENSE), as selected by the owner. Resources artwork is excluded pending provenance confirmation. See [license review](LICENSE_REVIEW.md) and [notices](THIRD_PARTY_NOTICES.md). QuadcastRGB retains its own GPL-2.0-only license.

Maintainer: Jonathan Iker Zamarripa.

## Source provenance and screenshots

Public tags are audited snapshots of the actual completed versions, reconstructed for publication because local development metadata/docs contain private information. All application, test and build inputs are preserved byte-for-byte; each tag includes a SHA-256 provenance manifest. They are not represented as original uninterrupted development commits. Private history and accepted apps are retained locally.

No authentic privacy-reviewed application screenshot is included yet. No mockup or vendor artwork is used as a screenshot.

## Compatibility, privacy and help

See [compatibility](docs/COMPATIBILITY.md), [troubleshooting](docs/TROUBLESHOOTING.md), [privacy](docs/PRIVACY.md), and [release gates](docs/RELEASE_GATES.md).
