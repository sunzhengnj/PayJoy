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
            field.tap()
            field.typeText(input)
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
            field.tap()
            field.typeText(input)
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
            XCTAssertGreaterThanOrEqual(menu.frame.width, 44)
            XCTAssertGreaterThanOrEqual(menu.frame.height, 44)
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

    func testFocusDraftAndInsertionPointAcrossHingeChanges() throws {
        try requirePoseHost()
        try requestPose("Open")
        let app = launchFixture("focus-setup")
        app.buttons["自定"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("　４５　")
        try verifyDraftAcrossPoses(in: app, field: field, expected: "　４５　", name: "focus", actionTitle: "开始专注")
        XCTAssertTrue(app.buttons["开始专注"].isEnabled)
        app.terminate()
    }

    func testSalaryDraftAndInsertionPointAcrossHingeChanges() throws {
        try requirePoseHost()
        try requestPose("Open")
        let app = launchFixture("salary-settings", locale: "de_DE")
        let field = app.textFields["10000"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        replaceText(in: field, with: "１２．３４５，６７")
        try verifyDraftAcrossPoses(in: app, field: field, expected: "１２．３４５，６７", name: "salary", actionTitle: "保存设置")
        app.terminate()
    }

    func testNormalSalarySurvivesProcessRelaunch() throws {
        try requirePoseHost()
        try requestPose("Open")
        for (locale, input) in [("ja_JP", "１２，３４５．６７"), ("de_DE", "１２．３４５，６７")] {
            let app = launchNormalSalary(locale: locale)
            let amount = app.textFields["10000"]
            let days = app.textFields["月计薪天数"]
            let originalAmount = try XCTUnwrap(amount.value as? String)
            let originalDays = try XCTUnwrap(days.value as? String)
            let original = ["locale": locale, "amount": originalAmount, "days": originalDays]
            let data = try JSONSerialization.data(withJSONObject: original, options: [.sortedKeys])
            FileHandle.standardOutput.write(Data("PAYJOY_ORIGINAL_SALARY ".utf8) + data + Data("\n".utf8))
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: locale)
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false
            // Prove a new write: the simulator may already contain the expected target values.
            replaceText(in: amount, with: try XCTUnwrap(formatter.string(from: 24123.89)))
            replaceText(in: days, with: try XCTUnwrap(formatter.string(from: 20.5)))
            app.buttons["保存设置"].tap()
            app.terminate()

            let seeded = launchNormalSalary(locale: locale)
            let baseline = try XCTUnwrap(seeded.textFields["10000"].value as? String)
            let baselineDays = try XCTUnwrap(seeded.textFields["月计薪天数"].value as? String)
            XCTAssertEqual(try XCTUnwrap(formatter.number(from: baseline)).doubleValue, 24123.89, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(formatter.number(from: baselineDays)).doubleValue, 20.5, accuracy: 0.001)
            attachScreenshot("normal-salary-baseline-\(locale)")
            replaceText(in: seeded.textFields["10000"], with: input)
            let daysInput = locale == "de_DE" ? "２１，７５８" : "２１．７５８"
            replaceText(in: seeded.textFields["月计薪天数"], with: daysInput)
            for action in ["Partially Open", "Rotate Right", "Open"] {
                try requestPose(action)
                XCTAssertEqual(seeded.textFields["10000"].value as? String, input)
                XCTAssertEqual(seeded.textFields["月计薪天数"].value as? String, daysInput)
                attachScreenshot("normal-salary-before-save-\(locale)-\(action)")
            }
            seeded.buttons["保存设置"].tap()
            seeded.terminate()

            let reopened = launchNormalSalary(locale: locale)
            let savedAmount = try XCTUnwrap(reopened.textFields["10000"].value as? String)
            let savedDays = try XCTUnwrap(reopened.textFields["月计薪天数"].value as? String)
            XCTAssertEqual(try XCTUnwrap(formatter.number(from: savedAmount)).doubleValue, 12345.67, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(formatter.number(from: savedDays)).doubleValue, 21.75, accuracy: 0.001)
            attachScreenshot("normal-salary-relaunched-\(locale)")

            replaceText(in: reopened.textFields["10000"], with: originalAmount)
            replaceText(in: reopened.textFields["月计薪天数"], with: originalDays)
            reopened.buttons["保存设置"].tap()
            reopened.terminate()
            let restored = launchNormalSalary(locale: locale)
            XCTAssertEqual(restored.textFields["10000"].value as? String, originalAmount)
            XCTAssertEqual(restored.textFields["月计薪天数"].value as? String, originalDays)
            attachScreenshot("normal-salary-restored-\(locale)")
            restored.terminate()
        }
    }

    private func launchNormalSalary(locale: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", locale]
        app.launchEnvironment = [:]
        app.launch()
        let profile = app.buttons["我的"]
        XCTAssertTrue(profile.waitForExistence(timeout: 15), "Normal-mode simulator must have finished onboarding")
        profile.tap()
        openSalarySettings(in: app)
        XCTAssertTrue(app.textFields["10000"].waitForExistence(timeout: 10))
        return app
    }

    private func requirePoseHost() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PAYJOY_DUO_POSE_HOST"] == "1",
                          "Use PayJoyPoseUITests with scripts/qa/run_duo_pose_tests.py")
    }

    private func verifyDraftAcrossPoses(in app: XCUIApplication, field: XCUIElement, expected: String, name: String, actionTitle: String) throws {
        for (index, action) in ["Partially Open", "Rotate Right", "Open", "Closed", "Open"].enumerated() {
            try requestPose(action)
            XCTAssertEqual(field.value as? String, expected)
            // Type through the app without tapping the field again: focus and caret must survive.
            app.typeText("7")
            XCTAssertEqual(field.value as? String, expected + "7")
            app.typeText(XCUIKeyboardKey.delete.rawValue)
            XCTAssertEqual(field.value as? String, expected)
            attachScreenshot("\(name)-pose-\(index)-\(action)")

            let primary = app.buttons[actionTitle]
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<5 {
                if primary.isHittable { break }
                scroll.swipeUp()
            }
            XCTAssertTrue(primary.isHittable, "Primary action must be reachable within the current fold pane")
            XCTAssertGreaterThanOrEqual(primary.frame.width, 44)
            XCTAssertGreaterThanOrEqual(primary.frame.height, 44)
            attachScreenshot("\(name)-action-\(index)-\(action)")
            // Explicitly return to editing after checking the action's scroll reachability.
            field.tap()
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        }
    }

    private func requestPose(_ action: String) throws {
        let id = UUID().uuidString
        let requestURL = FileManager.default.temporaryDirectory.appendingPathComponent("payjoy-duo-pose-\(id).json")
        let ackURL = requestURL.appendingPathExtension("ack")
        defer {
            try? FileManager.default.removeItem(at: requestURL)
            try? FileManager.default.removeItem(at: ackURL)
        }
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "action": action, "ack": ackURL.path], options: [.sortedKeys])
        try data.write(to: requestURL, options: .atomic)
        let marker = "PAYJOY_DUO_POSE_REQUEST \(requestURL.path)\n"
        FileHandle.standardOutput.write(Data(marker.utf8))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: ackURL.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 35), .completed, "Host did not confirm \(action)")
        let ack = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: ackURL)) as? [String: String])
        XCTAssertEqual(ack["id"], id)
        XCTAssertEqual(ack["action"], action)
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
        if let value = field.value as? String, !value.isEmpty {
            let middle = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = field.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: field.frame.width + 24, dy: field.frame.height / 2))
            middle.press(forDuration: 0.6, thenDragTo: end)
            field.typeText("7")
            XCTAssertEqual(field.value as? String, value + "7", "Move the caret to the end before clearing")
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count + 1))
        }
        let empty = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let value = field.value as? String
            return value == nil || value == "" || value == field.placeholderValue
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [empty], timeout: 5), .completed,
                       "Clear the entire previous value before typing; actual: \(field.value ?? "nil")")
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
