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
