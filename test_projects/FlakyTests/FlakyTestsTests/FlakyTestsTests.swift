//
//  FlakyTestsTests.swift
//  FlakyTestsTests
//
//  Created by Josh Holtz on 5/15/24.
//

import XCTest
@testable import FlakyTests

final class FlakyTestsTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRandomFailure() {
        // Generate a random number between 0 and 1
        let randomValue = Double.random(in: 0..<1)

        // Check if the random value falls within the 75% failure range
        if randomValue < 0.75 {
            // Fail the test
            XCTFail("Random failure triggered")
        } else {
            // Pass the test
            XCTAssertTrue(true)
        }
    }

}
