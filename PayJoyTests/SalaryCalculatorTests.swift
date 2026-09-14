import XCTest
@testable import PayJoy

final class SalaryCalculatorTests: XCTestCase {
    private var calendar: Calendar!
    private var calculator: SalaryCalculator!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calculator = SalaryCalculator(calendar: calendar)
    }

    func testSalaryModesCalculateDailyIncome() {
        var settings = SalarySettings.defaultValue

        settings.salaryType = .monthly
        settings.salaryAmount = 10_000
        XCTAssertEqual(calculator.dailySalary(for: settings), 10_000 / 21.75, accuracy: 0.001)

        settings.salaryType = .yearly
        settings.salaryAmount = 240_000
        XCTAssertEqual(calculator.dailySalary(for: settings), 240_000 / 12 / 21.75, accuracy: 0.001)

        settings.salaryType = .daily
        settings.salaryAmount = 500
        XCTAssertEqual(calculator.dailySalary(for: settings), 500, accuracy: 0.001)

        settings.salaryType = .hourly
        settings.salaryAmount = 100
        XCTAssertEqual(calculator.dailySalary(for: settings), 900, accuracy: 0.001)
    }

    @MainActor
    func testHomeBubbleRestStateOverridesLateNightAndFriday() {
        let rest = [L10n.t("现在先休息，开工以后再说。"), L10n.t("这段时间归你，工作先放一边。")]
        for status in [WorkdayStatus.afterWork, .restDay] {
            for hour in [0, 16, 23] {
                XCTAssertEqual(HomeView.bubbleMessages(status: status, isOvertime: false, isOffDutyBeforeWork: false, hour: hour, weekday: 6), rest)
            }
        }
        XCTAssertEqual(HomeView.bubbleMessages(status: .beforeWork, isOvertime: false, isOffDutyBeforeWork: true, hour: 0, weekday: 3), rest)
        XCTAssertFalse(HomeView.bubbleMessages(status: .afterWork, isOvertime: true, isOffDutyBeforeWork: false, hour: 23, weekday: 6).contains(rest[0]))
    }

    @MainActor
    func testHomeBubbleBreakAndBeforeWorkStayInTheirOwnContext() {
        XCTAssertEqual(HomeView.bubbleMessages(status: .lunchBreak, isOvertime: false, isOffDutyBeforeWork: false, hour: 12, weekday: 3), [L10n.t("午休暂停，快乐继续。")])
        XCTAssertEqual(HomeView.bubbleMessages(status: .beforeWork, isOvertime: false, isOffDutyBeforeWork: false, hour: 0, weekday: 2), [L10n.t("开工前，钱包正在做热身。")])
    }

    func testPersistedSalarySettingsNormalizeInvalidValues() throws {
        let payload = """
        {
          "salaryType": "monthly",
          "salaryAmount": -100,
          "currencySymbol": "invalid",
          "workStart": { "hour": 22, "minute": 0 },
          "workEnd": { "hour": 21, "minute": 0 },
          "deductLunch": true,
          "lunchStart": { "hour": 8, "minute": 0 },
          "lunchEnd": { "hour": 9, "minute": 0 },
          "monthlyPaidDays": 0,
          "workdays": [0, 8]
        }
        """

        let settings = try JSONDecoder().decode(SalarySettings.self, from: Data(payload.utf8))

        XCTAssertEqual(settings.salaryAmount, 0)
        XCTAssertEqual(settings.currencySymbol, SalaryCurrency.defaultSymbol)
        XCTAssertEqual(settings.workStart, .defaultStart)
        XCTAssertEqual(settings.workEnd, .defaultEnd)
        XCTAssertFalse(settings.deductLunch)
        XCTAssertEqual(settings.monthlyPaidDays, 1)
        XCTAssertEqual(settings.workdays, Workday.defaultWeekdays)
    }

    func testWorkdaySummaryUsesConfiguredDaysInDisplayOrder() {
        var settings = SalarySettings.defaultValue
        settings.workdays = [Workday.sunday.rawValue, Workday.tuesday.rawValue]

        XCTAssertEqual(settings.workdaySummary, "\(Workday.tuesday.title)、\(Workday.sunday.title)")
    }

    func testWorkweekBadgeUsesConfiguredWorkdayCount() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        settings.workdays = [Workday.monday.rawValue]
        let mondayAfterWork = date("2026-05-18 19:00:00")

        let badge = calculator.salaryBadges(
            now: mondayAfterWork,
            settings: settings,
            records: [],
            focusedWish: nil,
            wishes: [],
            overtimeRecords: []
        ).first { $0.id == "workweek-earned" }

        XCTAssertEqual(badge?.progress, 1)
    }

    func testWishExperienceClassifiesAndRoundTripsWithoutAmount() throws {
        let wish = WishExperience(
            title: "  去九寨沟旅行  ",
            captureSource: .text,
            createdAt: date("2026-05-18 09:00:00")
        )

        XCTAssertEqual(wish.title, "去九寨沟旅行")
        XCTAssertEqual(wish.archetype, .journey)
        XCTAssertNil(wish.targetAmount)

        let data = try JSONEncoder().encode(wish)
        XCTAssertEqual(try JSONDecoder().decode(WishExperience.self, from: data), wish)
    }

    func testDisabledWishPlanningExporterStaysUnavailable() async throws {
        let exporter = DisabledWishPlanningExporter()
        let wish = WishExperience(title: "去九寨沟", archetype: .journey)

        XCTAssertFalse(exporter.isAvailable)
        let draft = try await exporter.prepareExport(for: wish)
        XCTAssertEqual(draft.sourceWishID, wish.id)
        XCTAssertEqual(draft.schemaVersion, 1)
    }

    @MainActor
    func testFreeWishCollectionAllowsTwoActiveWishes() {
        let suiteName = "PayJoyTests.Wishes.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appState = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil),
            now: date("2026-05-18 09:00:00")
        )

        for index in 1...4 {
            _ = appState.createWish(
                title: "愿望 \(index)",
                captureSource: .text,
                targetAmount: Decimal(index * 100)
            )
        }

        XCTAssertEqual(appState.activeWishes.count, 2)
        XCTAssertFalse(appState.canCreateWish)
        XCTAssertEqual(appState.activeWishes.filter(\.isFocused).count, 1)
    }

    @MainActor
    func testProWishCollectionHasNoActiveWishLimit() {
        let suiteName = "PayJoyTests.ProWishes.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)
        var preferences = AppPreferences.defaultValue
        preferences.isProUnlocked = true
        store.savePreferences(preferences)
        let appState = AppState(
            store: store,
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil),
            now: date("2026-05-18 09:00:00")
        )

        for index in 1...4 {
            _ = appState.createWish(title: "愿望 \(index)", captureSource: .text)
        }

        XCTAssertEqual(appState.activeWishes.count, 4)
        XCTAssertTrue(appState.canCreateWish)
    }

    func testLegacyGoalAndSalaryWishesMigrateIntoUnifiedWishStorage() throws {
        let suiteName = "PayJoyTests.WishMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let encoder = JSONEncoder()
        defaults.set(
            try encoder.encode(
                LegacyPersonalGoal(
                    title: "去九寨沟",
                    targetAmount: 6_000,
                    startedAt: date("2026-05-18 09:00:00")
                )
            ),
            forKey: "payjoy.personal.goal"
        )
        defaults.set(
            try encoder.encode([
                LegacySalaryWish(
                    id: UUID(),
                    title: "小狮子",
                    targetAmount: 399,
                    createdAt: date("2026-05-19 09:00:00"),
                    isCompleted: false
                )
            ]),
            forKey: "payjoy.salary.wishes"
        )

        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)
        let migrated = store.loadWishExperiences()

        XCTAssertEqual(migrated.count, 2)
        XCTAssertTrue(migrated[0].isFocused)
        XCTAssertEqual(migrated[0].archetype, .journey)
        XCTAssertEqual(migrated[1].archetype, .possession)
        XCTAssertNotNil(defaults.data(forKey: "payjoy.wish.experiences.v1"))
        XCTAssertNil(defaults.data(forKey: "payjoy.personal.goal"))
        XCTAssertNil(defaults.data(forKey: "payjoy.salary.wishes"))
    }

    func testPersonalGoalProgressSkipsRestDayWhenEstimatingCompletion() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        let sunday = date("2026-05-17 10:00:00")
        let goal = WishExperience(
            title: "旅行",
            archetype: .journey,
            targetAmount: 500,
            createdAt: sunday,
            focusedAt: sunday
        )

        let progress = calculator.personalGoalProgress(
            for: goal,
            now: sunday,
            settings: settings,
            records: []
        )

        XCTAssertEqual(progress.earnedAmount, 0, accuracy: 0.001)
        XCTAssertEqual(progress.estimatedWorkdaysRemaining, 1)
        XCTAssertEqual(progress.estimatedCompletionDate, date("2026-05-18 00:00:00"))
    }

    func testPreferencesKeepGoalRemindersOptInByDefault() throws {
        let data = try JSONEncoder().encode(AppPreferences.defaultValue)
        let restored = try JSONDecoder().decode(AppPreferences.self, from: data)
        XCTAssertFalse(restored.goalRemindersEnabled)
        XCTAssertFalse(restored.hasCompletedInitialSetup)
        XCTAssertTrue(restored.unlockedBadgeIDs.isEmpty)
    }

    func testPreferencesPersistDisplayAndMotionChoices() throws {
        var preferences = AppPreferences.defaultValue
        preferences.showDecimalCents = false
        preferences.showCoinRain = false
        preferences.reduceMotion = true

        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))

        XCTAssertFalse(restored.showDecimalCents)
        XCTAssertFalse(restored.showCoinRain)
        XCTAssertTrue(restored.reduceMotion)
    }

    func testCoreVisibleStringsAreLocalizedForEnglishJapaneseAndKorean() throws {
        let defaults = UserDefaults.standard
        let preferencesKey = "payjoy.app.preferences"
        let originalData = defaults.data(forKey: preferencesKey)
        defer {
            if let originalData {
                defaults.set(originalData, forKey: preferencesKey)
            } else {
                defaults.removeObject(forKey: preferencesKey)
            }
        }

        let visibleStrings = [
            "下班结算战报", "不用打开 App，也能看到今日已赚、进度和倒计时。", "今天已标记收工，收入按整天结算。",
            "今日到账，打工人安全下线。", "今日收工战报", "休息日不开薪，也要开心。", "加班已收尾，辛苦值已记录。",
            "午休暂停，快乐继续。", "周五下午，自由已经在门口刷卡。", "周五尾声，钱包和灵魂都在倒计时。",
            "夜班模式启动，屏幕也在陪你。", "实时活动、隐私保护、老板键、同步、午休与主题资产一次解锁。",
            "开工前，钱包正在做热身。", "收下战报", "收工时间",
            "无法安全保存密码，请稍后再试。", "本次加班", "深夜在线，金币别睡。", "秒变计算器",
            "老板键", "老板键已启动",
            "锁屏和灵动岛也能展示当前进度。", "长按上方数字显示区，即可退出计算器并返回开薪。",
            "首页右上角公文包按钮可一键伪装成计算器。首次进入会显示退出指引，之后长按计算器上方数字显示区即可返回开薪。",
            "把难熬的工作时间，变成看得见的小快乐。", "这份工作是为了什么？",
            "今天感觉怎么样？", "默认隐藏真实金额", "愿望",
            "今天休息，不催签到。好好把时间还给自己。", "让每天的世界，更像你喜欢的样子", "地区语气与格式",
            "今天也给自己一点好心情。", "添加愿望", "添加这个愿望",
            "最近有什么东西，让你一想到就有点开心？", "进度由你填写，节奏由你决定。",
            "一个小小的期待", "想拥有", "当前进度 %d%%", "已完成与已暂停",
            "这个愿望实现了", "可以留一张照片，给这份开心做个纪念。", "标记为已实现", "已留照片",
            "实际薪资、完整回执历史、额外语气和全部主题，一次开通。"
        ]

        let expectedBrands: [AppLanguage: String] = [
            .en: "ClockJoy",
            .ja: "ClockJoy",
            .ko: "ClockJoy"
        ]

        for language in [AppLanguage.en, .ja, .ko] {
            var preferences = AppPreferences.defaultValue
            preferences.appLanguage = language
            defaults.set(try JSONEncoder().encode(preferences), forKey: preferencesKey)

            let untranslated = visibleStrings.filter { L10n.t($0) == $0 }
            XCTAssertTrue(untranslated.isEmpty, "\(language.rawValue) untranslated: \(untranslated.joined(separator: ", "))")
            XCTAssertNotEqual(L10n.t("本月剩 20 个工作日！"), "本月剩 20 个工作日！")
            XCTAssertFalse(L10n.t("开薪！").contains("PayJoy"))
            XCTAssertFalse(L10n.t("关于开薪").contains("PayJoy"))
            XCTAssertFalse(L10n.t("由 PayJoy 开薪生成").contains("PayJoy"))
            XCTAssertEqual(L10n.appDisplayName, expectedBrands[language])
            XCTAssertTrue(L10n.t("开薪！").contains(expectedBrands[language]!))
            XCTAssertTrue(L10n.t("去 App Store 给开薪评分").contains(expectedBrands[language]!))
            XCTAssertFalse(L10n.t("去 App Store 给开薪评分").contains("开薪"))
            XCTAssertFalse(L10n.t("去 App Store 给开薪评分").contains("開薪"))
        }
    }

    func testLiteralInterfaceStringsAreLocalizedForSupportedLanguages() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoots = ["PayJoy", "PayJoyWidgets"].map(projectRoot.appendingPathComponent)
        var sourceFiles: [URL] = []
        for sourceRoot in sourceRoots {
            guard let sourceEnumerator = FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            ) else {
                XCTFail("Unable to enumerate \(sourceRoot.lastPathComponent) source files")
                return
            }
            sourceFiles.append(contentsOf: sourceEnumerator.compactMap {
                ($0 as? URL).flatMap { $0.pathExtension == "swift" ? $0 : nil }
            })
        }
        let patterns = [
            #"L10n\.(?:t|format)\(\s*\"((?:\\.|[^\"\\])*)\""#,
            #"L10n\.t\(\s*(?:\w+\s*\?\s*)?\"((?:\\.|[^\"\\])*)\"\s*:\s*\"((?:\\.|[^\"\\])*)\""#
        ]
        let expressions = try patterns.map { try NSRegularExpression(pattern: $0) }
        var keys = Set<String>()

        for file in sourceFiles where file.pathExtension == "swift" && file.lastPathComponent != "L10n.swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for expression in expressions {
                for match in expression.matches(in: source, range: range) {
                    for captureIndex in 1..<match.numberOfRanges {
                        guard match.range(at: captureIndex).location != NSNotFound,
                              let keyRange = Range(match.range(at: captureIndex), in: source) else { continue }
                        let key = String(source[keyRange])
                        guard !key.contains("\\(") else { continue }
                        keys.insert(key)
                    }
                }
            }
        }

        for language in [AppLanguage.en, .ja, .ko] {
            let untranslated = L10n.untranslatedKeys(Array(keys), language: language)
            XCTAssertTrue(
                untranslated.isEmpty,
                "\(language.rawValue) untranslated literals: \(untranslated.sorted().joined(separator: ", "))"
            )

            let dynamicKeys = [
                "已安排 周一到周五 09:00 开薪、18:00 到账提醒。"
            ]
            XCTAssertTrue(
                L10n.untranslatedKeys(dynamicKeys, language: language).isEmpty,
                "\(language.rawValue) untranslated dynamic strings"
            )
        }
    }

    func testUserFacingSwiftStringsDoNotExposeProLabels() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = projectRoot.appendingPathComponent("PayJoy")
        let forbidden = try NSRegularExpression(
            pattern: #"(?i)(?:^|[^a-z])pro(?:[^a-z]|$)|会员专属|会员限定"#
        )
        let literal = try NSRegularExpression(pattern: #"\"((?:\\.|[^\"\\])*)\""#)
        let interfaceCall = try NSRegularExpression(
            pattern: #"(?:L10n\.(?:t|format)|Text|Label|Button)\(\s*\"((?:\\.|[^\"\\])*)\""#
        )
        var violations: [String] = []

        guard let sourceEnumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        ) else {
            XCTFail("Unable to enumerate PayJoy source files")
            return
        }

        for file in sourceEnumerator.compactMap({ $0 as? URL }) where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            let expression = file.lastPathComponent == "L10n.swift" ? literal : interfaceCall
            let sourceRange = NSRange(source.startIndex..., in: source)

            for match in expression.matches(in: source, range: sourceRange) {
                guard let matchRange = Range(match.range(at: 1), in: source) else { continue }
                let value = String(source[matchRange])
                let fullValueRange = NSRange(value.startIndex..., in: value)
                if forbidden.firstMatch(in: value, range: fullValueRange) != nil {
                    violations.append("\(file.lastPathComponent): \(value)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "User-facing membership labels must stay neutral until tapped: \(violations.sorted().joined(separator: ", "))"
        )
    }

    func testStoreKitKeepsProductIDButUsesMemberFacingName() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configurationURL = projectRoot
            .appendingPathComponent("PayJoy")
            .appendingPathComponent("Configuration")
            .appendingPathComponent("PayJoy.storekit")
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: configurationURL)) as? [String: Any]
        )
        let products = try XCTUnwrap(payload["products"] as? [[String: Any]])
        let product = try XCTUnwrap(products.first)

        XCTAssertEqual(product["productID"] as? String, "payjoy.pro.lifetime")

        let localizations = try XCTUnwrap(product["localizations"] as? [[String: Any]])
        let localizedNames: [(String, String)] = localizations.compactMap { localization -> (String, String)? in
            guard let locale = localization["locale"] as? String,
                  let displayName = localization["displayName"] as? String else { return nil }
            return (locale, displayName)
        }
        let names = Dictionary(uniqueKeysWithValues: localizedNames)
        XCTAssertEqual(names["zh_Hans"], "开薪会员")
        XCTAssertEqual(names["en_US"], "ClockJoy Membership")
        XCTAssertTrue(names.values.allSatisfy { !$0.localizedCaseInsensitiveContains("pro") })
    }

    func testSavingPreferencesCachesThemeForRendering() {
        let suiteName = "PayJoyTests.ThemeCache.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var preferences = AppPreferences.defaultValue
        preferences.selectedTheme = .midnight

        SettingsStore(defaults: defaults, sharedDefaults: nil).savePreferences(preferences)

        XCTAssertEqual(defaults.string(forKey: "payjoy.app.selected.theme"), AppVisualTheme.midnight.rawValue)
    }

    func testCloudSyncInitializationIsScopedToAppleAccount() {
        let suiteName = "PayJoyTests.CloudSync.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)

        store.markCloudSyncInitialized(for: "apple-user-a")

        XCTAssertTrue(store.hasInitializedCloudSync(for: "apple-user-a"))
        XCTAssertFalse(store.hasInitializedCloudSync(for: "apple-user-b"))
    }

    @MainActor
    func testLocalStoreKitConfigurationLoadsProProduct() async throws {
        let product = try await StoreKitService().loadProProduct()

        XCTAssertEqual(product.id, StoreKitService.proProductID)
    }

    func testLegacyPreferencesSkipInitialSetup() throws {
        let restored = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        XCTAssertTrue(restored.hasCompletedInitialSetup)
    }

    func testPreferencesNeverEncodeLegacyPasscodeCredential() throws {
        var preferences = AppPreferences.defaultValue
        preferences.appLockPasscodeSalt = "legacy-salt"
        preferences.appLockPasscodeHash = "legacy-hash"

        let data = try JSONEncoder().encode(preferences)
        let payload = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(payload.contains("legacy-salt"))
        XCTAssertFalse(payload.contains("legacy-hash"))
        XCTAssertFalse(payload.contains("appLockPasscodeSalt"))
        XCTAssertFalse(payload.contains("appLockPasscodeHash"))
    }

    func testClearAllLocalDataRemovesOneTimeBossKeyGuideState() {
        let suiteName = "PayJoyTests.clearAll.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "payjoy.boss.key.didShowExitGuide")

        SettingsStore(defaults: defaults, sharedDefaults: nil).clearAllLocalData()

        XCTAssertNil(defaults.object(forKey: "payjoy.boss.key.didShowExitGuide"))
    }

    func testCloudPreferenceRestoreKeepsLocalEntitlementAndAppLockToggle() {
        var synced = AppPreferences.defaultValue
        synced.isProUnlocked = true
        synced.hideSensitiveAmounts = true
        synced.unlockedBadgeIDs = ["remote-badge"]
        synced.appLockEnabled = true
        synced.appLockPasscodeSalt = "remote-salt"
        synced.appLockPasscodeHash = "remote-hash"

        let withoutLocalSecurityState = synced.preservingLocalSecurityState(from: .defaultValue)
        XCTAssertFalse(withoutLocalSecurityState.isProUnlocked)
        XCTAssertFalse(withoutLocalSecurityState.appLockEnabled)
        XCTAssertNil(withoutLocalSecurityState.appLockPasscodeSalt)
        XCTAssertNil(withoutLocalSecurityState.appLockPasscodeHash)
        XCTAssertTrue(withoutLocalSecurityState.hideSensitiveAmounts)
        XCTAssertEqual(withoutLocalSecurityState.unlockedBadgeIDs, ["remote-badge"])

        var localPurchase = AppPreferences.defaultValue
        localPurchase.isProUnlocked = true
        localPurchase.appLockEnabled = true
        localPurchase.unlockedBadgeIDs = ["local-badge"]
        localPurchase.appLockPasscodeSalt = "local-salt"
        localPurchase.appLockPasscodeHash = "local-hash"
        let withLocalSecurityState = AppPreferences.defaultValue.preservingLocalSecurityState(from: localPurchase)
        XCTAssertTrue(withLocalSecurityState.isProUnlocked)
        XCTAssertTrue(withLocalSecurityState.appLockEnabled)
        XCTAssertNil(withLocalSecurityState.appLockPasscodeSalt)
        XCTAssertNil(withLocalSecurityState.appLockPasscodeHash)
        XCTAssertEqual(withLocalSecurityState.unlockedBadgeIDs, ["local-badge"])
    }

    func testLegacyCloudSnapshotKeepsWishExperiencesUnset() throws {
        let snapshot = PayJoyCloudSnapshot(
            settings: .defaultValue,
            profile: .defaultValue,
            preferences: .defaultValue,
            overtimeDateKeys: [],
            overtimeRecords: [],
            earlyLeaveDateKeys: [],
            salaryDayRecords: [],
            wishExperiences: [
                WishExperience(
                    title: "耳机",
                    archetype: .possession,
                    targetAmount: 1_299,
                    createdAt: date("2026-05-18 09:00:00")
                )
            ],
            updatedAt: date("2026-05-18 09:00:00")
        )
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        payload.removeValue(forKey: "wishExperiences")
        let legacyData = try JSONSerialization.data(withJSONObject: payload)

        let restoredLegacy = try JSONDecoder().decode(PayJoyCloudSnapshot.self, from: legacyData)
        XCTAssertNil(restoredLegacy.wishExperiences)
    }

    func testCloudPayloadCodecCompressesAndRestoresLegacySnapshots() throws {
        let snapshot = PayJoyCloudSnapshot(
            settings: .defaultValue,
            profile: .defaultValue,
            preferences: .defaultValue,
            overtimeDateKeys: [],
            overtimeRecords: [],
            earlyLeaveDateKeys: [],
            salaryDayRecords: (0..<2_000).map { index in
                let updatedAt = Date(timeIntervalSince1970: TimeInterval(index * 86_400))
                return SalaryDayRecord(
                    dateKey: "2020-\(index / 28 + 1)-\(index % 28 + 1)",
                    kind: index.isMultiple(of: 11) ? .paidLeave : .normal,
                    note: index.isMultiple(of: 7) ? "项目复盘" : "",
                    settingsSnapshot: .defaultValue,
                    scheduledAmount: 459.77,
                    earnedAmount: 459.77,
                    isEstimated: false,
                    updatedAt: updatedAt
                )
            },
            wishExperiences: [
                WishExperience(
                    title: "夏日旅行",
                    archetype: .journey,
                    targetAmount: 6_000,
                    createdAt: date("2026-05-18 09:00:00"),
                    focusedAt: date("2026-05-18 09:00:00")
                ),
                WishExperience(
                    title: "降噪耳机",
                    archetype: .possession,
                    targetAmount: 1_299,
                    createdAt: date("2026-05-18 09:00:00")
                )
            ],
            updatedAt: date("2026-05-18 09:00:00")
        )

        let compressedPayload = try PayJoyCloudPayloadCodec.encode(snapshot)
        let legacyPayload = try JSONEncoder().encode(snapshot).base64EncodedString()

        XCTAssertTrue(compressedPayload.hasPrefix("lzfse:"))
        XCTAssertLessThan(compressedPayload.utf8.count, legacyPayload.utf8.count)
        XCTAssertEqual(try PayJoyCloudPayloadCodec.decode(compressedPayload), snapshot)
        XCTAssertEqual(try PayJoyCloudPayloadCodec.decode(legacyPayload), snapshot)
    }

    func testGoalReminderUsesWorkEndOnEstimatedCompletionDay() {
        var settings = SalarySettings.defaultValue
        settings.workEnd = WorkTime(hour: 18, minute: 30)
        let completionDay = date("2026-05-18 00:00:00")

        let beforeWorkEnd = WorkReminderScheduler.goalReminderFireDate(
            completionDate: completionDay,
            workEnd: settings.workEnd,
            now: date("2026-05-18 10:00:00"),
            calendar: calendar
        )
        XCTAssertEqual(beforeWorkEnd, date("2026-05-18 18:30:00"))

        let afterWorkEnd = WorkReminderScheduler.goalReminderFireDate(
            completionDate: completionDay,
            workEnd: settings.workEnd,
            now: date("2026-05-18 19:00:00"),
            calendar: calendar
        )
        XCTAssertNil(afterWorkEnd)
    }

    func testPastCalendarCorrectionUsesActualIncomeInsteadOfEstimate() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        let monday = date("2026-05-18 18:30:00")
        let record = SalaryDayRecord(
            dateKey: calculator.dateKey(for: monday),
            kind: .paidLeave,
            note: "年假",
            settingsSnapshot: settings,
            scheduledAmount: 500,
            earnedAmount: 500,
            isEstimated: false,
            updatedAt: monday
        )

        let day = calculator.salaryCalendarDay(
            for: monday,
            now: date("2026-05-19 10:00:00"),
            settings: settings,
            record: record
        )
        XCTAssertEqual(day.earnedAmount, 500, accuracy: 0.001)
        XCTAssertFalse(day.isEstimated)
    }

    func testWeeklyPayReportAggregatesVisibleWorkdaysAndFutureBars() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        let report = calculator.weeklyPayReport(
            now: date("2026-05-13 19:00:00"),
            settings: settings,
            records: []
        )

        XCTAssertEqual(report.days.count, 7)
        XCTAssertEqual(report.totalWorkdays, 5)
        XCTAssertEqual(report.paidDayCount, 3)
        XCTAssertEqual(report.earnedAmount, 1_500, accuracy: 0.001)
        XCTAssertEqual(report.projectedAmount, 2_500, accuracy: 0.001)
        XCTAssertEqual(report.progress, 0.6, accuracy: 0.001)
        XCTAssertEqual(report.days.filter(\.isFuture).count, 3)
    }

    func testSalaryBadgesReflectExistingPaydayProgress() throws {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        let monday = date("2026-05-18 18:00:00")

        let starterBadges = calculator.salaryBadges(
            now: monday,
            settings: settings,
            records: [],
            focusedWish: nil,
            wishes: [],
            overtimeRecords: []
        )

        XCTAssertEqual(starterBadges.count, 34)
        XCTAssertTrue(starterBadges.first(where: { $0.id == "first-payday" })?.isUnlocked == true)
        XCTAssertFalse(starterBadges.first(where: { $0.id == "workweek-earned" })?.isUnlocked == true)
        XCTAssertFalse(starterBadges.first(where: { $0.id == "payday-direction" })?.isUnlocked == true)
        XCTAssertFalse(starterBadges.first(where: { $0.id == "calendar-collector" })?.isUnlocked == true)

        let friday = date("2026-05-22 18:00:00")
        let goal = WishExperience(
            title: "旅行",
            archetype: .journey,
            targetAmount: 1_000,
            createdAt: monday,
            focusedAt: monday
        )
        let wish = WishExperience(
            title: "耳机",
            archetype: .possession,
            targetAmount: 500,
            status: .completed,
            createdAt: monday,
            completedAt: monday
        )
        let overtime = OvertimeRecord(
            startAt: date("2026-05-20 18:00:00"),
            endAt: date("2026-05-21 02:00:00")
        )
        let progressBadges = calculator.salaryBadges(
            now: friday,
            settings: settings,
            records: [],
            focusedWish: goal,
            wishes: [wish],
            overtimeRecords: [overtime]
        )

        XCTAssertTrue(progressBadges.first(where: { $0.id == "goal-reached" })?.isUnlocked == true)
        XCTAssertNil(progressBadges.first(where: { $0.id == "wish-starter" }))
        XCTAssertNil(progressBadges.first(where: { $0.id == "wish-fulfilled" }))
        XCTAssertTrue(progressBadges.first(where: { $0.id == "overtime-starter" })?.isUnlocked == true)
        XCTAssertTrue(progressBadges.first(where: { $0.id == "overtime-advanced" })?.isUnlocked == true)
        XCTAssertFalse(progressBadges.first(where: { $0.id == "month-finish" })?.isUnlocked == true)
        XCTAssertEqual(try XCTUnwrap(progressBadges.first(where: { $0.id == "workweek-earned" })?.progress), 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(progressBadges.first(where: { $0.id == "overtime-hero" })?.progress), 1, accuracy: 0.001)
    }

    func testUnlockedBadgesRemainAvailableAfterTheirPeriodResets() {
        let badges = calculator.salaryBadges(
            now: date("2026-05-18 08:00:00"),
            settings: .defaultValue,
            records: [],
            focusedWish: nil,
            wishes: [],
            overtimeRecords: [],
            unlockedBadgeIDs: ["month-finish", "overtime-hero"]
        )

        XCTAssertTrue(badges.first(where: { $0.id == "month-finish" })?.isUnlocked == true)
        XCTAssertTrue(badges.first(where: { $0.id == "overtime-hero" })?.isUnlocked == true)
    }

    func testSalaryBadgesUnlockCollectionAndScheduleMilestones() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        let saturday = date("2026-05-23 18:00:00")

        let records = (0..<30).map { offset -> SalaryDayRecord in
            let day = calendar.date(byAdding: .day, value: -offset, to: saturday)!
            let kind: SalaryDayKind = offset == 0 ? .rest : .normal
            return SalaryDayRecord(
                dateKey: calculator.dateKey(for: day),
                kind: kind,
                note: "",
                settingsSnapshot: settings,
                scheduledAmount: kind == .normal ? 500 : 0,
                earnedAmount: kind == .normal ? 500 : 0,
                isEstimated: false,
                updatedAt: day
            )
        }
        let wishes = [
            WishExperience(title: "耳机", archetype: .possession, targetAmount: 500, status: .completed, createdAt: saturday, completedAt: saturday),
            WishExperience(title: "旅行", archetype: .journey, targetAmount: 1_000, status: .completed, createdAt: saturday, completedAt: saturday),
            WishExperience(title: "相机", archetype: .possession, targetAmount: 2_000, status: .completed, createdAt: saturday, completedAt: saturday)
        ]
        let weekendOvertime = OvertimeRecord(
            startAt: saturday,
            endAt: saturday.addingTimeInterval(5 * 3_600)
        )

        let badges = calculator.salaryBadges(
            now: saturday,
            settings: settings,
            records: records,
            focusedWish: nil,
            wishes: wishes,
            overtimeRecords: [weekendOvertime]
        )

        ["calendar-week", "calendar-collector", "calendar-month", "calendar-archivist", "schedule-owner", "overtime-advanced", "weekend-shift"].forEach { id in
            XCTAssertTrue(badges.first(where: { $0.id == id })?.isUnlocked == true, id)
        }
        XCTAssertFalse(badges.contains { $0.id.hasPrefix("wish-") })
    }

    func testSalaryBadgesOfferExpandedCalendarWishAndOvertimeMilestones() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        let saturday = date("2026-05-23 18:00:00")

        let recordOffsets: [Int] = Array(0..<180)
        let records = recordOffsets.map { offset -> SalaryDayRecord in
            let day = calendar.date(byAdding: .day, value: -offset, to: saturday)!
            let kind: SalaryDayKind
            switch offset % 12 {
            case 0: kind = .paidLeave
            case 1: kind = .rest
            case 2: kind = .unpaidLeave
            default: kind = .normal
            }
            let amount: Double = (kind == .normal || kind == .paidLeave) ? 500 : 0
            return SalaryDayRecord(
                dateKey: calculator.dateKey(for: day),
                kind: kind,
                note: offset < 5 ? "复盘" : "",
                settingsSnapshot: settings,
                scheduledAmount: amount,
                earnedAmount: amount,
                isEstimated: false,
                updatedAt: day
            )
        }
        let wishIndexes: [Int] = Array(0..<8)
        let wishes = wishIndexes.map {
            WishExperience(
                title: "愿望 \($0)",
                targetAmount: 500,
                status: .completed,
                createdAt: saturday,
                completedAt: saturday
            )
        }
        let overtimeOffsets: [Int] = Array(0..<10)
        let overtimeRecords = overtimeOffsets.map { offset -> OvertimeRecord in
            let start = calendar.date(byAdding: .day, value: -offset * 7, to: saturday)!
            return OvertimeRecord(startAt: start, endAt: start.addingTimeInterval(2 * 3_600))
        }

        let badges = calculator.salaryBadges(
            now: saturday,
            settings: settings,
            records: records,
            focusedWish: nil,
            wishes: wishes,
            overtimeRecords: overtimeRecords
        )

        XCTAssertEqual(badges.count, 34)
        [
            "calendar-vault", "calendar-yearbook", "calendar-note", "calendar-journal",
            "paid-leave", "schedule-director", "rest-planner",
            "overtime-logbook", "overtime-ledger", "weekend-veteran"
        ].forEach { id in
            XCTAssertTrue(badges.first(where: { $0.id == id })?.isUnlocked == true, id)
        }
        XCTAssertFalse(badges.contains { $0.id.hasPrefix("wish-") })
    }

    func testSalaryBadgesUseUniqueOriginalArtworkAndFamilies() {
        let badges = SalaryCalculator().salaryBadges(
            now: date("2026-05-18 09:00:00"),
            settings: .defaultValue,
            records: [],
            focusedWish: nil,
            wishes: [],
            overtimeRecords: []
        )

        XCTAssertEqual(badges.count, 34)
        XCTAssertEqual(Set(badges.map(\.artworkName)).count, 34)
        XCTAssertEqual(
            Dictionary(grouping: badges, by: \.family).mapValues(\.count),
            [
                .paydayProgress: 6,
                .wish: 4,
                .calendar: 8,
                .journal: 7,
                .overtime: 9
            ]
        )
        XCTAssertTrue(badges.allSatisfy { $0.artworkName == "achievement_\($0.id.replacingOccurrences(of: "-", with: "_"))_v1" })
    }

    func testBeforeWorkWorkingAndAfterWorkStates() {
        let settings = SalarySettings.defaultValue

        let before = calculator.snapshot(for: date("2026-05-18 08:30:00"), settings: settings)
        XCTAssertEqual(before.status, .beforeWork)
        XCTAssertEqual(before.todayEarned, 0, accuracy: 0.001)

        let working = calculator.snapshot(for: date("2026-05-18 10:00:00"), settings: settings)
        XCTAssertEqual(working.status, .working)
        XCTAssertGreaterThan(working.todayEarned, 0)
        XCTAssertLessThan(working.todayEarned, working.todayTotal)

        let after = calculator.snapshot(for: date("2026-05-18 18:00:00"), settings: settings)
        XCTAssertEqual(after.status, .afterWork)
        XCTAssertEqual(after.todayEarned, after.todayTotal, accuracy: 0.001)
        XCTAssertEqual(after.progress, 1, accuracy: 0.001)
    }

    func testOffDutyCountdownAppearsOnlyAfterACompletedWorkday() throws {
        let settings = SalarySettings.defaultValue

        let afterMidnight = try XCTUnwrap(
            calculator.offDutySecondsUntilWorkStart(
                for: date("2026-05-19 00:05:00"),
                settings: settings
            )
        )
        XCTAssertEqual(afterMidnight, 8 * 3_600 + 55 * 60, accuracy: 0.001)

        XCTAssertNil(
            calculator.offDutySecondsUntilWorkStart(
                for: date("2026-05-18 00:05:00"),
                settings: settings
            )
        )
        XCTAssertNil(
            calculator.offDutySecondsUntilWorkStart(
                for: date("2026-05-19 10:00:00"),
                settings: settings
            )
        )
        XCTAssertNil(
            calculator.offDutySecondsUntilWorkStart(
                for: date("2026-05-23 00:05:00"),
                settings: settings
            )
        )
    }

    @MainActor
    func testActiveOvertimeSuppressesOffDutyCountdown() throws {
        let suiteName = "PayJoyTests.OffDutyCountdown.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            calculator: calculator,
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-19 00:05:00")
        )

        XCTAssertNotNil(state.offDutySecondsUntilWorkStart)
        state.startOvertime(at: date("2026-05-18 23:30:00"))
        XCTAssertNil(state.offDutySecondsUntilWorkStart)
    }

    func testLegacyLiveActivityStateDecodesWithoutOffDutyFields() throws {
        let state = PayJoyActivityAttributes.ContentState(
            earned: 123,
            total: 500,
            perSecond: 0.02,
            progress: 0.25,
            statusTitle: "开薪中",
            endDate: date("2026-05-19 18:00:00"),
            remainingText: "08:00:00",
            countdownTitle: nil,
            isOffDuty: nil,
            hidesSensitiveAmounts: true,
            currencySymbol: "¥",
            visualTheme: .classic,
            goalTitle: nil,
            goalProgress: nil,
            goalRemainingText: nil,
            goalCompletionText: nil
        )
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
        )
        payload.removeValue(forKey: "countdownTitle")
        payload.removeValue(forKey: "isOffDuty")

        let restored = try JSONDecoder().decode(
            PayJoyActivityAttributes.ContentState.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )

        XCTAssertNil(restored.countdownTitle)
        XCTAssertNil(restored.isOffDuty)
        XCTAssertTrue(restored.hidesSensitiveAmounts)
    }

    func testLunchDeductionPausesEarningsAndProgress() {
        var settings = SalarySettings.defaultValue
        settings.deductLunch = true

        let lunch = calculator.snapshot(for: date("2026-05-18 12:30:00"), settings: settings)
        let beforeLunchEnd = calculator.snapshot(for: date("2026-05-18 12:59:00"), settings: settings)

        XCTAssertEqual(lunch.status, .lunchBreak)
        XCTAssertEqual(lunch.todayEarned, beforeLunchEnd.todayEarned, accuracy: 0.5)
        XCTAssertEqual(calculator.workingSecondsPerDay(settings: settings), 8 * 3_600, accuracy: 0.001)
    }

    func testWeekendIsRestDay() {
        let snapshot = calculator.snapshot(for: date("2026-05-17 10:00:00"), settings: .defaultValue)
        XCTAssertEqual(snapshot.status, .restDay)
        XCTAssertEqual(snapshot.todayEarned, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.todayTotal, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.remainingToday, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.progress, 0, accuracy: 0.001)
    }

    func testCalendarCorrectionControlsTodaySnapshot() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        let now = date("2026-05-18 10:00:00")
        let unpaidLeave = SalaryDayRecord(
            dateKey: calculator.dateKey(for: now),
            kind: .unpaidLeave,
            note: "病假",
            settingsSnapshot: settings,
            scheduledAmount: 0,
            earnedAmount: 0,
            isEstimated: false,
            updatedAt: now
        )
        let paidLeave = SalaryDayRecord(
            dateKey: calculator.dateKey(for: now),
            kind: .paidLeave,
            note: "年假",
            settingsSnapshot: settings,
            scheduledAmount: 500,
            earnedAmount: 500,
            isEstimated: false,
            updatedAt: now
        )

        let unpaidSnapshot = calculator.snapshot(for: now, settings: settings, record: unpaidLeave)
        XCTAssertEqual(unpaidSnapshot.status, .restDay)
        XCTAssertEqual(unpaidSnapshot.todayTotal, 0, accuracy: 0.001)
        XCTAssertEqual(unpaidSnapshot.remainingToday, 0, accuracy: 0.001)

        let paidSnapshot = calculator.snapshot(for: now, settings: settings, record: paidLeave)
        XCTAssertEqual(paidSnapshot.status, .afterWork)
        XCTAssertEqual(paidSnapshot.todayEarned, 500, accuracy: 0.001)
        XCTAssertEqual(paidSnapshot.progress, 1, accuracy: 0.001)
    }

    func testCustomWorkdaysCanIncludeSunday() {
        var settings = SalarySettings.defaultValue
        settings.workdays = [Workday.sunday.rawValue]

        let snapshot = calculator.snapshot(for: date("2026-05-17 10:00:00"), settings: settings)

        XCTAssertEqual(snapshot.status, .working)
        XCTAssertGreaterThan(snapshot.todayEarned, 0)
    }

    func testOvertimeDateDoesNotCountRestDayAsPaidWork() {
        let sunday = date("2026-05-17 10:00:00")
        let snapshot = calculator.snapshot(
            for: sunday,
            settings: .defaultValue,
            overtimeDateKeys: [calculator.dateKey(for: sunday)]
        )

        XCTAssertEqual(snapshot.status, .restDay)
        XCTAssertEqual(snapshot.todayEarned, 0, accuracy: 0.001)
    }

    func testOvertimeSummaryCountsMonthlyRecords() {
        let firstStart = date("2026-05-17 18:00:00")
        let firstEnd = date("2026-05-17 20:30:00")
        let secondStart = date("2026-05-23 19:00:00")
        let secondEnd = date("2026-05-23 21:00:00")
        let juneStart = date("2026-06-07 18:00:00")
        let summary = calculator.overtimeSummary(
            in: .month,
            date: date("2026-05-30 12:00:00"),
            now: date("2026-05-30 12:00:00"),
            overtimeRecords: [
                OvertimeRecord(id: "may-1", startAt: firstStart, endAt: firstEnd),
                OvertimeRecord(id: "may-2", startAt: secondStart, endAt: secondEnd),
                OvertimeRecord(id: "jun-1", startAt: juneStart, endAt: juneStart.addingTimeInterval(3_600))
            ]
        )

        XCTAssertEqual(summary.count, 2)
        XCTAssertEqual(summary.totalHours, 4.5, accuracy: 0.001)
        XCTAssertEqual(summary.records.map(\.id), ["may-2", "may-1"])
    }

    func testOvertimeSummaryIncludesActiveRecordUntilNow() {
        let summary = calculator.overtimeSummary(
            in: .month,
            date: date("2026-05-30 12:00:00"),
            now: date("2026-05-30 21:15:00"),
            overtimeRecords: [
                OvertimeRecord(id: "active", startAt: date("2026-05-30 18:00:00"), endAt: nil)
            ]
        )

        XCTAssertEqual(summary.count, 1)
        XCTAssertTrue(summary.hasActiveRecord)
        XCTAssertEqual(summary.totalHours, 3.25, accuracy: 0.001)
    }

    func testBoundaryTimesDoNotExceedDaySalary() {
        let settings = SalarySettings.defaultValue
        let atStart = calculator.snapshot(for: date("2026-05-18 09:00:00"), settings: settings)
        let atEnd = calculator.snapshot(for: date("2026-05-18 18:00:00"), settings: settings)

        XCTAssertEqual(atStart.todayEarned, 0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(atEnd.todayEarned, atEnd.todayTotal)
        XCTAssertGreaterThanOrEqual(atEnd.remainingToday, 0)
    }

    func testPeriodBreakdownCountsWorkdays() {
        let settings = SalarySettings.defaultValue
        let breakdown = calculator.periodBreakdown(for: .month, date: date("2026-05-18 12:00:00"), settings: settings)

        XCTAssertEqual(breakdown.totalWorkdays, 21)
        XCTAssertEqual(breakdown.elapsedFullWorkdays, 11)
        XCTAssertEqual(breakdown.remainingWorkdays, 10)
        XCTAssertEqual(breakdown.completedWorkdayEquivalent, 11 + (3.0 / 9.0), accuracy: 0.001)
    }

    func testPeriodBreakdownOnRestDayDoesNotCountToday() {
        let settings = SalarySettings.defaultValue
        let breakdown = calculator.periodBreakdown(for: .today, date: date("2026-05-17 12:00:00"), settings: settings)

        XCTAssertEqual(breakdown.totalWorkdays, 0)
        XCTAssertEqual(breakdown.remainingWorkdays, 0)
        XCTAssertEqual(breakdown.completedWorkdayEquivalent, 0, accuracy: 0.001)
    }

    func testMonthlySalaryCompletesWhenMonthHasNoRemainingWorkdays() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .monthly
        settings.salaryAmount = 10_000
        settings.monthlyPaidDays = 21.75

        let earnings = calculator.periodEarnings(for: .month, date: date("2026-05-30 22:00:00"), settings: settings)
        let breakdown = calculator.periodBreakdown(for: .month, date: date("2026-05-30 22:00:00"), settings: settings)

        XCTAssertEqual(breakdown.totalWorkdays, 21)
        XCTAssertEqual(breakdown.remainingWorkdays, 0)
        XCTAssertEqual(earnings.projected, 10_000, accuracy: 0.001)
        XCTAssertEqual(earnings.earned, 10_000, accuracy: 0.001)
        XCTAssertEqual(earnings.progress, 1, accuracy: 0.001)
    }

    func testMonthlySalaryUsesActualMonthWorkdayProgress() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .monthly
        settings.salaryAmount = 10_000
        settings.monthlyPaidDays = 21.75

        let earnings = calculator.periodEarnings(for: .month, date: date("2026-05-18 12:00:00"), settings: settings)
        let expectedProgress = (11 + 3.0 / 9.0) / 21

        XCTAssertEqual(earnings.projected, 10_000, accuracy: 0.001)
        XCTAssertEqual(earnings.progress, expectedProgress, accuracy: 0.001)
        XCTAssertEqual(earnings.earned, 10_000 * expectedProgress, accuracy: 0.001)
    }

    func testPeriodEarningsAndBreakdownUseCalendarCorrections() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .monthly
        settings.salaryAmount = 10_000
        let leaveDate = date("2026-05-18 12:00:00")
        let record = SalaryDayRecord(
            dateKey: calculator.dateKey(for: leaveDate),
            kind: .unpaidLeave,
            note: "请假",
            settingsSnapshot: settings,
            scheduledAmount: 0,
            earnedAmount: 0,
            isEstimated: false,
            updatedAt: leaveDate
        )
        let now = date("2026-05-31 12:00:00")

        let earnings = calculator.periodEarnings(for: .month, date: now, settings: settings, records: [record])
        let breakdown = calculator.periodBreakdown(for: .month, date: now, settings: settings, records: [record])
        let expectedAmount = 10_000.0 - (10_000.0 / 21)

        XCTAssertEqual(earnings.projected, expectedAmount, accuracy: 0.001)
        XCTAssertEqual(earnings.earned, expectedAmount, accuracy: 0.001)
        XCTAssertEqual(breakdown.totalWorkdays, 20)
        XCTAssertEqual(breakdown.elapsedFullWorkdays, 20)
        XCTAssertEqual(breakdown.remainingWorkdays, 0)
    }

    func testSalaryCalendarDistributesMonthlySalaryAcrossActualWorkdays() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .monthly
        settings.salaryAmount = 10_000

        let amount = calculator.scheduledSalaryAmount(for: date("2026-05-18 12:00:00"), settings: settings)

        XCTAssertEqual(amount, 10_000 / 21, accuracy: 0.001)
    }

    func testSalaryCalendarUsesSavedSnapshotForPastDay() {
        var originalSettings = SalarySettings.defaultValue
        originalSettings.salaryAmount = 10_000
        let day = date("2026-05-18 18:00:00")
        let savedAmount = calculator.scheduledSalaryAmount(for: day, settings: originalSettings)
        let record = SalaryDayRecord(
            dateKey: calculator.dateKey(for: day),
            kind: .normal,
            note: "",
            settingsSnapshot: originalSettings,
            scheduledAmount: savedAmount,
            earnedAmount: savedAmount,
            isEstimated: false,
            updatedAt: day
        )
        var currentSettings = originalSettings
        currentSettings.salaryAmount = 20_000

        let calendarDay = calculator.salaryCalendarDay(
            for: day,
            now: date("2026-06-01 12:00:00"),
            settings: currentSettings,
            record: record
        )

        XCTAssertEqual(calendarDay.earnedAmount, savedAmount, accuracy: 0.001)
        XCTAssertFalse(calendarDay.isEstimated)
    }

    func testFutureSalaryCalendarRecordRefreshesWithNewSettings() {
        var oldSettings = SalarySettings.defaultValue
        oldSettings.salaryType = .daily
        oldSettings.salaryAmount = 500
        var newSettings = oldSettings
        newSettings.salaryAmount = 700
        let now = date("2026-05-18 10:00:00")
        let futureDate = date("2026-05-19 09:00:00")
        let futureRecord = SalaryDayRecord(
            dateKey: calculator.dateKey(for: futureDate),
            kind: .paidLeave,
            note: "年假",
            settingsSnapshot: oldSettings,
            scheduledAmount: 500,
            earnedAmount: 0,
            isEstimated: true,
            updatedAt: date("2026-05-18 09:00:00")
        )

        let refreshed = calculator.refreshedFutureSalaryDayRecord(
            futureRecord,
            for: futureDate,
            now: now,
            settings: newSettings
        )

        XCTAssertEqual(refreshed.settingsSnapshot, newSettings)
        XCTAssertEqual(refreshed.scheduledAmount, 700, accuracy: 0.001)
        XCTAssertEqual(refreshed.earnedAmount, 0, accuracy: 0.001)
        XCTAssertEqual(refreshed.note, "年假")
        XCTAssertEqual(refreshed.updatedAt, now)

        let pastRecord = SalaryDayRecord(
            dateKey: calculator.dateKey(for: date("2026-05-15 09:00:00")),
            kind: .paidLeave,
            note: "年假",
            settingsSnapshot: oldSettings,
            scheduledAmount: 500,
            earnedAmount: 500,
            isEstimated: false,
            updatedAt: date("2026-05-15 18:00:00")
        )
        XCTAssertEqual(
            calculator.refreshedFutureSalaryDayRecord(
                pastRecord,
                for: date("2026-05-15 09:00:00"),
                now: now,
                settings: newSettings
            ),
            pastRecord
        )
    }

    func testSalaryCalendarCompletesTodayAfterEarlyLeave() {
        let settings = SalarySettings.defaultValue
        let now = date("2026-05-18 12:00:00")
        let dateKey = calculator.dateKey(for: now)

        let calendarDay = calculator.salaryCalendarDay(
            for: now,
            now: now,
            settings: settings,
            record: nil,
            completedDateKeys: [dateKey]
        )

        XCTAssertEqual(calendarDay.earnedAmount, calendarDay.scheduledAmount, accuracy: 0.001)
    }

    func testSalaryCalendarCalculatesTodayFromClockInsteadOfStoredEarnings() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .daily
        settings.salaryAmount = 500
        let now = date("2026-05-18 12:00:00")
        let record = SalaryDayRecord(
            dateKey: calculator.dateKey(for: now),
            kind: .normal,
            note: "",
            settingsSnapshot: settings,
            scheduledAmount: 500,
            earnedAmount: 0,
            isEstimated: false,
            updatedAt: date("2026-05-18 09:00:00")
        )

        let day = calculator.salaryCalendarDay(
            for: now,
            now: now,
            settings: settings,
            record: record
        )

        XCTAssertEqual(day.earnedAmount, 500 * (3.0 / 9.0), accuracy: 0.001)
        XCTAssertGreaterThan(day.earnedAmount, record.earnedAmount)
    }

    func testUnpaidLeaveRemovesDayFromSalaryMonthProjection() {
        let settings = SalarySettings.defaultValue
        let leaveDate = date("2026-05-18 12:00:00")
        let record = SalaryDayRecord(
            dateKey: calculator.dateKey(for: leaveDate),
            kind: .unpaidLeave,
            note: "请假",
            settingsSnapshot: settings,
            scheduledAmount: 0,
            earnedAmount: 0,
            isEstimated: true,
            updatedAt: leaveDate
        )

        let summary = calculator.salaryMonthSummary(
            for: leaveDate,
            now: date("2026-05-31 23:00:00"),
            settings: settings,
            records: [record]
        )

        XCTAssertEqual(summary.paidDayCount, 20)
        XCTAssertEqual(summary.projectedAmount, 10_000 - (10_000 / 21), accuracy: 0.001)
    }

    func testUnknownLanguageFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.preferredLanguage(for: "fr-FR"), .en)
        XCTAssertEqual(AppLanguage.preferredLanguage(for: "th-TH"), .en)
        XCTAssertEqual(AppMarket.resolve(languageIdentifier: "fr-FR", regionCode: "FR"), .globalEnglish)
    }

    func testAppMarketCombinesLanguageAndRegion() {
        XCTAssertEqual(AppMarket.resolve(languageIdentifier: "zh-Hant", regionCode: "TW"), .taiwan)
        XCTAssertEqual(AppMarket.resolve(languageIdentifier: "zh-Hant", regionCode: "HK"), .hongKong)
        XCTAssertEqual(AppMarket.resolve(languageIdentifier: "ja", regionCode: nil), .japan)
        XCTAssertEqual(AppMarket.resolve(languageIdentifier: "ko", regionCode: nil), .southKorea)
        XCTAssertEqual(AppMarket.resolve(languageIdentifier: "en", regionCode: "JP"), .japan)
    }

    func testLegacyCurrencyMigrationUsesISOCodeAndMarket() {
        XCTAssertEqual(CurrencyCode.migrating(legacySymbol: "$", market: .taiwan), .TWD)
        XCTAssertEqual(CurrencyCode.migrating(legacySymbol: "$", market: .hongKong), .HKD)
        XCTAssertEqual(CurrencyCode.migrating(legacySymbol: "¥", market: .japan), .JPY)
        XCTAssertEqual(CurrencyCode.migrating(legacySymbol: "¥", market: .mainlandChina), .CNY)
        XCTAssertEqual(CurrencyCode.migrating(legacySymbol: "₩", market: .southKorea), .KRW)
        XCTAssertEqual(CurrencyCode.JPY.fractionDigits, 0)
        XCTAssertEqual(CurrencyCode.KRW.fractionDigits, 0)
        XCTAssertEqual(CurrencyCode.TWD.displaySymbol, "NT$")
        XCTAssertEqual(CurrencyCode.HKD.displaySymbol, "HK$")
    }

    func testCurrencyCodeRoundTripsWithSalarySettings() throws {
        var settings = SalarySettings.defaultValue
        settings.setCurrencyCode(.JPY)

        let restored = try JSONDecoder().decode(
            SalarySettings.self,
            from: JSONEncoder().encode(settings)
        )

        XCTAssertEqual(restored.currencyCode, .JPY)
        XCTAssertEqual(restored.currencySymbol, "¥")
    }

    func testPersistedISOCodeDisambiguatesSharedCurrencySymbol() throws {
        let defaults = UserDefaults.standard
        let settingsKey = "payjoy.salary.settings"
        let originalData = defaults.data(forKey: settingsKey)
        defer {
            if let originalData {
                defaults.set(originalData, forKey: settingsKey)
            } else {
                defaults.removeObject(forKey: settingsKey)
            }
        }

        var settings = SalarySettings.defaultValue
        settings.setCurrencyCode(.JPY)
        defaults.set(try JSONEncoder().encode(settings), forKey: settingsKey)

        XCTAssertEqual(SalaryCurrency.code(for: "¥"), .JPY)
        XCTAssertEqual(1_234.moneyText(currencySymbol: "¥").contains(".00"), false)
    }

    @MainActor
    func testWishProgressIsUserControlled() {
        let suiteName = "PayJoyTests.WishProgress.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil),
            now: date("2026-05-18 17:00:00")
        )
        let wish = state.createWish(
            title: "去九寨沟",
            archetype: .journey,
            captureSource: .text,
            targetAmount: 6_000
        )

        guard let wishID = wish?.id else {
            XCTFail("Expected a created wish")
            return
        }
        state.updateWishProgress(id: wishID, progress: 0.42)

        XCTAssertEqual(state.focusedWish?.progress, 0.42)
    }

    func testLegacyWishStoryFieldsMigrateToManualProgressWithoutReencoding() throws {
        let wish = WishExperience(
            title: "一只软乎乎的小狮子",
            archetype: .companion,
            captureSource: .text,
            targetAmount: 6_000,
            currencyCode: .CNY
        )
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(wish)) as? [String: Any]
        )
        payload["workValueProgress"] = 2_520
        payload["storyboardID"] = "basic-companion-v1"
        payload["sceneStates"] = [["id": "halfway", "threshold": 0.5]]
        payload["futureFrames"] = [["dateKey": "2026-05-18", "glimmerCount": 4]]
        payload["companionName"] = "栗栗"

        let migratedWish = try JSONDecoder().decode(
            WishExperience.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )
        let reencoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(migratedWish)) as? [String: Any]
        )

        XCTAssertEqual(migratedWish.progress ?? -1, 0.42, accuracy: 0.001)
        XCTAssertEqual(WishArchetype.classify("一只软乎乎的小狮子"), .possession)
        XCTAssertNil(reencoded["workValueProgress"])
        XCTAssertNil(reencoded["storyboardID"])
        XCTAssertNil(reencoded["sceneStates"])
        XCTAssertNil(reencoded["futureFrames"])
        XCTAssertNil(reencoded["companionName"])
    }


    func testEngagementStateMigratesLegacyStoryFieldsWithoutReencodingThem() throws {
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(EngagementState.defaultValue)
            ) as? [String: Any]
        )
        payload["purpose"] = "travel"
        payload["completedCapsuleCount"] = 12
        payload["viewedStoryChapterCount"] = 8
        payload["inventory"] = ["wishGlimmers": 3]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let state = try JSONDecoder().decode(EngagementState.self, from: data)
        let migrated = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
        )

        XCTAssertNil(migrated["purpose"])
        XCTAssertNil(migrated["completedCapsuleCount"])
        XCTAssertNil(migrated["viewedStoryChapterCount"])
        XCTAssertNil(migrated["inventory"])
    }

    @MainActor
    func testClosingCapsuleIsDeterministicForTheSameDayAndHidesSalary() {
        let suiteName = "PayJoyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 19:00:00")
        )

        let first = state.completeClosingCapsule()
        let second = state.completeClosingCapsule()

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.messageIndex, second.messageIndex)
        XCTAssertFalse(first.revealsSalary)
        XCTAssertEqual(state.engagementState.capsules.count, 1)
    }

    @MainActor
    func testClosingReceiptAvailabilityWaitsForOvertimeAndAllowsEarlyLeave() {
        let suiteName = "PayJoyTests.ClosingAvailability.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 15:00:00")
        )

        XCTAssertFalse(state.canOpenClosingReceipt)
        state.leaveWorkEarlyToday()
        XCTAssertTrue(state.canOpenClosingReceipt)

        state.cancelLeaveWorkEarlyToday()
        state.now = date("2026-05-18 19:00:00")
        XCTAssertTrue(state.canOpenClosingReceipt)
        state.startOvertime(at: date("2026-05-18 18:30:00"))
        XCTAssertFalse(state.canOpenClosingReceipt)
        state.stopActiveOvertime()
        XCTAssertTrue(state.canOpenClosingReceipt)
    }

    @MainActor
    func testCrossMidnightOvertimeCreatesReceiptForTheStartedWorkday() {
        let suiteName = "PayJoyTests.ClosingCrossMidnight.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 22:00:00")
        )

        state.startOvertime(at: date("2026-05-18 19:00:00"))
        state.now = date("2026-05-19 00:30:00")
        state.stopActiveOvertime()

        XCTAssertTrue(state.canOpenClosingReceipt)
        let receipt = state.completeClosingCapsule()
        XCTAssertEqual(receipt.dateKey, "2026-05-18")
        XCTAssertEqual(receipt.currencyCode, .CNY)
        XCTAssertEqual(receipt.workProgress, 1)
    }

    @MainActor
    func testClosingReceiptNotificationWaitsForActiveOvertimeToEnd() {
        let suiteName = "PayJoyTests.ClosingNotificationOvertime.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 19:00:00")
        )

        state.startOvertime(at: date("2026-05-18 18:30:00"))
        state.handleNotificationRoute(.closingReceipt)
        XCTAssertFalse(state.shouldPresentClosingReceipt)

        state.stopActiveOvertime()
        XCTAssertTrue(state.shouldPresentClosingReceipt)
    }

    @MainActor
    func testClosingReceiptSnapshotsCurrencyForHistoricalDisplay() {
        let suiteName = "PayJoyTests.ClosingCurrency.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 19:00:00")
        )

        let receipt = state.completeClosingCapsule()
        var settings = state.settings
        settings.setCurrencyCode(.USD)
        state.settings = settings

        XCTAssertEqual(receipt.currencyCode, .CNY)
        XCTAssertEqual(state.engagementState.capsules.first?.currencyCode, .CNY)
    }

    @MainActor
    func testClosingReceiptUsesLocalDayAfterTimeZoneChange() {
        let suiteName = "PayJoyTests.ClosingTimeZone.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let firstNow = utc.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 19))!
        let secondNow = tokyo.date(from: DateComponents(year: 2026, month: 5, day: 19, hour: 19))!

        let firstState = AppState(
            calculator: SalaryCalculator(calendar: utc),
            store: store,
            now: firstNow
        )
        let first = firstState.completeClosingCapsule()
        XCTAssertEqual(first.dateKey, "2026-05-18")

        let secondState = AppState(
            calculator: SalaryCalculator(calendar: tokyo),
            store: store,
            now: secondNow
        )
        XCTAssertNil(secondState.todayClosingReceipt)
        let second = secondState.completeClosingCapsule()

        XCTAssertEqual(second.dateKey, "2026-05-19")
        XCTAssertEqual(secondState.engagementState.capsules.count, 2)
    }

    @MainActor
    func testClosingReceiptSnapshotsFocusedWishIdentityAndTitle() throws {
        let suiteName = "PayJoyTests.ClosingWishSnapshot.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 19:00:00")
        )
        let wish = try XCTUnwrap(
            state.createWish(title: "去看海", captureSource: .text, targetAmount: 1_000)
        )
        state.updateWishProgress(id: wish.id, progress: 0.35)

        let receipt = state.completeClosingCapsule()

        XCTAssertEqual(receipt.wishID, wish.id)
        XCTAssertEqual(receipt.wishTitle, "去看海")
        XCTAssertEqual(receipt.wishProgress, 0.35)
    }

    func testLegacyClosingReceiptDecodesWithoutWishSnapshotFields() throws {
        let receipt = ClosingCapsule(
            id: "legacy-receipt",
            dateKey: "2026-05-18",
            createdAt: date("2026-05-18 19:00:00"),
            messageIndex: 0,
            earnedAmount: 500,
            currencyCode: .CNY,
            workProgress: 1,
            wishProgress: 0.25,
            wishID: UUID(),
            wishTitle: "旧愿望",
            companionID: CompanionProfile.defaultValue.id,
            mood: .steady,
            tone: .gentle,
            revealsSalary: false
        )
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any]
        )
        payload.removeValue(forKey: "wishID")
        payload.removeValue(forKey: "wishTitle")
        payload.removeValue(forKey: "currencyCode")

        let decoded = try JSONDecoder().decode(
            ClosingCapsule.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )

        XCTAssertNil(decoded.wishID)
        XCTAssertNil(decoded.wishTitle)
        XCTAssertNil(decoded.currencyCode)
        XCTAssertEqual(decoded.wishProgress, 0.25)
    }

    @MainActor
    func testFreeClosingReceiptHistoryKeepsRecordsButShowsSeven() {
        let suiteName = "PayJoyTests.ClosingHistory.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-01 19:00:00")
        )

        for offset in 0..<9 {
            state.now = calendar.date(byAdding: .day, value: offset, to: date("2026-05-01 19:00:00"))!
            _ = state.completeClosingCapsule()
        }

        XCTAssertEqual(state.engagementState.capsules.count, 9)
        XCTAssertEqual(state.visibleClosingReceipts.count, 7)
        XCTAssertTrue(state.hasLockedClosingReceipts)
    }

    @MainActor
    func testClosingReceiptFourHundredCapAndMemberHistory() {
        let suiteName = "PayJoyTests.ClosingHistoryCap.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-01 19:00:00")
        )
        let receipts = (0..<405).map { index in
            ClosingCapsule(
                id: "receipt-\(index)",
                dateKey: String(format: "2026-%03d", index),
                createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                messageIndex: index,
                earnedAmount: Double(index),
                currencyCode: .CNY,
                workProgress: 1,
                wishProgress: nil,
                wishID: nil,
                wishTitle: nil,
                companionID: CompanionProfile.defaultValue.id,
                mood: .steady,
                tone: .gentle,
                revealsSalary: false
            )
        }

        state.engagementState = EngagementState(
            selectedCompanionID: CompanionProfile.defaultValue.id,
            tone: .gentle,
            dailyState: .empty(),
            capsules: receipts
        )

        XCTAssertEqual(state.engagementState.capsules.count, 400)
        XCTAssertEqual(state.visibleClosingReceipts.count, 7)
        XCTAssertTrue(state.hasLockedClosingReceipts)

        var preferences = state.preferences
        preferences.isProUnlocked = true
        state.preferences = preferences

        XCTAssertEqual(state.visibleClosingReceipts.count, 400)
        XCTAssertFalse(state.hasLockedClosingReceipts)
    }

    func testClosingReceiptNotificationRouteDecodesFromUserInfo() {
        let route = AppNotificationResponseHandler.route(
            from: [AppNotificationResponseHandler.routeUserInfoKey: AppNotificationRoute.closingReceipt.rawValue]
        )

        XCTAssertEqual(route, .closingReceipt)
        XCTAssertNil(AppNotificationResponseHandler.route(from: [:]))
    }

    func testLegacyCloudSnapshotKeepsEngagementStateUnset() throws {
        let snapshot = PayJoyCloudSnapshot(
            settings: .defaultValue,
            profile: .defaultValue,
            preferences: .defaultValue,
            overtimeDateKeys: [],
            overtimeRecords: [],
            earlyLeaveDateKeys: [],
            salaryDayRecords: [],
            engagementState: .defaultValue,
            updatedAt: date("2026-05-18 09:00:00")
        )
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        payload.removeValue(forKey: "engagementState")

        let restored = try JSONDecoder().decode(
            PayJoyCloudSnapshot.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )

        XCTAssertNil(restored.engagementState)
    }

    func testPaydaySettingsMigrateAndRoundTrip() throws {
        let legacyData = try JSONEncoder().encode(SalarySettings.defaultValue)
        var legacyPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: legacyData) as? [String: Any])
        legacyPayload.removeValue(forKey: "paydayDay")

        let migrated = try JSONDecoder().decode(
            SalarySettings.self,
            from: JSONSerialization.data(withJSONObject: legacyPayload)
        )
        XCTAssertNil(migrated.paydayDay)

        var configured = migrated
        configured.paydayDay = 25
        let restored = try JSONDecoder().decode(
            SalarySettings.self,
            from: JSONEncoder().encode(configured)
        )
        XCTAssertEqual(restored.paydayDay, 25)
    }

    func testDaysUntilPaydayIgnoresUnsetAndTodayAndUsesNextMonthAfterPayday() {
        var settings = SalarySettings.defaultValue
        XCTAssertNil(calculator.daysUntilPayday(from: date("2026-05-18 09:00:00"), settings: settings))

        settings.paydayDay = 25
        XCTAssertEqual(calculator.daysUntilPayday(from: date("2026-05-18 09:00:00"), settings: settings), 7)
        XCTAssertEqual(calculator.daysUntilPayday(from: date("2026-05-24 23:59:00"), settings: settings), 1)
        XCTAssertNil(calculator.daysUntilPayday(from: date("2026-05-25 08:00:00"), settings: settings))
        XCTAssertEqual(calculator.daysUntilPayday(from: date("2026-05-26 08:00:00"), settings: settings), 30)

        settings.paydayDay = 31
        XCTAssertEqual(calculator.daysUntilPayday(from: date("2026-02-20 12:00:00"), settings: settings), 8)
        XCTAssertNil(calculator.daysUntilPayday(from: date("2026-02-28 12:00:00"), settings: settings))
    }

    @MainActor
    func testPaydaySoonCardStaysOffOnPaydayRestDaysOvertimeAndFarDates() {
        let suiteName = "PayJoyTests.PaydaySoon.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 15:00:00")
        )
        var settings = state.settings
        settings.paydayDay = 25
        state.settings = settings
        XCTAssertEqual(state.paydaySoonDays, 7)

        state.now = date("2026-05-25 15:00:00")
        XCTAssertNil(state.paydaySoonDays)
        XCTAssertTrue(state.isTodayPayday)

        state.now = date("2026-05-15 15:00:00")
        XCTAssertNil(state.paydaySoonDays)

        state.now = date("2026-05-23 15:00:00")
        XCTAssertNil(state.paydaySoonDays)

        state.now = date("2026-05-21 19:30:00")
        state.startOvertimeNow()
        XCTAssertNil(state.paydaySoonDays)
    }

    func testMondayWeekStartAlignsToMonday() {
        XCTAssertEqual(calculator.dateKey(for: calculator.mondayWeekStart(for: date("2026-05-18 09:00:00"))), "2026-05-18")
        XCTAssertEqual(calculator.dateKey(for: calculator.mondayWeekStart(for: date("2026-05-20 15:00:00"))), "2026-05-18")
        XCTAssertEqual(calculator.dateKey(for: calculator.mondayWeekStart(for: date("2026-05-17 12:00:00"))), "2026-05-11")
        XCTAssertEqual(
            calculator.mondayWeekDateKeys(for: date("2026-05-20 15:00:00")),
            [
                "2026-05-18", "2026-05-19", "2026-05-20", "2026-05-21",
                "2026-05-22", "2026-05-23", "2026-05-24"
            ]
        )
    }

    @MainActor
    func testWeeklyEchoAppearsOnWeekendAndFridayAfterWorkOnlyWhenReceiptsExist() {
        let suiteName = "PayJoyTests.WeeklyEcho.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-20 15:00:00")
        )
        XCTAssertFalse(state.shouldShowWeeklyEcho)

        var engagement = state.engagementState
        engagement.capsules = [
            ClosingCapsule(
                id: "week-echo",
                dateKey: "2026-05-20",
                createdAt: date("2026-05-20 19:00:00"),
                messageIndex: 0,
                earnedAmount: 400,
                currencyCode: .CNY,
                workProgress: 1,
                wishProgress: nil,
                wishID: nil,
                wishTitle: nil,
                companionID: CompanionProfile.defaultValue.id,
                mood: .steady,
                tone: .gentle,
                revealsSalary: false
            )
        ]
        state.engagementState = engagement
        XCTAssertFalse(state.shouldShowWeeklyEcho)

        state.now = date("2026-05-22 19:10:00")
        XCTAssertTrue(state.shouldShowWeeklyEcho)

        state.now = date("2026-05-23 10:00:00")
        XCTAssertTrue(state.shouldShowWeeklyEcho)

        state.now = date("2026-05-21 19:30:00")
        state.startOvertimeNow()
        XCTAssertFalse(state.shouldShowWeeklyEcho)
    }

    func testPaydayUsesLastCalendarDayWhenConfiguredDayDoesNotExist() {
        var settings = SalarySettings.defaultValue
        settings.paydayDay = 31

        XCTAssertTrue(calculator.isPayday(date("2026-02-28 00:01:00"), settings: settings))
        XCTAssertTrue(calculator.isPayday(date("2026-02-28 23:59:59"), settings: settings))
        XCTAssertFalse(calculator.isPayday(date("2026-02-27 23:59:59"), settings: settings))
    }

    @MainActor
    func testPaydayAutoCelebrationShowsOnceAndManualEntryStaysAvailable() {
        let suiteName = "PayJoyTests.PaydayPresentation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 19:00:00")
        )
        var settings = state.settings
        settings.paydayDay = 18
        state.settings = settings
        var preferences = state.preferences
        preferences.hasCompletedInitialSetup = true
        state.preferences = preferences

        state.applicationDidBecomeActive()
        XCTAssertTrue(state.shouldPresentPaydayCelebration)
        state.dismissPaydayCelebration()
        state.applicationDidBecomeActive()
        XCTAssertFalse(state.shouldPresentPaydayCelebration)

        state.openPaydayCelebration()
        XCTAssertTrue(state.shouldPresentPaydayCelebration)
    }

    @MainActor
    func testClosingReceiptQueuesBehindPaydayCelebration() {
        let suiteName = "PayJoyTests.PaydayReceiptQueue.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 19:00:00")
        )
        var settings = state.settings
        settings.paydayDay = 18
        state.settings = settings
        var preferences = state.preferences
        preferences.hasCompletedInitialSetup = true
        state.preferences = preferences

        state.applicationDidBecomeActive()
        state.openClosingReceipt()
        XCTAssertTrue(state.shouldPresentPaydayCelebration)
        XCTAssertFalse(state.shouldPresentClosingReceipt)

        state.dismissPaydayCelebration()
        XCTAssertFalse(state.shouldPresentPaydayCelebration)
        XCTAssertTrue(state.shouldPresentClosingReceipt)
    }

    func testActualSalaryEligibilityAllowsPastMonthsAndCurrentMonthAfterPayday() {
        var settings = SalarySettings.defaultValue
        settings.paydayDay = 15

        XCTAssertTrue(calculator.canEnterActualSalary(
            for: date("2026-07-01 12:00:00"),
            now: date("2026-08-01 09:00:00"),
            settings: settings
        ))
        XCTAssertFalse(calculator.canEnterActualSalary(
            for: date("2026-08-01 12:00:00"),
            now: date("2026-08-14 23:59:59"),
            settings: settings
        ))
        XCTAssertTrue(calculator.canEnterActualSalary(
            for: date("2026-08-01 12:00:00"),
            now: date("2026-08-15 00:00:00"),
            settings: settings
        ))
    }

    func testActualSalaryOverridesEstimatedMonthTotals() throws {
        var settings = SalarySettings.defaultValue
        settings.salaryAmount = 18_000
        let older = ActualSalaryRecord(
            monthKey: "2026-07",
            amount: 17_500,
            currencyCode: settings.currencyCode,
            updatedAt: date("2026-08-01 09:00:00")
        )
        let latest = ActualSalaryRecord(
            monthKey: "2026-07",
            amount: 19_240.5,
            currencyCode: settings.currencyCode,
            updatedAt: date("2026-08-02 09:00:00")
        )

        let summary = calculator.salaryMonthSummary(
            for: date("2026-07-01 12:00:00"),
            now: date("2026-08-23 12:00:00"),
            settings: settings,
            records: [],
            actualSalaryRecords: [older, latest]
        )
        XCTAssertEqual(try XCTUnwrap(summary.actualAmount), 19_240.5, accuracy: 0.001)
        XCTAssertEqual(summary.earnedAmount, 19_240.5, accuracy: 0.001)
        XCTAssertEqual(summary.projectedAmount, 19_240.5, accuracy: 0.001)
        XCTAssertEqual(summary.estimatedDayCount, 0)
        XCTAssertEqual(summary.progress, 1, accuracy: 0.001)
    }

    func testActualSalaryWithDifferentCurrencyIsPreservedButExcludedFromTotals() {
        var settings = SalarySettings.defaultValue
        settings.currencyCode = .USD
        settings.currencySymbol = "$"
        let month = date("2026-07-01 12:00:00")
        let now = date("2026-08-23 12:00:00")
        let differentCurrencyRecord = ActualSalaryRecord(
            monthKey: "2026-07",
            amount: 19_240.5,
            currencyCode: .CNY,
            updatedAt: date("2026-08-02 09:00:00")
        )

        let expected = calculator.salaryMonthSummary(
            for: month,
            now: now,
            settings: settings,
            records: []
        )
        let actual = calculator.salaryMonthSummary(
            for: month,
            now: now,
            settings: settings,
            records: [],
            actualSalaryRecords: [differentCurrencyRecord]
        )

        XCTAssertEqual(actual, expected)
        XCTAssertNil(actual.actualAmount)
        XCTAssertEqual(differentCurrencyRecord.currencyCode, .CNY)
    }

    @MainActor
    func testEstimatedSalarySummaryRemainsAvailableForActualSalaryComparison() throws {
        let suiteName = "PayJoyTests.ActualSalaryComparison.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            calculator: calculator,
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-08-23 12:00:00")
        )
        var preferences = state.preferences
        preferences.isProUnlocked = true
        state.preferences = preferences

        let month = date("2026-07-01 12:00:00")
        XCTAssertTrue(state.saveActualSalary(amount: 19_240.5, for: month))

        let actual = state.salaryMonthSummary(for: month)
        let estimate = state.estimatedSalaryMonthSummary(for: month)

        XCTAssertEqual(try XCTUnwrap(actual.actualAmount), 19_240.5, accuracy: 0.001)
        XCTAssertNil(estimate.actualAmount)
        XCTAssertNotEqual(actual.projectedAmount, estimate.projectedAmount)
    }

    func testActualSalaryRecordsAndPaydayMarkerPersistLocally() {
        let suiteName = "PayJoyTests.Payday.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)
        let records = [
            ActualSalaryRecord(
                monthKey: "2026-07",
                amount: 12_345.67,
                currencyCode: .CNY,
                updatedAt: date("2026-08-01 09:00:00")
            )
        ]

        store.saveActualSalaryRecords(records)
        store.markPaydayCelebrationShown(dateKey: "2026-08-23")

        XCTAssertEqual(store.loadActualSalaryRecords(), records)
        XCTAssertEqual(store.lastPaydayCelebrationDate(), "2026-08-23")
    }

    @MainActor
    func testGlobalPrivacyAlwaysHidesPaydayShareAmount() {
        let suiteName = "PayJoyTests.PaydayPrivacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 19:00:00")
        )
        var preferences = state.preferences
        preferences.paydayShareHidesAmount = false
        preferences.hideSensitiveAmounts = false
        state.preferences = preferences
        XCTAssertFalse(state.hidesPaydayShareAmount)

        preferences.hideSensitiveAmounts = true
        state.preferences = preferences
        XCTAssertTrue(state.hidesPaydayShareAmount)
    }

    @MainActor
    func testActualSalaryAndExtraReceiptTonesRequireMembership() {
        let suiteName = "PayJoyTests.MemberGate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            now: date("2026-05-18 19:00:00")
        )
        var settings = state.settings
        settings.paydayDay = 15
        state.settings = settings

        XCTAssertFalse(state.saveActualSalary(amount: 12_345, for: state.now))
        XCTAssertFalse(state.selectEmotionalTone(.dryHumor))

        var preferences = state.preferences
        preferences.isProUnlocked = true
        state.preferences = preferences
        XCTAssertTrue(state.saveActualSalary(amount: 12_345, for: state.now))
        XCTAssertTrue(state.selectEmotionalTone(.dryHumor))
        XCTAssertEqual(state.salaryMonthSummary(for: state.now).actualAmount, 12_345)
        XCTAssertEqual(state.todayPaydayAmount, 12_345)
        XCTAssertTrue(state.todayPaydayAmountIsActual)

        state.removeActualSalary(for: state.now)
        XCTAssertNil(state.salaryMonthSummary(for: state.now).actualAmount)
        XCTAssertFalse(state.todayPaydayAmountIsActual)
        XCTAssertEqual(
            state.todayPaydayAmount,
            state.salaryMonthSummary(for: state.now).projectedAmount,
            accuracy: 0.001
        )
    }

    func testActualSalaryFlowsIntoYearTotals() {
        var settings = SalarySettings.defaultValue
        settings.salaryAmount = 18_000
        let now = date("2026-08-23 12:00:00")
        let july = date("2026-07-01 12:00:00")
        let actual = ActualSalaryRecord(
            monthKey: "2026-07",
            amount: 19_240.5,
            currencyCode: settings.currencyCode,
            updatedAt: date("2026-08-02 09:00:00")
        )
        let withoutActual = calculator.periodEarnings(
            for: .year,
            date: now,
            settings: settings
        )
        let julyEstimate = calculator.salaryMonthSummary(
            for: july,
            now: now,
            settings: settings,
            records: []
        )
        let withActual = calculator.periodEarnings(
            for: .year,
            date: now,
            settings: settings,
            actualSalaryRecords: [actual]
        )

        XCTAssertEqual(
            withActual.earned - withoutActual.earned,
            actual.amount - julyEstimate.earnedAmount,
            accuracy: 0.001
        )
        XCTAssertEqual(
            withActual.projected - withoutActual.projected,
            actual.amount - julyEstimate.projectedAmount,
            accuracy: 0.001
        )
    }

    func testCloudSnapshotActualSalaryRecordsRoundTripAndLegacyDefault() throws {
        let record = ActualSalaryRecord(
            monthKey: "2026-07",
            amount: 12_345.67,
            currencyCode: .CNY,
            updatedAt: date("2026-08-01 09:00:00")
        )
        let snapshot = PayJoyCloudSnapshot(
            settings: .defaultValue,
            profile: .defaultValue,
            preferences: .defaultValue,
            overtimeDateKeys: [],
            overtimeRecords: [],
            earlyLeaveDateKeys: [],
            salaryDayRecords: [],
            actualSalaryRecords: [record],
            updatedAt: date("2026-08-23 09:00:00")
        )
        let roundTrip = try JSONDecoder().decode(
            PayJoyCloudSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        XCTAssertEqual(roundTrip.actualSalaryRecords, [record])

        var legacyPayload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )
        legacyPayload.removeValue(forKey: "actualSalaryRecords")
        let legacy = try JSONDecoder().decode(
            PayJoyCloudSnapshot.self,
            from: JSONSerialization.data(withJSONObject: legacyPayload)
        )
        XCTAssertTrue(legacy.actualSalaryRecords.isEmpty)
    }

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)!
    }
}
