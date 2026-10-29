# Compatibility

| Item | Evidence / support |
|---|---|
| Original HyperX QuadCast S, Apple Silicon | Owner-reported app-level lighting, audio/mute and eight physical checks passed for v0.2.0 and v0.2.1 on one configuration. |
| Test/build host | macOS 27.2 (26B118), Xcode 27.1 (27A9275), Swift 6.4, arm64. |
| Deployment minimum | macOS 13 in Package.swift; not a claim that every 13+ OS has been tested. |
| QuadcastRGB | Separate Homebrew installation; exact 1.0.5 required by v0.2.1 preflight. No CLI bundled. |
| Original-S controller IDs | 0951:171F, 03F0:0F8B, 03F0:028C, 03F0:048C, 03F0:068C are allowlisted. The exact owner-tested unit's ID was not captured. |
| DuoCast / QuadCast 2 / QuadCast 2 S | Excluded from this application's supported device allowlist. |
| Intel / additional original-S revisions / other macOS releases | Not independently tested or certified. |
| Hubs, docks, adapters, multiple controllers | Not broadly validated; upstream CLI selects the first compatible device, so exact targeting is a known limitation. |
| Public downloaded app installation | Not verified: no Developer ID signed/notarized installer or second-Mac acceptance. Source downloads only. |

The app controls lighting only. Hardware gain, polar pattern, physical tap-to-mute and audio remain outside software control. It does not read back true LED state. Startup/login approval and complete VoiceOver testing are not inferred from the eight physical smoke checks.
