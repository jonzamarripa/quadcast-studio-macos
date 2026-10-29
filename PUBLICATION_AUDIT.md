# Publication audit — 2026-10-29

Status: **published source-only** at https://github.com/jonzamarripa/quadcast-studio-macos. Repository is public, Issues enabled, main and three distinct version tags verified. All three source Releases and their ZIP/checksum downloads were verified after publication. No app installer is included.

## Provenance

The actual working v0.1.1 source, accepted v0.2.0 and accepted v0.2.1 source are preserved as distinct audited snapshots. Private local Git history includes personal email metadata and documentation paths, so it was backed up locally and not copied into this public history. Snapshot commit messages explicitly disclose reconstruction. Public Git author uses the account's GitHub no-reply address. No force push is planned.

- `v0.1.1` → `769cdceed0c6a17f0f89453e4714bcedb3641f44`: all original build-input hashes match.
- `v0.2.0` → `1682076ec0df3426403b329321415f37baf03106`: all original build-input hashes match.
- `v0.2.1` → `e3c7de403f02c871b4c18f8553eae9d76cdd499b`: all original build-input hashes match.

All Sources/, Tests/, Resources/, Package.swift, Info.plist and build-app.sh files match the corresponding real version. Publication docs are separate from application code. No source version is fabricated; v0.2.1 completed acceptance before this publication task.

## Audit findings and treatment

- Credential-marker scans found no credential/token/private-key patterns in staged source. This is a bounded code review, not a guarantee against every possible secret format.
- Personal absolute paths and private commit email metadata exist in private development history/docs; they are excluded from publication. Synthetic `/Users/test` redaction fixtures remain unchanged.
- No private logs, actual serial numbers, profiles/UserDefaults, generated apps, build caches, ZIP assets, private keys or credentials are tracked in public history. Per-version source archives are built from Git tags separately.
- App manifests use only local targets and Apple frameworks; no third-party Swift package/source was identified. No QuadcastRGB implementation or executable is included. Dependency remains externally installed GPL-2.0-only with attribution and separate rights review.
- The supplied generic microphone icon has no visible manufacturer logo. Independent asset ownership is not certified; no reuse license is granted.
- The owner selected MIT for original app code. Resources artwork is excluded pending provenance confirmation; the app license does not relicense QuadcastRGB or Apple frameworks. See LICENSE and THIRD_PARTY_NOTICES.md.
- README's stale claim that v0.2.1 was unbuilt was corrected. Unsupported microphone models are distinguished from untested original-S revisions. Login/VoiceOver certification is not inferred from the eight physical checks.
- Authentic screenshots are not included; no mockup/vendor artwork is substituted.

## Fresh verification

All three audited source snapshots compiled in release configuration using full Xcode. XCTest passed 6 tests for v0.1.1, 24 for v0.2.0 and 30 for v0.2.1. The final suite explicitly enabled read-only checks of installed QuadcastRGB 1.0.5. No new lighting commands or audio capture were performed. Historical user hardware observations remain attributed to the user.

Build/test logs are retained privately, not in public Git history. Source checksums accompany separately prepared archives. No ready-to-install app binary is being published: Developer ID signing, notarization, Gatekeeper/second-Mac installation and distribution rights are unresolved.

## Publication documents

The owner authorized proceeding without the failed ZIP download and supplied the combined publication document. README.md and CODEX_PUBLISH_ALL.md informed this work. Supporting install, compatibility, troubleshooting, privacy, contribution, security, issue-template and release documents were generated directly from inspected code. Stale planned-v0.2.1 and login/VoiceOver-certification claims in the drafts were corrected against actual evidence.

## Owner licensing decision

The owner selected MIT for original app code after the first staging pass. LICENSE and notices were added to each still-unpublished snapshot without changing its build inputs. Source archives were regenerated. Resource artwork remains excluded pending ownership confirmation. The owner subsequently authorized proceeding without the ZIP. Publishing authentication is now active for jonzamarripa.

## Remote verification

The local Git client had no credential-helper login, so the authorized GitHub API imported verified blobs/trees and snapshot commits following an initial repository seed. Every remote tree SHA matched its audited local tree. Public snapshot SHAs differ from earlier unpublished local snapshots because the public history includes that initial seed. No force push or unrelated history replacement occurred. A public fetch independently retrieved main/tag objects.

All six public asset downloads passed SHA-256 verification. The three source ZIPs also passed per-file original build-input manifest verification. MIT and artwork exclusions are present in each published tag. Repository topics are macos, swiftui, hyperx, quadcast-s, rgb, usb and microphone. No secrets or original private Git author emails were transferred. Existing validated local projects remain unchanged.
