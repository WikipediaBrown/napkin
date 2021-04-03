import XCTest

import napkinTests

var tests = [XCTestCaseEntry]()
tests += napkinTests.allTests()
XCTMain(tests)
