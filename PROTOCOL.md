# ColayAI Tracking Protocol v1

The shared contract that the Android, iOS and web SDKs follow when sending events to the ColayAI server. The server side (`/cx/v1/*`) is implemented against this document.

## Endpoint

```
POST {baseUrl}/cx/v1/batch
Content-Type: application/json
X-Colay-Key: colay_pk_xxxxxxxx        (publishable key; embedded in the app, not a secret)
```

- `baseUrl` defaults to `https://colayai.com`.
- A key belongs to one `TrackingSource` (a website or an app). The server validates the key, the platform, the Android package name, the iOS bundle ID and, for the web, the `Origin`.
- The web SDK uses `navigator.sendBeacon` when the page is closing. Since headers cannot be sent that way, the key is also accepted in the body as `key`.

### Body

```json
{
  "key": "colay_pk_...",                // sendBeacon only; ignored when the header is present
  "sentAt": "2026-11-15T21:04:05.123Z",
  "sdk": { "name": "colay-android", "version": "0.1.2" },
  "context": {
    "app":    { "id": "com.example.app", "version": "2.3.1", "build": "231" },
    "device": { "platform": "android", "os": "Android", "osVersion": "15", "manufacturer": "Samsung",
                "model": "SM-S921B", "locale": "en-US", "timezone": "Europe/Istanbul",
                "screenWidth": 1080, "screenHeight": 2340 },
    "advertisingId": "…",               // only with ads consent and when the app allows it
    "limitAdTracking": false,
    "page": { "url": "…", "path": "/", "title": "…", "referrer": "…" }   // web only
  },
  "events": [ Event, … ]
}
```

### Event

| Field | Type | Description |
|---|---|---|
| `id` | string (UUID) | Unique event ID. The server never counts the same ID twice. Used as `event_id` when forwarding to ad platforms. |
| `type` | string | `track`, `screen`, `identify`, `alias` |
| `name` | string | Event name (one of the standard names below or a custom name, up to 64 characters) |
| `timestamp` | ISO-8601 | Time of the event on the device (UTC) |
| `anonymousId` | string | Random ID per device / browser (generated on first launch) |
| `userId` | string? | The app's own user ID (after `identify`) |
| `sessionId` | string | Session ID (renewed after 30 minutes of inactivity) |
| `properties` | object | Event properties (up to 64 keys, 8 KB) |
| `traits` | object? | `identify` only: user traits (email, phone, name…) |
| `revenue` | number? | Sale amount |
| `currency` | string? | ISO-4217 (`USD`, `EUR`, `TRY`…) |
| `consent` | object | `{ "analytics": true, "ads": true }` — consent at the time of the event |
| `attribution` | object? | Only on `app_install`, `deeplink_open` and `session_start`. On the web, arriving from an ad link starts a new session and the attribution is attached to that session's `session_start` event. |

### Attribution (`attribution`)

```json
{
  "utm_source": "facebook", "utm_medium": "paid", "utm_campaign": "november", "utm_content": "video1", "utm_term": "…",
  "fbclid": "…", "gclid": "…", "gbraid": "…", "wbraid": "…", "ttclid": "…", "ctwa_clid": "…", "msclkid": "…",
  "colay_link": "AbC12",                       // ColayAI tracking link code (/r/{code})
  "referrer": "https://…",                     // web: document.referrer
  "installReferrer": "utm_source=…&gclid=…",   // Android: raw Play Install Referrer value
  "referrerClickTs": 1731700000, "installBeginTs": 1731700100,
  "asaToken": "…",                             // iOS: Apple Search Ads (AdServices) token
  "deeplink": "exampleapp://campaign?utm_source=…"
}
```

## Standard event names

| Name | When |
|---|---|
| `app_install` | First launch of the app (once). On Android the install referrer is attached. |
| `app_open` | The app came to the foreground |
| `app_background` | The app went to the background (`properties.duration` in seconds) |
| `session_start` | A new session |
| `screen_view` | `type=screen`, `name` = screen name |
| `page_view` | Web page view |
| `deeplink_open` | The app was opened from a link |
| `sign_up`, `login`, `logout` | Sign-up, sign-in, sign-out |
| `lead` | Form or contact request |
| `purchase` | Purchase (`revenue`, `currency`, `properties.orderId`) |
| `subscription_start`, `subscription_cancel` | Subscriptions |
| `add_to_cart`, `begin_checkout` | E-commerce steps |
| `tutorial_complete`, `level_complete` | In-app progress |

## Responses and retries

| Code | What the SDK does |
|---|---|
| `200` `{ "accepted": n }` | Sent events are removed from the queue |
| `400` | Malformed batch: events are dropped and not resent |
| `401` / `403` | Invalid or disabled key: events are dropped and sending stops for the rest of the process lifetime |
| `413` | Batch too large: split in two and retried |
| `429`, `5xx`, network error | Events stay in the queue. The wait doubles on every attempt (up to 10 minutes); a `Retry-After` header is respected. |

## Limits

- A batch holds at most 100 events and 500 KB of data.
- The on-device queue holds at most 1000 events; when the limit is exceeded, the oldest events are dropped.
- SDKs send once 20 events are queued or every 15 seconds, and immediately when the app goes to the background.

## Consent

- `analytics = false`: no events are sent and the queue is cleared.
- `ads = false`: events are sent, but without the advertising ID and click IDs. The server does not forward these events to Meta, Google or TikTok.
- The default consent is set with `defaultConsent` in the SDK configuration. For users covered by GDPR / KVKK, `analytics=false` is recommended until the app obtains explicit consent.
- iOS: the SDK never requests ATT permission. It reads the advertising ID (IDFA) only when `collectAdvertisingId = true`, the app has obtained permission and `ads` consent is granted.

## Identity resolution

- `anonymousId` is generated on first launch and persisted.
- When `identify(userId, traits)` is called, the server links all earlier events of that `anonymousId` to the user.
- `reset()` (sign-out) generates a new `anonymousId` and clears `userId`.
- Email and phone are sent in plain text inside `traits` (over TLS). The server hashes them with SHA-256 before sending them to ad platforms.
