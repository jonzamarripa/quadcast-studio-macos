# Security and privacy

Do not post secrets, certificates, tokens, serial numbers or unredacted diagnostics. Ordinary bug reports can use Issues with only macOS version, controller VID/PID, dependency version and minimal reproduction steps.

For a security-sensitive issue, use GitHub private vulnerability reporting if enabled. If it is unavailable, open a minimal issue requesting a private reporting channel without revealing exploit details or personal data. No response-time guarantee is offered.

The app launches only its own controller processes, does not bundle the backend, and does not implement audio capture or network telemetry. Forced app termination or OS failure can bypass cleanup. Public installer signing/notarization is still a release gate. Do not disable macOS security to run a download.
