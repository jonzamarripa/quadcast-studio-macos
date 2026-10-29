# Troubleshooting

## No original-S device

Use a USB data cable, try a direct connection and check macOS Sound Input/System Information USB. Audio and lighting controllers are separate endpoints. A product name alone is not sufficient for lighting compatibility. Do not reset firmware, detach drivers or change macOS security settings as a workaround.

## Missing or incompatible backend

Run `quadcastrgb --version` yourself. v0.2.1 requires exact 1.0.5 at an allowlisted Homebrew path. Missing, failing, stalled or different versions produce an error before a new lighting command. Homebrew may ship a newer version in the future; do not assume it is compatible or automatically downgrade it. Report a redacted version/OS/VID:PID summary.

## Preview changes but microphone does not

Preview is requested configuration, not LED readback. Choose Apply and observe the real LEDs. Stop a controller you started in Terminal with Control+C before using the app. Do not use killall or terminate unrelated processes. A running child or a successful process exit is not proof of physical lighting response.

## Controller will not stop

Use Stop controller and retry. A timeout retains ownership and blocks a replacement; quit can remain pending rather than abandoning a known child. Force-quit/OS failure can bypass cleanup. If another controller was independently started, stop that controller yourself. Never run lighting commands with administrator privileges.

## Reconnect or sleep/wake

Restore is off by default. It uses the last applied snapshot only after explicit consent; an edited preview is not the restoration source. No command is applied merely because the app launched. USB polling has the existing 2.5-second interval. v0.2.1 fixes a wake/changed-registry ordering issue, but broader hub/multi-controller configurations remain unverified.

## Profiles or imports

Export a backup before experimenting. UserDefaults remains local under the unchanged bundle ID and v1 profile key. Corrupt stored data is retained and reported instead of overwritten. Imports require schema version 1, valid names/colors/effects/ranges, unique incoming IDs, at most 1 MB and 200 total profiles. Import copies receive fresh IDs and collision-safe names. The app does not import arbitrary commands.

## Build, login or installation

Use full Xcode. See INSTALL.md for version-specific commands. The historical v0.1.1 packaging script retains old build-path assumptions. SMAppService login support requires the actual app bundle and may require OS approval. Public archives are source-only; no notarized installer is promised. Do not disable Gatekeeper/SIP or strip quarantine as an installation policy.

For issues, provide the tag, macOS version, controller VID/PID and minimal reproduction steps. Redact personal paths, profile names, serial numbers and credentials. No response-time guarantee is offered.
