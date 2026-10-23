import XCTest

@MainActor
final class InputAcceptanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testFullWidthFocusMinutesStartTheRequestedDuration() {
        for (input, expected) in [("２５", "25:00"), ("2５", "25:00"), ("　４５　", "45:00")] {
            let app = launchFixture("focus-setup")
            app.buttons["自定"].tap()
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            replaceText(in: field, with: input)
            XCTAssertEqual(field.value as? String, input, "Keep the unnormalized draft")
            attachScreenshot("focus-draft-\(expected)")
            let start = app.buttons["开始专注"]
            XCTAssertTrue(start.isEnabled)
            start.tap()
            let clock = app.staticTexts.matching(NSPredicate(format: "value == %@", expected)).firstMatch
            XCTAssertTrue(clock.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertTrue(app.buttons["暂停"].exists)
            attachScreenshot("focus-started-\(expected)")
            app.terminate()
        }
    }

    func testInvalidFocusMinutesCannotStartASession() {
        for input in ["0", "241", "25.5", "25 minutes"] {
            let app = launchFixture("focus-setup")
            app.buttons["自定"].tap()
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            replaceText(in: field, with: input)
            XCTAssertEqual(field.value as? String, input)
            XCTAssertFalse(app.buttons["开始专注"].isEnabled)
            XCTAssertFalse(app.buttons["暂停"].exists)
            XCTAssertTrue(app.staticTexts["请输入 1–240 分钟（整数）"].exists)
            attachScreenshot("focus-rejected-\(input)")
            app.terminate()
        }
    }

    func testChangingClockDisplayKeepsFocusRunning() {
        let app = launchFixture("focus-setup")
        app.buttons["开始专注"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 10))
        for (current, next) in [("本段剩余", "距下班"), ("距下班", "本段剩余")] {
            let menu = app.buttons.matching(identifier: current).firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 10), app.debugDescription)
            menu.tap()
            app.buttons[next].tap()
            XCTAssertTrue(app.buttons["暂停"].exists)
            XCTAssertFalse(app.buttons["继续"].exists)
            XCTAssertTrue(app.buttons.matching(identifier: next).firstMatch.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "专注已暂停")).firstMatch.exists)
            attachScreenshot("focus-running-\(next)")
        }
        app.terminate()
    }

    func testFullWidthSalaryDecimalsFollowTheRegion() throws {
        for (locale, input) in [("ja_JP", "１２，３４５．６７"), ("de_DE", "１２．３４５，６７")] {
            let app = launchFixture("salary-settings", locale: locale)
            let amount = app.textFields["10000"]
            XCTAssertTrue(amount.waitForExistence(timeout: 10))
            replaceText(in: amount, with: input)
            XCTAssertEqual(amount.value as? String, input)
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: locale)
            formatter.numberStyle = .decimal
            attachScreenshot("salary-input-\(locale)")
            if locale == "de_DE" {
                let paidDays = app.textFields["月计薪天数"]
                replaceText(in: paidDays, with: "２１，７５８")
                XCTAssertEqual(paidDays.value as? String, "２１，７５８")
            }
            app.buttons["保存设置"].tap()
            openSalarySettings(in: app)
            let savedAmount = app.textFields["10000"]
            XCTAssertTrue(savedAmount.waitForExistence(timeout: 10))
            let displayed = try XCTUnwrap(savedAmount.value as? String)
            let value = try XCTUnwrap(formatter.number(from: displayed))
            XCTAssertEqual(value.doubleValue, 12345.67, accuracy: 0.001, "Saved region \(locale), field \(displayed)")
            if locale == "de_DE" {
                let paidDays = app.textFields["月计薪天数"]
                let daysText = try XCTUnwrap(paidDays.value as? String)
                let days = try XCTUnwrap(formatter.number(from: daysText))
                XCTAssertEqual(days.doubleValue, 21.75, accuracy: 0.001)
            }
            attachScreenshot("salary-decimal-\(locale)")
            app.terminate()
        }
    }

    func testExpandedSalaryInputsFitWithoutScrolling() {
        let app = launchFixture("salary-settings")
        XCUIDevice.shared.orientation = .landscapeRight
        let viewport = app.scrollViews.containing(.textField, identifier: "10000").firstMatch
        XCTAssertTrue(viewport.exists)
        let steppers = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "0.25"))
        XCTAssertEqual(steppers.count, 2)
        attachScreenshot("salary-expanded-initial")
        for button in steppers.allElementsBoundByIndex {
            XCTAssertTrue(button.isHittable)
            XCTAssertTrue(viewport.frame.insetBy(dx: -1, dy: -1).contains(button.frame), "\(button.label): \(button.frame), viewport: \(viewport.frame)")
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        app.terminate()
    }

    private func launchFixture(_ screen: String, locale: String = "en_US") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", locale]
        app.launchEnvironment = [
            "PAYJOY_SCREENSHOT_MODE": "1",
            "PAYJOY_SCREENSHOT_SCREEN": screen == "focus-setup" ? "featured-focus-tab" : "root",
            "PAYJOY_SCREENSHOT_LANGUAGE": "zhHans",
            "PAYJOY_SCREENSHOT_THEME": "classic"
        ]
        app.launch()
        if screen == "salary-settings" {
            let profile = app.buttons["我的"]
            XCTAssertTrue(profile.waitForExistence(timeout: 10))
            profile.tap()
            openSalarySettings(in: app)
        }
        return app
    }

    private func openSalarySettings(in app: XCUIApplication) {
        let salary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "薪资设置")).firstMatch
        XCTAssertTrue(salary.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if salary.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(salary.isHittable, app.debugDescription)
        salary.tap()
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        if let value = field.value as? String, !value.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        let empty = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let value = field.value as? String
            return value == nil || value == "" || value == field.placeholderValue
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [empty], timeout: 5), .completed, "Clear the entire previous value before typing")
        field.typeText(text)
    }

    private func attachScreenshot(_ name: String) {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let screenshot = screen.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "\(name)-display\(index)-\(Int(screenshot.image.size.width))x\(Int(screenshot.image.size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
