import XCTest
@testable import OpenWriteKit

final class WritingCoreTests: XCTestCase {
    func testWritingSuiteL0() throws {
        for test in WritingTestSuite.defaultSuite() {
            try test.run()
        }
    }
}
