import Foundation

/// User consent.
/// - When `analytics` is false, no events are sent and the queue is cleared.
/// - When `ads` is false, events are still sent but without the advertising ID, click IDs and the Apple Search Ads token,
///   and the server does not forward events to ad platforms.
public struct ColayConsent: Equatable {
    public var analytics: Bool
    public var ads: Bool

    public init(analytics: Bool, ads: Bool) {
        self.analytics = analytics
        self.ads = ads
    }

    public static let granted = ColayConsent(analytics: true, ads: true)
    public static let denied = ColayConsent(analytics: false, ads: false)
    public static let analyticsOnly = ColayConsent(analytics: true, ads: false)
}

/// SDK settings. Every field has a sensible default.
public struct ColayConfig {
    /// ColayAI server.
    public var baseURL: URL = URL(string: "https://colayai.com")!
    /// Default used before the app records consent. For users covered by GDPR/KVKK, `.denied` is recommended
    /// until explicit consent is given; then call `Colay.setConsent`. The user's choice is persisted.
    public var defaultConsent: ColayConsent = .granted
    /// Events are sent right away once this many are queued.
    public var flushAt: Int = 20
    /// Seconds between periodic sends.
    public var flushInterval: TimeInterval = 15
    /// Maximum number of events kept on the device.
    public var maxQueueSize: Int = 1000
    /// Seconds of inactivity after which a new session starts.
    public var sessionTimeout: TimeInterval = 30 * 60
    /// Send app_install, app_open, app_background and session_start events automatically.
    public var trackLifecycle: Bool = true
    /// Whether to read the IDFA. The SDK NEVER requests ATT permission; it reads the IDFA only if the app has permission and `ads` consent is granted.
    public var collectAdvertisingId: Bool = false
    /// Whether to fetch the Apple Search Ads attribution token (AdServices) on first launch (no ATT required).
    public var collectAppleSearchAdsToken: Bool = true
    /// Update the SKAdNetwork / AdAttributionKit conversion value automatically from the schema defined on the
    /// ColayAI dashboard (iOS source → conversion values). Also registers the install for attribution on first launch.
    /// Turn off if you call `Colay.updateConversionValue` yourself or use another attribution SDK for this.
    public var automaticConversionValue: Bool = true
    /// Verbose console logging.
    public var debug: Bool = false

    public init() {}
}
