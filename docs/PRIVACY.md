# Privacy and diagnostics

The inspected Swift package uses local SwiftUI/AppKit/IOKit/Foundation/ServiceManagement code and a separately installed CLI. No app network client, telemetry package or microphone/audio-capture implementation was identified in this bounded source audit. OS sleep/wake notifications and read-only USB polling support connection recovery; they are not audio monitoring.

Profiles and preferences are local UserDefaults. Exports intentionally contain user profile names/colors. Diagnostics contain useful USB VID/PID, transient registry ID/process ID, requested arguments and bounded controller output. v0.2.1 redacts the current home path in exported errors/output. Review diagnostics and screenshots before sharing; automatic redaction is not a guarantee against all private information.

Never post serial numbers, tokens, certificates, account details or full home paths. JSON imports validate the whole document before changing the library. The app has no true LED-state readback.
