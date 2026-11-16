import Foundation
import ColaySDK

/// `AnalyticsTracking` implementation backed by the Colay AI SDK.
struct ColayAnalyticsTracker: AnalyticsTracking {
    func setConsent(analytics: Bool, ads: Bool) { Colay.setConsent(ColayConsent(analytics: analytics, ads: ads)) }
    func screen(_ name: String, properties: [String: Any]) { Colay.screen(name, properties) }
    func track(_ event: String, properties: [String: Any]) { Colay.track(event, properties) }
    func identify(_ userId: String, traits: [String: Any]) { Colay.identify(userId, traits: traits) }
    func purchase(_ amount: Double, currency: String, properties: [String: Any]) {
        Colay.purchase(amount, currency: currency, properties)
        Colay.updateConversionValue(10)   // optional: SKAdNetwork / AdAttributionKit
    }
    func flush(completion: @escaping () -> Void) { Colay.flush(completion: completion) }
    func reset() { Colay.reset() }
}
