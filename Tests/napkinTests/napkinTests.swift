import XCTest
@testable import napkin

final class napkinTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(napkin().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
