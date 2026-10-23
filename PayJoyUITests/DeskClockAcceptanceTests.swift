import XCTest

@MainActor
final class DeskClockAcceptanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testAutomaticEntryExitSuppressionAndAppearance() throws {
        let app = try launchDeskFixture("featured-home")
        try enterTabletop(in: app)
        let time = clock(in: app, title: "距下班", value: "03:06:00")
        let start = app.buttons["开始专注 · 25 分钟"]
        XCTAssertTrue(start.isHittable)
        XCTAssertLessThan(time.frame.maxY, start.frame.minY)
        for button in [app.buttons["返回"], appearance(in: app), start] {
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "¥", "¥")).firstMatch.exists)
        let originalAppearance = appearance(in: app).label
        appearance(in: app).tap()
        XCTAssertNotEqual(appearance(in: app).label, originalAppearance)
        appearance(in: app).tap()
        XCTAssertEqual(appearance(in: app).label, originalAppearance)
        attachScreenshot("desk-working-controls")

        app.buttons["返回"].tap()
        assertNoDesk(in: app)
        try requestPose("Rotate Right")
        assertNoDesk(in: app)
        try requestPose("Rotate Right")
        assertNoDesk(in: app)
        try requestPose("Open")
        try enterTabletop(in: app)
        _ = clock(in: app, title: "距下班", value: "03:06:00")
        attachScreenshot("desk-reentered-after-open")
        app.terminate()
    }

    func testOtherTabAndSalaryEditorKeepDraftInsteadOfEnteringDesk() throws {
        let app = try launchDeskFixture("featured-home")
        try enterTabletop(in: app)
        app.buttons["返回"].tap()
        try requestPose("Open")
        app.buttons["我的"].tap()
        try setTabletopPose()
        assertNoDesk(in: app)
        attachScreenshot("desk-blocked-by-profile-root")
        try requestPose("Open")
        let salary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "薪资设置")).firstMatch
        XCTAssertTrue(salary.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if salary.isHittable { break }
            app.swipeUp()
        }
        salary.tap()
        let field = app.textFields["10000"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("7")
        let draft = try XCTUnwrap(field.value as? String)
        XCTAssertEqual(draft.filter { $0 == "7" }.count, 1)
        try setTabletopPose()
        assertNoDesk(in: app)
        XCTAssertEqual(field.value as? String, draft)
        app.typeText("8")
        XCTAssertEqual(field.value as? String, draft.replacingOccurrences(of: "7", with: "78"))
        XCTAssertTrue(app.buttons["保存设置"].exists)
        attachScreenshot("desk-blocked-by-salary-editor")
        app.terminate()
    }

    func testEarlyCloseConfirmationAndReceiptBlockAutomaticEntry() throws {
        let app = try launchDeskFixture("featured-home")
        try enterTabletop(in: app)
        app.buttons["返回"].tap()
        try requestPose("Open")
        try openEarlyClose(in: app)
        try setTabletopPose()
        assertNoDesk(in: app)
        let dialog = app.scrollViews.containing(.staticText, identifier: "确认提前收工？").firstMatch
        let confirm = dialog.buttons["确认收工"]
        attachScreenshot("desk-early-close-before-hit-test")
        XCTAssertTrue(confirm.exists, app.debugDescription)
        XCTAssertGreaterThanOrEqual(confirm.frame.height, 44)
        attachScreenshot("desk-blocked-by-early-close-confirmation")
        print("PAYJOY_EARLY_CONFIRM_NATIVE_HIT \(confirm.isHittable)")
        dialog.buttons["取消"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(appearance(in: app).waitForExistence(timeout: 10))

        app.buttons["返回"].tap()
        try requestPose("Open")
        try openEarlyClose(in: app)
        try setTabletopPose()
        assertNoDesk(in: app)
        app.buttons["确认收工"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["今天过得怎么样？点一下就好。"].waitForExistence(timeout: 10))
        assertNoDesk(in: app)
        attachScreenshot("desk-blocked-by-receipt-draft")
        app.buttons["关闭"].firstMatch.tap()
        _ = clock(in: app, title: "下次上班", value: "18:06:00")
        XCTAssertTrue(app.buttons["收下今天"].exists, "Opening the receipt must not accept it automatically")
        attachScreenshot("desk-after-early-close")
        app.terminate()
    }

    func testWorkStateClocksAndActions() throws {
        for (screen, title, value, offersReceipt) in [
            ("featured-home", "距下班", "03:06:00", false),
            ("desk-lunch", "午休暂停 · 距下班", "06:00:00", false),
            ("desk-before-work", "下次上班", "01:30:00", false),
            ("desk-after-work", "下次上班", "14:30:00", true),
            ("desk-rest-day", "下次上班", "18:06:00", false)
        ] {
            let app = try launchDeskFixture(screen)
            try enterTabletop(in: app)
            _ = clock(in: app, title: title, value: value)
            XCTAssertTrue(app.buttons["开始专注 · 25 分钟"].isHittable)
            XCTAssertEqual(app.buttons["收下今天"].exists, offersReceipt)
            XCTAssertFalse(app.buttons["结束加班"].exists)
            attachScreenshot(screen)
            app.terminate()
        }
    }

    func testNoNextWorkdayShowsRestingClock() throws {
        let app = try launchDeskFixture("desk-no-next-work")
        try enterTabletop(in: app)
        _ = clock(in: app, title: "今天", value: "休息中")
        XCTAssertTrue(app.buttons["开始专注 · 25 分钟"].isHittable)
        attachScreenshot("desk-no-next-work")
        app.terminate()
    }

    func testCrossMidnightOvertimeCancelAndConfirmUsesReceiptFlow() throws {
        let app = try launchDeskFixture("desk-overtime-midnight")
        try enterTabletop(in: app)
        _ = clock(in: app, title: "本次加班时长", value: "01:33:00")
        XCTAssertFalse(app.buttons["开始专注 · 25 分钟"].exists)
        app.buttons["结束加班"].tap()
        XCTAssertTrue(app.staticTexts["选择结束时间"].waitForExistence(timeout: 10))
        attachScreenshot("desk-overtime-confirmation")
        app.buttons["完成"].tap()
        _ = clock(in: app, title: "本次加班时长", value: "01:33:00")
        app.buttons["结束加班"].tap()
        let sheet = app.scrollViews.containing(.staticText, identifier: "选择结束时间").firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        let finish = sheet.buttons["结束加班"]
        for _ in 0..<4 {
            if finish.isHittable { break }
            sheet.swipeUp()
        }
        XCTAssertTrue(finish.isHittable)
        finish.tap()
        XCTAssertTrue(app.staticTexts["今天过得怎么样？点一下就好。"].waitForExistence(timeout: 10))
        attachScreenshot("desk-overtime-receipt-draft")
        let receipt = app.scrollViews.containing(.staticText, identifier: "今天过得怎么样？点一下就好。").firstMatch
        XCTAssertTrue(receipt.staticTexts["¥818.18"].exists, app.debugDescription)
        app.buttons["关闭"].firstMatch.tap()
        XCTAssertFalse(app.buttons["结束加班"].exists)
        app.terminate()
    }

    private func launchDeskFixture(_ screen: String) throws -> XCUIApplication {
        try requirePoseHost()
        try requestPose("Open")
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "en_US"]
        app.launchEnvironment = ["PAYJOY_SCREENSHOT_MODE": "1", "PAYJOY_SCREENSHOT_SCREEN": screen,
                                 "PAYJOY_SCREENSHOT_LANGUAGE": "zhHans", "PAYJOY_SCREENSHOT_THEME": "classic",
                                 "PAYJOY_DESK_AUDIT": "1"]
        app.launch()
        XCTAssertTrue(app.buttons["首页"].waitForExistence(timeout: 15))
        return app
    }

    private func appearance(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", ["切换为白底", "切换为黑底"])).firstMatch
    }

    private func enterTabletop(in app: XCUIApplication) throws {
        try setTabletopPose()
        XCTAssertTrue(appearance(in: app).waitForExistence(timeout: 10), app.debugDescription)
    }

    private func setTabletopPose() throws {
        let axis = try requestPose("Partially Open", readsLayout: true)
        if axis == "vertical" {
            XCTAssertEqual(try requestPose("Rotate Right", readsLayout: true), "horizontal")
        } else {
            XCTAssertEqual(axis, "horizontal")
        }
    }

    private func assertNoDesk(in app: XCUIApplication) {
        XCTAssertFalse(appearance(in: app).waitForExistence(timeout: 2))
    }

    @discardableResult
    private func clock(in app: XCUIApplication, title: String, value: String) -> XCUIElement {
        let time = app.staticTexts.matching(NSPredicate(format: "label == %@ AND value == %@", title, value)).firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 10), app.debugDescription)
        return time
    }

    private func openEarlyClose(in app: XCUIApplication) throws {
        let button = app.buttons["提前下班"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        let scroll = app.scrollViews.containing(.button, identifier: "提前下班").firstMatch
        for _ in 0..<6 {
            if button.isHittable { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(button.isHittable)
        button.tap()
        XCTAssertTrue(app.staticTexts["确认提前收工？"].waitForExistence(timeout: 10))
    }
}
