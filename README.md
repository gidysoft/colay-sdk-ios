<p align="center"><strong>Colay AI iOS SDK</strong></p>
<p align="center">Attribution, event tracking and conversion measurement for your iOS app</p>

<p align="center">
  <a href="https://github.com/gidysoft/colay-sdk-ios/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/gidysoft/colay-sdk-ios/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="Swift Package Manager" src="https://img.shields.io/badge/SPM-compatible-orange">
  <img alt="iOS 13+" src="https://img.shields.io/badge/iOS-13%2B-lightgrey">
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

[Colay AI](https://colayai.com) brings your ads, website, app and AI Agent conversations together in one dashboard. This SDK reports **which ad or link opened your iOS app**, which screens users visit, and key steps such as sign-up, add to cart and purchase.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [API](#api)
- [Configuration](#configuration)
- [Privacy and consent](#privacy-and-consent)
- [Architecture](#architecture)
- [Example app](#example-app)
- [Development and testing](#development-and-testing)
- [Troubleshooting](#troubleshooting)

## Features

- **Attribution:** Apple Search Ads attribution token (no ATT required), UTM parameters and Meta / Google / TikTok click IDs, deep links.
- **SKAdNetwork / AdAttributionKit:** conversion values set automatically from the schema defined on the ColayAI dashboard (or manually via `updateConversionValue`); install postback copies reported per campaign.
- **Events:** screens (SwiftUI `.colayScreen`), standard and custom events, purchases, user identity.
- **Automatic events:** `app_install`, `app_open`, `app_background`, `session_start`, `deeplink_open`.
- **Reliable delivery:** persistent on-device queue, batched uploads, exponential backoff on errors.
- **Privacy:** nothing is sent without consent; the SDK never requests ATT permission; `PrivacyInfo.xcprivacy` is bundled.
- **Lightweight:** no external dependencies.

## Requirements

| | |
|---|---|
| iOS | 13.0 or later (macOS 10.15+ for tests) |
| Xcode / Swift | Xcode 15+, Swift 5.9+ |
| Colay AI | Dashboard → Ads → **Tracking setup** → iOS source (app ID = bundle ID) |

## Installation

Xcode → File → **Add Package Dependencies…** → `https://github.com/gidysoft/colay-sdk-ios` → Up to Next Major `0.1.4`.

```swift
// Package.swift
.package(url: "https://github.com/gidysoft/colay-sdk-ios", from: "0.1.4")
```

## Quick start

```swift
import SwiftUI
import ColaySDK

@main
struct MyApp: App {
    init() {
        var config = ColayConfig()
        config.defaultConsent = .denied
        Colay.start(key: "colay_pk_xxx", config: config)
    }
    var body: some Scene {
        WindowGroup {
            ContentView().onOpenURL { Colay.handleDeepLink($0) }
        }
    }
}

// Once the user grants consent
Colay.setConsent(.granted)

// Screens, events, users, purchases
CartView().colayScreen("Cart")
Colay.track("add_to_cart", ["productId": "thermos-500"])
Colay.identify("u_123", traits: ["email": "jane@example.com"])
Colay.purchase(149.90, currency: "USD", ["orderId": "A-1001"])
```

UIKit: call `Colay.start` in `application(_:didFinishLaunchingWithOptions:)` and `Colay.handleDeepLink` in `scene(_:openURLContexts:)`. The publishable key (`colay_pk_…`) is not a secret: it can only send events.

## SKAdNetwork

1. On the ColayAI dashboard, open **Tracking setup → your iOS source → Edit**, enter the App Store ID and define
   conversion values (for example `sign_up` → 10, `purchase` → 40).
2. Add the ColayAI domain to your app's `Info.plist` so Apple sends ColayAI a copy of every winning install postback:

   ```xml
   <key>NSAdvertisingAttributionReportEndpoint</key>
   <string>https://colayai.com</string>
   ```

The SDK registers the install on first launch, reads the schema (`GET /cx/v1/config`, refreshed every 12 hours) and raises
the conversion value when a matching event is tracked. The value never decreases within a measurement window
(days 0-2, 3-7, 8-35). Set `config.automaticConversionValue = false` if you manage conversion values yourself.

## API

| Call | What it does |
|---|---|
| `Colay.start(key:config:)` | Initializes the SDK (once, at app launch) |
| `Colay.setConsent(_:)` | Sets consent and persists it on the device |
| `Colay.screen(_:_:)` / `.colayScreen(_:)` | Sends a `screen_view` event |
| `Colay.track(_:_:)` | Sends a standard or custom event (name up to 64 characters) |
| `Colay.identify(_:traits:)` | Identifies the user; earlier anonymous events are linked |
| `Colay.purchase(_:currency:_:)` | Sends a `purchase` event, used in revenue reports |
| `Colay.handleDeepLink(_:)` | Reads campaign data from the link that opened the app |
| `Colay.updateConversionValue(_:coarse:lockWindow:)` | SKAdNetwork / AdAttributionKit conversion value |
| `Colay.reset()` | Clears the user and session on sign-out |
| `Colay.flush(completion:)` | Sends the queue right away |

**Standard event names:** `sign_up`, `login`, `logout`, `lead`, `add_to_cart`, `begin_checkout`, `purchase`, `subscription_start`, `subscription_cancel`, `tutorial_complete`, `level_complete`. Full contract: [PROTOCOL.md](PROTOCOL.md).

## Configuration

| `ColayConfig` field | Default | Description |
|---|---|---|
| `baseURL` | `https://colayai.com` | Server |
| `defaultConsent` | `.granted` | `.denied` is recommended for users covered by GDPR / KVKK |
| `flushAt` / `flushInterval` | 20 / 15 s | Batch size threshold and upload interval |
| `maxQueueSize` | 1000 | Maximum number of events kept on the device |
| `sessionTimeout` | 1800 s | Inactivity before a new session starts |
| `trackLifecycle` | `true` | Automatic app lifecycle events |
| `collectAdvertisingId` | `false` | IDFA, only if the app has ATT permission and ads consent is granted |
| `collectAppleSearchAdsToken` | `true` | Apple Search Ads token on first launch |
| `debug` | `false` | Verbose console logging with the `[ColaySDK]` prefix |

## Privacy and consent

| Consent | Behaviour |
|---|---|
| `.denied` | No events are sent; the queue is cleared |
| `.analyticsOnly` | Events are sent without the IDFA, click IDs and the Apple Search Ads token |
| `.granted` | Everything |

Email addresses and phone numbers travel over TLS; the server stores them hashed with SHA-256. For the App Store "App Privacy" section: usage data, identifiers (device ID), and optionally contact info (if you use `identify`). The privacy manifest is `Sources/ColaySDK/Resources/PrivacyInfo.xcprivacy`.

## Architecture

```
Colay (public API, thread-safe)
  └─ Client ───── session, consent, lifecycle, deep links, SKAdNetwork
       ├─ EventQueue ─── persistent on-device queue (file), limits and trimming
       ├─ Transport ──── HTTPS upload; handles 200 / 400 / 401 / 413 / 429 / 5xx responses
       ├─ Attribution ── parses UTM parameters and click IDs
       └─ PlatformInfo ─ device info, IDFA, Apple Search Ads token
```

Every call returns immediately; work runs on a single serial queue. The public surface is only `Colay`, `ColayConfig`, `ColayConsent` and `ColayCoarseValue`.

The example app follows **MVVM**:

```
App ─▶ MainView (SwiftUI) ─▶ MainViewModel (@MainActor, ObservableObject) ─▶ AnalyticsTracking (protocol)
                                                                               └─ ColayAnalyticsTracker ─▶ Colay
```

The view only renders state; business logic lives in `MainViewModel`; analytics calls sit behind the `AnalyticsTracking` protocol. The ViewModel is tested with a fake tracker (`Examples/ColayExample/Tests`).

## Example app

```bash
cd Examples/ColayExample
cp Config.example.xcconfig Config.xcconfig     # enter your key (Config.xcconfig is not committed)
xcodegen generate                               # https://github.com/yonaskolb/XcodeGen
open ColayExample.xcodeproj
```

Enter `com.colayai.example` as the app ID of your tracking source. Tests (ViewModel unit tests and a UI test that taps each button in turn):

```bash
xcodebuild -project ColayExample.xcodeproj -scheme ColayExample \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Development and testing

```bash
swift test
xcodebuild -scheme ColaySDK -destination 'generic/platform=iOS Simulator' build
```

To release: bump `ColaySDKVersion` in `Client.swift`, add a `## [x.y.z]` section to [CHANGELOG.md](CHANGELOG.md), merge to `main`, then `git tag x.y.z && git push origin x.y.z`. The Release workflow checks that the tag matches the code version, runs the tests and publishes a GitHub Release with the notes from the CHANGELOG. Swift Package Manager reads the version from the tag.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No events arrive | Consent was not granted (`Colay.setConsent`) or `Colay.start` was not called |
| 401 / 403 | Wrong key, disabled source, or the bundle ID does not match the source |
| Events show up late | Events are batched; call `Colay.flush()` to send immediately |

---

[Changelog](CHANGELOG.md) · [Releases](https://github.com/gidysoft/colay-sdk-ios/releases) · [Security](SECURITY.md) · [Contributing](CONTRIBUTING.md) · [MIT License](LICENSE) © Gidysoft
