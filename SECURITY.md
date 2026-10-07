# Security policy

## Supported versions

Security fixes are made against the current `main` branch. Downloaded releases should be considered supported only when they are the latest release; older builds may not receive fixes.

## Report a vulnerability

Please do not open a public issue for a suspected security vulnerability. Use GitHub's **Private vulnerability reporting** for this repository (Security → Advisories → Report a vulnerability). Include the affected version, macOS version, reproduction steps, and impact. Redact transcripts, recordings, access tokens, home-directory paths, and other personal data.

If private reporting is unavailable, contact the repository owner through the GitHub profile and request a private security-reporting channel. Do not send exploit details in a public discussion.

## Privacy-sensitive areas

Utter records microphone and, when enabled, system audio for local transcription; it also uses Accessibility APIs for focused text context and text insertion. Audio and text must not be added to logs, crash reports, test artifacts, screenshots, or issue attachments. Model downloads must use immutable revisions and digest verification. Tooling that executes commands, reads arbitrary files, or transmits user content requires explicit user-visible consent and a separate security review.

## Response

The maintainer will acknowledge a report, assess affected versions and severity, coordinate a fix and disclosure with the reporter, and publish a release note when a fix is available. Please allow time for a fix before public disclosure.
