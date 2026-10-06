import XCTest

/// Maakt App Store-screenshots. Slaat zichzelf over tenzij `GB_SCREENSHOTS=1` is gezet.
/// Draai handmatig op de 6,9"-simulator (iPhone 17 Pro Max) of een 13"-iPad:
///   xcrun simctl status_bar <device> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
///   TEST_RUNNER_GB_SCREENSHOTS=1 xcodebuild -scheme Garantiebewaarder -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
///     test -only-testing:GarantiebewaarderUITests/ScreenshotUITests
/// De beelden komen in /tmp/gb-shots/<taal>/.
@MainActor
final class ScreenshotUITests: XCTestCase {
    private func launch(_ language: String, _ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        let locale = language == "nl" ? "nl_NL" : "en_US"
        app.launchArguments += ["-UITesting", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + extra
        app.launch()
        return app
    }

    private func shoot(_ language: String, _ name: String) {
        let dir = URL(fileURLWithPath: "/tmp/gb-shots/\(language)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Thread.sleep(forTimeInterval: 0.8) // animaties laten uitlopen
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
    }

    private func capture(_ language: String) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["GB_SCREENSHOTS"] == "1", "Zet TEST_RUNNER_GB_SCREENSHOTS=1 om screenshots te maken")
        // 1. Overzicht
        var app = launch(language, ["-DemoData"])
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        shoot(language, "01-overzicht")

        // 3 + 4 + 6. Detail, bon op volledig scherm, claimhulp
        let rows = app.buttons.matching(identifier: "productRow")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
        rows.element(boundBy: 1).tap() // wasmachine
        XCTAssertTrue(app.staticTexts["detailName"].waitForExistence(timeout: 5))
        shoot(language, "03-detail")
        let thumb = app.buttons["attachmentThumb"].firstMatch
        scrollTo(thumb, in: app)
        if thumb.exists {
            thumb.tap()
            XCTAssertTrue(app.buttons["closeViewerButton"].waitForExistence(timeout: 5))
            shoot(language, "04-bon")
            app.buttons["closeViewerButton"].tap()
        }
        let claim = app.buttons["claimHelpLink"]
        scrollTo(claim, in: app)
        claim.tap()
        XCTAssertTrue(app.descendants(matching: .any)["claimDisclaimer"].firstMatch.waitForExistence(timeout: 5))
        shoot(language, "06-claimhulp")
        app.terminate()

        // 2. Bon herkend
        app = launch(language, ["-DemoSeedReceipt"])
        XCTAssertTrue(app.descendants(matching: .any)["recognitionBanner"].firstMatch.waitForExistence(timeout: 10))
        shoot(language, "02-herkenning")
        app.terminate()

        // 5. Herinneringen
        app = launch(language, ["-DemoData"])
        app.buttons["settingsButton"].tap()
        let toggle = app.descendants(matching: .any)["remindersToggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        // Rustig scrollen (korter dan swipeUp) zodat de kop "Herinneringen" bovenaan staat.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.50)))
        shoot(language, "05-herinneringen")
        app.terminate()

        // 7. Privacy (onboarding pagina 2)
        app = launch(language, ["-UITestingOnboarding"])
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        shoot(language, "07-privacy")
        app.terminate()
    }

    func testCaptureDutch() throws { try capture("nl") }
    func testCaptureEnglish() throws { try capture("en") }
}
