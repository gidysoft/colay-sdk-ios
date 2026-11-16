# Changelog

All notable changes to this project are documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [SemVer](https://semver.org/).

## [0.1.2] - 2026-11-17

Initial public release.

### Added
- Public API: `start`, `track`, `screen`, `identify`, `purchase`, `setConsent`, `handleDeepLink`, `reset`, `flush`, `updateConversionValue` and the SwiftUI `.colayScreen` modifier.
- Apple Search Ads attribution token (no ATT required); SKAdNetwork / AdAttributionKit conversion values; UTM parameters and click IDs from deep links.
- Automatic `app_install`, `app_open`, `app_background`, `session_start` and `deeplink_open` events.
- Persistent on-device queue, batched uploads and exponential backoff.
- Consent management (analytics / ads); the IDFA is opt-in and the SDK never requests ATT permission; `PrivacyInfo.xcprivacy` included.
- Example app built with MVVM (SwiftUI, `ObservableObject` ViewModel, `AnalyticsTracking` protocol) with unit and UI tests.
- GitHub Actions: `swift test` and an iOS build on every change; automatic GitHub Releases from version tags.
- `README.md`, `PROTOCOL.md`, `SECURITY.md`, `CONTRIBUTING.md`.
