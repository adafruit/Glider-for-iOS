//
//  Glider_SimulateBluetoothUITests.swift
//  Glider SimulateBluetoothUITests
//
//  Created by Antonio García on 14/12/21.
//

import XCTest

class Glider_SimulateBluetoothUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func testSnapshots() throws {
        
        let app = XCUIApplication()
        snapshot("01_Scan")
        
        app.buttons["-"].tap()
        snapshot("02_Info")
        
        app.tabBars["Tab Bar"].buttons["Explorer"].tap()
        snapshot("03_Explorer")
        
        app.tables/*@START_MENU_TOKEN@*/.buttons["code.py, 2 KB"]/*[[".cells[\"code.py, 2 KB\"].buttons[\"code.py, 2 KB\"]",".buttons[\"code.py, 2 KB\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        snapshot("04_Code")
    }
    
    /*
     func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }*/

    /*
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }*/
}
