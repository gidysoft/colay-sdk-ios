# Changelog

All notable changes to this project are documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [SemVer](https://semver.org/).

## [0.1.4] - 2026-11-17

### Fixed
- The SKAdNetwork schema is fetched asynchronously, so tracking calls never wait for the network; after a failed fetch
  the SDK waits an hour before retrying instead of retrying on every app open.
- The coarse conversion value never decreases within a measurement window (later windows report only the coarse value).

## [0.1.3] - 2026-11-17

### Added
- Automatic SKAdNetwork / AdAttributionKit conversion values: the SDK reads the conversion value schema defined on the
  ColayAI dashboard (`GET /cx/v1/config`, refreshed every 12 hours) and raises the value when a matching event is tracked.
  The value never decreases within a measurement window (days 0-2, 3-7, 8-35).
- The install is registered for SKAdNetwork attribution on first launch.
- `ColayConfig.automaticConversionValue` (default `true`) to turn this off when you set values yourself.

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
