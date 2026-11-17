import XCTest
@testable import ColaySDK

final class AttributionTests: XCTestCase {

    func testDeepLink() {
        let url = URL(string: "exampleapp://campaign/november?utm_campaign=black%20friday&fbclid=IwAR1&colay_link=AbC12&foo=bar")!
        let a = Attribution.fromURL(url)
        XCTAssertEqual(a["utm_campaign"], "black friday")
        XCTAssertEqual(a["fbclid"], "IwAR1")
        XCTAssertEqual(a["colay_link"], "AbC12")
        XCTAssertNil(a["foo"])
    }

    func testLinkWithoutQuery() {
        XCTAssertTrue(Attribution.fromURL(URL(string: "https://example.com/path")!).isEmpty)
        XCTAssertTrue(Attribution.fromURL(URL(string: "https://example.com/?utm_source=&gclid=")!).isEmpty)
    }

    func testClickIdsRemovedWithoutAdsConsent() {
        let a = Attribution.stripClickIds(["utm_source": "fb", "fbclid": "x", "gclid": "y"])
        XCTAssertEqual(a.keys.sorted(), ["utm_source"])
    }
}

final class EventQueueTests: XCTestCase {

    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("q.jsonl")
    }

    func testPersistsAndDropsOldestAtLimit() {
        let f = tempFile()
        let q = EventQueue(fileURL: f, maxSize: 3)
        for i in 1...5 { q.add(["id": "\(i)"]) }
        XCTAssertEqual(q.count, 3)
        let again = EventQueue(fileURL: f, maxSize: 3)
        XCTAssertEqual(again.peek(10, maxBytes: 100_000).compactMap { $0["id"] as? String }, ["3", "4", "5"])
    }

    func testSentEventsAreRemoved() {
        let q = EventQueue(fileURL: tempFile(), maxSize: 100)
        for i in 1...5 { q.add(["id": "\(i)"]) }
        q.remove(q.peek(2, maxBytes: 100_000))
        XCTAssertEqual(q.peek(10, maxBytes: 100_000).compactMap { $0["id"] as? String }, ["3", "4", "5"])
    }
}

final class TransportTests: XCTestCase {
    func testResponseCodes() {
        XCTAssertEqual(SendResult.from(status: 200, retryAfter: nil), .ok)
        XCTAssertEqual(SendResult.from(status: 400, retryAfter: nil), .drop)
        XCTAssertEqual(SendResult.from(status: 401, retryAfter: nil), .unauthorized)
        XCTAssertEqual(SendResult.from(status: 413, retryAfter: nil), .tooLarge)
        XCTAssertEqual(SendResult.from(status: 429, retryAfter: "30"), .retry(after: 30))
        XCTAssertEqual(SendResult.from(status: 503, retryAfter: nil), .retry(after: nil))
    }

    func testJsonLimits() {
        let big = Dictionary(uniqueKeysWithValues: (0..<100).map { ("k\($0)", $0) })
        XCTAssertEqual(JSON.limit(big).count, 64)
        XCTAssertEqual((JSON.limit(["s": String(repeating: "x", count: 5000)])["s"] as? String)?.count, 1000)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(JSON.limit(["d": Date(), "u": URL(string: "https://a.b")!])))
    }
}

final class SkanTests: XCTestCase {

    private let rules = [
        SkanRule(event: "sign_up", fine: 10),
        SkanRule(event: "purchase", fine: 40, coarse: .high),
        SkanRule(event: "purchase", fine: 50, coarse: .high, minRevenue: 100),
    ]

    func testHighestMatchingRule() {
        XCTAssertEqual(Skan.target(rules: rules, event: "sign_up", revenue: nil, current: -1)?.fine, 10)
        XCTAssertEqual(Skan.target(rules: rules, event: "purchase", revenue: 20, current: 10)?.fine, 40)
        XCTAssertEqual(Skan.target(rules: rules, event: "purchase", revenue: 150, current: 10)?.fine, 50)
    }

    func testValueNeverGoesDown() {
        XCTAssertNil(Skan.target(rules: rules, event: "sign_up", revenue: nil, current: 40))
        XCTAssertNil(Skan.target(rules: rules, event: "purchase", revenue: 20, current: 40))
        XCTAssertNil(Skan.target(rules: rules, event: "unknown", revenue: nil, current: -1))
    }

    func testWindows() {
        let day: TimeInterval = 86_400
        XCTAssertEqual(Skan.window(installedAt: 0, now: day), 0)
        XCTAssertEqual(Skan.window(installedAt: 0, now: 3 * day), 1)
        XCTAssertEqual(Skan.window(installedAt: 0, now: 10 * day), 2)
        XCTAssertNil(Skan.window(installedAt: 0, now: 40 * day))
    }

    func testCoarseNeverGoesDown() {
        XCTAssertEqual(Skan.maxCoarse(.low, previous: 2), .high)
        XCTAssertEqual(Skan.maxCoarse(.low, previous: 1), .medium)
        XCTAssertEqual(Skan.maxCoarse(.high, previous: 1), .high)
        XCTAssertEqual(Skan.maxCoarse(.medium, previous: -1), .medium)
    }

    func testParseServerSchema() {
        let json = #"{"skan":{"rules":[{"event":"sign_up","fine":10,"coarse":"low"},{"event":"purchase","fine":70,"coarse":"high","minRevenue":5},{"fine":3}]}}"#
        let parsed = Skan.parse(Data(json.utf8))
        XCTAssertEqual(parsed?.count, 2)
        XCTAssertEqual(parsed?[1].fine, 63)
        XCTAssertEqual(parsed?[1].coarse, .high)
        XCTAssertEqual(parsed?[1].minRevenue, 5)
        XCTAssertNil(Skan.parse(Data("{}".utf8)))
    }
}
