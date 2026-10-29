# Publication audit — 2026-10-29

Status: **staged locally, not published**. Authenticated GitHub connector identity is jonzamarripa; intended public repository is quadcast-studio-macos. Repository lookup returned not found. Additional publishing authorization is pending; no repository creation/upload was attempted.

## Provenance

The actual working v0.1.1 source, accepted v0.2.0 and accepted v0.2.1 source are preserved as distinct audited snapshots. Private local Git history includes personal email metadata and documentation paths, so it was backed up locally and not copied into this public history. Snapshot commit messages explicitly disclose reconstruction. Public Git author uses the account's GitHub no-reply address. No force push is planned.

- `v0.1.1` → `6c90d8c829d5e633de195adcd908fefed174d5bf`: all original build-input hashes match.
- `v0.2.0` → `68fbbc4beddbf53bae57e7af3e0fda64ded149b2`: all original build-input hashes match.
- `v0.2.1` → `7d2ed817cac3c18ea3742a2930487488fc4b60cc`: all original build-input hashes match.

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

## Missing inputs

CODEX_PUBLISH_ALL.md and the supplied professional README were accessible. QuadCastStudio_GitHub_Launch_Kit.zip was not found at the supplied location, Downloads or chat attachments. INSTALL/SECURITY/CONTRIBUTING/LICENSE_REVIEW/issue templates/release-note drafts were prepared from inspected implementation as interim material, not claimed to be the supplied missing files. Reconcile the actual launch kit before publication.

## Owner licensing decision

The owner selected MIT for original app code after the first staging pass. LICENSE and notices were added to each still-unpublished snapshot without changing its build inputs. Source archives were regenerated. Resource artwork remains excluded pending ownership confirmation. The supplied ZIP path was checked again and still returned file-not-found; publishing authentication is not active.
