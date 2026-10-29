# Contributing

Open an issue before proposing major changes. Original app code is MIT-licensed; Resources artwork is excluded pending provenance confirmation. Do not submit third-party code or art without checking rights. QuadcastRGB has its own GPL-2.0-only license.

Use the relevant tag and full Xcode. Run `swift test` and `swift build -c release --product QuadCastStudio`; hardware behavior must be reported separately from mocked tests. Do not claim LEDs changed from process success. Keep changes focused, include meaningful regression tests, and describe the exact tested hardware/macOS/dependency configuration.

Do not add firmware/gain/physical mute/audio processing, telemetry, silent installation, shell interpolation, privileged services or process-wide kill commands. Never commit credentials, private logs, serial numbers, generated apps, build caches or personal absolute paths. Screenshots must show the actual app and be reviewed for private profile/desktop content.
