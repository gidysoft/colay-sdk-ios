import XCTest
@testable import ColayExample

@MainActor
final class MainViewModelTests: XCTestCase {

    private final class FakeTracker: AnalyticsTracking {
        var calls: [String] = []
        func setConsent(analytics: Bool, ads: Bool) { calls.append("consent:\(analytics)") }
        func screen(_ name: String, properties: [String: Any]) { calls.append("screen:\(name)") }
        func track(_ event: String, properties: [String: Any]) { calls.append("track:\(event)") }
        func identify(_ userId: String, traits: [String: Any]) { calls.append("identify:\(userId)") }
        func purchase(_ amount: Double, currency: String, properties: [String: Any]) { calls.append("purchase:\(amount):\(currency)") }
        func flush(completion: @escaping () -> Void) { calls.append("flush"); completion() }
        func reset() { calls.append("reset") }
    }

    func testEventsAreNotSentBeforeConsent() {
        let tracker = FakeTracker()
        let vm = MainViewModel(tracker: tracker)
        vm.addToCart()
        XCTAssertTrue(tracker.calls.isEmpty)
        XCTAssertEqual(vm.sentCount, 0)
    }

    func testEventsAreSentAfterConsent() {
        let tracker = FakeTracker()
        let vm = MainViewModel(tracker: tracker)
        vm.toggleConsent()
        vm.signUp()
        vm.purchase()
        XCTAssertEqual(tracker.calls, ["consent:true", "track:sign_up", "identify:example-user-1", "purchase:149.9:USD"])
        XCTAssertEqual(vm.sentCount, 2)
    }

    func testSignOutResetsTrackerAndCounter() {
        let tracker = FakeTracker()
        let vm = MainViewModel(tracker: tracker)
        vm.toggleConsent(); vm.addToCart(); vm.signOut()
        XCTAssertEqual(tracker.calls.last, "reset")
        XCTAssertEqual(vm.sentCount, 0)
    }
}
