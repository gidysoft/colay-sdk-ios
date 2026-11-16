import Foundation

/// ColayAI tracking SDK.
///
/// ```swift
/// // AppDelegate / App init
/// Colay.start(key: "colay_pk_xxx")
///
/// Colay.screen("Cart")
/// Colay.track("sign_up", ["method": "email"])
/// Colay.identify("u_123", traits: ["email": "jane@example.com"])
/// Colay.purchase(149.90, currency: "USD", ["orderId": "A-1001"])
///
/// // Opened from a link (SceneDelegate / .onOpenURL)
/// Colay.handleDeepLink(url)
/// ```
///
/// Every call returns immediately; work happens in the background. Calls made before `start` are ignored.
public enum Colay {

    private static let lock = NSLock()
    private static var client: Client?

    /// Initializes the SDK. Call it once when the app launches.
    public static func start(key: String, config: ColayConfig = ColayConfig()) {
        lock.lock(); defer { lock.unlock() }
        guard client == nil else { return }
        precondition(key.hasPrefix("colay_pk_"), "ColayAI: the publishable key must start with 'colay_pk_'")
        client = Client(key: key, config: config)
    }

    /// Custom or standard event (see PROTOCOL.md: sign_up, login, lead, purchase…).
    public static func track(_ name: String, _ properties: [String: Any] = [:]) {
        c()?.track(name, properties)
    }

    /// Screen view. Screen funnels are built from these events.
    public static func screen(_ name: String, _ properties: [String: Any] = [:]) {
        c()?.screen(name, properties)
    }

    /// The user signed in or signed up: earlier anonymous events are linked to this user.
    public static func identify(_ userId: String, traits: [String: Any] = [:]) {
        c()?.identify(userId, traits)
    }

    /// Purchase. The spend vs. revenue report is built from this event.
    public static func purchase(_ amount: Double, currency: String, _ properties: [String: Any] = [:]) {
        c()?.track("purchase", properties, revenue: amount, currency: currency)
    }

    /// The user's consent. It is persisted and applies to later app launches too.
    public static func setConsent(_ consent: ColayConsent) {
        c()?.setConsent(consent)
    }

    /// Call when the app is opened from a link (universal link or custom scheme).
    public static func handleDeepLink(_ url: URL) {
        c()?.handleDeepLink(url)
    }

    /// The user signed out: the user link is cleared and a new anonymous ID is generated.
    public static func reset() {
        c()?.reset()
    }

    /// Tries to send queued events right away.
    public static func flush(completion: (() -> Void)? = nil) {
        c()?.flush(completion: completion)
    }

    /// SKAdNetwork / AdAttributionKit conversion value (0-63), e.g. sign-up = 10, purchase = 40.
    /// The meaning of each value is defined on the "Tracking setup" page of the ColayAI dashboard.
    public static func updateConversionValue(_ fine: Int, coarse: ColayCoarseValue? = nil, lockWindow: Bool = false) {
        PlatformInfo.updateConversionValue(fine, coarse: coarse, lockWindow: lockWindow)
    }

    /// The device's anonymous ID (for support and debugging).
    public static var anonymousId: String { client?.currentAnonymousId ?? "" }

    private static func c() -> Client? {
        if let client { return client }
        print("[ColaySDK] Used before Colay.start was called; event ignored")
        return nil
    }
}

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, macOS 10.15, *)
public extension View {
    /// Sends a screen_view when a SwiftUI view appears: `.colayScreen("Cart")`.
    func colayScreen(_ name: String, _ properties: [String: Any] = [:]) -> some View {
        onAppear { Colay.screen(name, properties) }
    }
}
#endif
