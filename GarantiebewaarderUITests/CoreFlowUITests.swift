import XCTest

@MainActor
final class CoreFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launchApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITesting", "-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launch()
    }

    private func addProduct(named name: String, store: String = "") {
        let add = app.buttons["addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let manual = app.buttons["manualButton"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        if !store.isEmpty {
            let storeField = app.textFields["storeField"]
            storeField.tap()
            storeField.typeText(store)
        }
        app.buttons["saveButton"].tap()
    }

    func testAddOpenEditDelete() throws {
        launchApp()
        XCTAssertTrue(app.buttons["emptyAddButton"].waitForExistence(timeout: 5))
        app.buttons["emptyAddButton"].tap()
        XCTAssertTrue(app.buttons["manualButton"].waitForExistence(timeout: 5))
        app.buttons["cancelAddButton"].tap()

        addProduct(named: "Wasmachine")
        // Na opslaan opent het detail van het nieuwe product.
        XCTAssertTrue(app.otherElements["productDetail"].waitForExistence(timeout: 5)
                      || app.staticTexts["detailName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detailName"].label, "Wasmachine")

        app.buttons["editButton"].tap()
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        let current = (nameField.value as? String) ?? ""
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "Wasmachine Bosch")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.staticTexts["detailName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detailName"].label, "Wasmachine Bosch")

        let delete = app.buttons["deleteButton"]
        for _ in 0..<4 where !delete.isHittable { app.swipeUp() }
        delete.tap()
        let confirm = app.buttons["confirmDeleteButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["emptyAddButton"].waitForExistence(timeout: 5))
    }

    func testSearchFiltersList() throws {
        launchApp()
        addProduct(named: "Laptop", store: "Coolblue")
        XCTAssertTrue(app.staticTexts["detailName"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        addProduct(named: "Wasmachine")
        XCTAssertTrue(app.staticTexts["detailName"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertEqual(app.cells.matching(identifier: "productRow").count
                       + app.buttons.matching(identifier: "productRow").count, 2)

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("coolblue")
        XCTAssertTrue(app.staticTexts["Laptop"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Wasmachine"].exists)
    }
}
