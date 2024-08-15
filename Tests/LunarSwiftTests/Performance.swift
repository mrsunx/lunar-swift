//
//  Performance.swift
//  
//
//  Created by zizo on 2024/8/14.
//

import XCTest
import LunarSwift

final class Performance: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {

            for _ in 0..<1000 {
                // 6s
                let _ = Lunar.fromDate(date: Date())

                // 0.328s
//                let _ = Solar.fromDate(date: Date())

                // 2.501s
//                let _ = LunarYear(lunarYear: 2024)

                // 3s
//                let _ = Lunar(lunarYear: 2024, lunarMonth: 7, lunarDay: 11, hour: 17, minute: 38, second: 0)
            }
        }
    }

}
