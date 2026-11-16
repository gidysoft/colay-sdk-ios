import XCTest

/// End to end: consent → screen → cart → sign-up → purchase → deep link → flush.
/// Events appear in the dashboard under "Tracking setup → Test" or "User journey → Events".
final class ColayExampleUITests: XCTestCase {
    func testSendsAllEventTypes() throws {
        let app = XCUIApplication()
        app.launch()
        for id in ["consent", "viewProduct", "addToCart", "signUp", "purchase"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing button: \(id)")
            button.tap()
        }
        if #available(iOS 16.4, *) {
            app.open(URL(string: "colayexample://campaign?utm_source=instagram&utm_medium=paid_social&utm_campaign=winter-sale&fbclid=TESTFBCLID123")!)
            app.activate()
        }
        let flush = app.buttons["flush"]
        XCTAssertTrue(flush.waitForExistence(timeout: 10))
        flush.tap()
        let status = app.staticTexts["status"]
        let sent = NSPredicate(format: "label == %@", "Queue sent to the server")
        expectation(for: sent, evaluatedWith: status)
        waitForExpectations(timeout: 20)
    }
}
