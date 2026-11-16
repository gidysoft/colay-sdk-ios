import Foundation

/// Main screen logic. Each user action maps to one analytics call:
///
/// - **Step 2 — Consent:** `toggleConsent()`
/// - **Step 3 — Screens:** `onAppear()`, `viewProduct()`
/// - **Step 4 — Events:** `addToCart()`, `signUp()` (standard event names are listed in the README)
/// - **Step 5 — User:** `identify` after sign-in
/// - **Step 6 — Purchase:** `purchase()`
@MainActor
final class MainViewModel: ObservableObject {
    @Published private(set) var consentGranted = false
    @Published private(set) var lastAction = "Grant consent first."
    @Published private(set) var sentCount = 0

    private let tracker: AnalyticsTracking
    private static let productId = "thermos-500"
    private static let price = 149.90

    init(tracker: AnalyticsTracking) {
        self.tracker = tracker
    }

    func onAppear() {
        tracker.screen("Home", properties: [:])
    }

    func toggleConsent() {
        consentGranted.toggle()
        tracker.setConsent(analytics: consentGranted, ads: consentGranted)
        lastAction = consentGranted ? "Consent granted: events will be sent." : "Consent withdrawn: nothing is sent."
    }

    func viewProduct() {
        record("screen_view: Product detail") { $0.screen("Product detail", properties: ["productId": Self.productId]) }
    }

    func addToCart() {
        record("add_to_cart") { $0.track("add_to_cart", properties: ["productId": Self.productId, "price": Self.price]) }
    }

    func signUp() {
        record("sign_up + identify") {
            $0.track("sign_up", properties: ["method": "email"])
            $0.identify("example-user-1", traits: ["email": "user@example.com"])
        }
    }

    func purchase() {
        record("purchase: 149.90 USD") {
            $0.purchase(Self.price, currency: "USD", properties: ["orderId": "EXAMPLE-\(Int(Date().timeIntervalSince1970))"])
        }
    }

    func flush() {
        lastAction = "Sending the queue to the server"
        tracker.flush { [weak self] in
            Task { @MainActor in self?.lastAction = "Queue sent to the server" }
        }
    }

    func signOut() {
        tracker.reset()
        sentCount = 0
        lastAction = "User and session reset"
    }

    private func record(_ label: String, _ send: (AnalyticsTracking) -> Void) {
        guard consentGranted else {
            lastAction = "Grant consent first (no events are sent without consent)."
            return
        }
        send(tracker)
        sentCount += 1
        lastAction = "\(label) sent"
    }
}
