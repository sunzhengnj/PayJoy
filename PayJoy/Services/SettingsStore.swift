import Foundation
import Security

struct AppLockCredential: Equatable {
    let salt: String
    let hash: String

    init?(salt: String?, hash: String?) {
        guard let salt, !salt.isEmpty, let hash, !hash.isEmpty else { return nil }
        self.salt = salt
        self.hash = hash
    }
}

struct SettingsStore {
    private let salaryKey = "payjoy.salary.settings"
    private let profileKey = "payjoy.user.profile"
    private let preferencesKey = "payjoy.app.preferences"
    private let selectedThemeKey = "payjoy.app.selected.theme"
    private let overtimeDaysKey = "payjoy.overtime.days"
    private let overtimeRecordsKey = "payjoy.overtime.records"
    private let earlyLeaveDaysKey = "payjoy.early.leave.days"
    private let salaryDayRecordsKey = "payjoy.salary.day.records"
    private let actualSalaryRecordsKey = "payjoy.actual.salary.records.v1"
    private let lastPaydayCelebrationDateKey = "payjoy.payday.celebration.last.date"
    private let personalGoalKey = "payjoy.personal.goal"
    private let salaryWishesKey = "payjoy.salary.wishes"
    private let wishExperiencesKey = "payjoy.wish.experiences.v1"
    private let engagementStateKey = "payjoy.engagement.state.v1"
    private let appleAccountKey = "payjoy.apple.account"
    private let cloudSyncInitializedAccountKey = "payjoy.cloud.sync.initialized.account"
    private let bossKeyExitGuideKey = "payjoy.boss.key.didShowExitGuide"
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?

    init(
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    ) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
    }

    func load() -> SalarySettings {
        if let data = defaults.data(forKey: salaryKey),
           let settings = try? JSONDecoder().decode(SalarySettings.self, from: data) {
            return settings
        }
        guard let data = sharedDefaults?.data(forKey: salaryKey),
              let settings = try? JSONDecoder().decode(SalarySettings.self, from: data) else {
            return .defaultValue
        }
        return settings
    }

    func save(_ settings: SalarySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: salaryKey)
        sharedDefaults?.set(data, forKey: salaryKey)
    }

    func loadProfile() -> UserProfile {
        if let data = defaults.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        guard let data = sharedDefaults?.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return .defaultValue
        }
        return profile
    }

    func saveProfile(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKey)
        sharedDefaults?.set(data, forKey: profileKey)
    }

    func loadPreferences() -> AppPreferences {
        if let data = defaults.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            cacheSelectedTheme(preferences.selectedTheme)
            return preferences
        }
        guard let data = sharedDefaults?.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return .defaultValue
        }
        cacheSelectedTheme(preferences.selectedTheme)
        return preferences
    }

    func savePreferences(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: preferencesKey)
        sharedDefaults?.set(data, forKey: preferencesKey)
        cacheSelectedTheme(preferences.selectedTheme)
        defaults.synchronize()
        sharedDefaults?.synchronize()
    }

    private func cacheSelectedTheme(_ theme: AppVisualTheme) {
        defaults.set(theme.rawValue, forKey: selectedThemeKey)
        sharedDefaults?.set(theme.rawValue, forKey: selectedThemeKey)
    }

    func loadOvertimeDays() -> Set<String> {
        if let data = defaults.data(forKey: overtimeDaysKey),
           let days = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return days
        }
        guard let data = sharedDefaults?.data(forKey: overtimeDaysKey),
              let days = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return days
    }

    func saveOvertimeDays(_ days: Set<String>) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        defaults.set(data, forKey: overtimeDaysKey)
        sharedDefaults?.set(data, forKey: overtimeDaysKey)
    }

    func loadOvertimeRecords() -> [OvertimeRecord] {
        if let data = defaults.data(forKey: overtimeRecordsKey),
           let records = try? JSONDecoder().decode([OvertimeRecord].self, from: data) {
            return records
        }
        guard let data = sharedDefaults?.data(forKey: overtimeRecordsKey),
              let records = try? JSONDecoder().decode([OvertimeRecord].self, from: data) else {
            return []
        }
        return records
    }

    func saveOvertimeRecords(_ records: [OvertimeRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: overtimeRecordsKey)
        sharedDefaults?.set(data, forKey: overtimeRecordsKey)
    }

    func loadEarlyLeaveDays() -> Set<String> {
        if let data = defaults.data(forKey: earlyLeaveDaysKey),
           let days = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return days
        }
        guard let data = sharedDefaults?.data(forKey: earlyLeaveDaysKey),
              let days = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return days
    }

    func saveEarlyLeaveDays(_ days: Set<String>) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        defaults.set(data, forKey: earlyLeaveDaysKey)
        sharedDefaults?.set(data, forKey: earlyLeaveDaysKey)
    }

    func loadSalaryDayRecords() -> [SalaryDayRecord] {
        if let data = defaults.data(forKey: salaryDayRecordsKey),
           let records = try? JSONDecoder().decode([SalaryDayRecord].self, from: data) {
            return records
        }
        guard let data = sharedDefaults?.data(forKey: salaryDayRecordsKey),
              let records = try? JSONDecoder().decode([SalaryDayRecord].self, from: data) else {
            return []
        }
        return records
    }

    func saveSalaryDayRecords(_ records: [SalaryDayRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: salaryDayRecordsKey)
        sharedDefaults?.set(data, forKey: salaryDayRecordsKey)
    }

    func loadActualSalaryRecords() -> [ActualSalaryRecord] {
        if let data = defaults.data(forKey: actualSalaryRecordsKey),
           let records = try? JSONDecoder().decode([ActualSalaryRecord].self, from: data) {
            return records
        }
        guard let data = sharedDefaults?.data(forKey: actualSalaryRecordsKey),
              let records = try? JSONDecoder().decode([ActualSalaryRecord].self, from: data) else {
            return []
        }
        return records
    }

    func saveActualSalaryRecords(_ records: [ActualSalaryRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: actualSalaryRecordsKey)
        sharedDefaults?.set(data, forKey: actualSalaryRecordsKey)
    }

    func lastPaydayCelebrationDate() -> String? {
        defaults.string(forKey: lastPaydayCelebrationDateKey)
    }

    func markPaydayCelebrationShown(dateKey: String) {
        defaults.set(dateKey, forKey: lastPaydayCelebrationDateKey)
    }

    func loadWishExperiences() -> [WishExperience] {
        if let data = defaults.data(forKey: wishExperiencesKey),
           let wishes = try? JSONDecoder().decode([WishExperience].self, from: data) {
            return wishes
        }
        if let data = sharedDefaults?.data(forKey: wishExperiencesKey),
           let wishes = try? JSONDecoder().decode([WishExperience].self, from: data) {
            return wishes
        }
        let migrated = migrateLegacyWishes()
        if !migrated.isEmpty {
            saveWishExperiences(migrated)
        }
        return migrated
    }

    func saveWishExperiences(_ wishes: [WishExperience]) {
        guard let data = try? JSONEncoder().encode(wishes) else { return }
        defaults.set(data, forKey: wishExperiencesKey)
        sharedDefaults?.set(data, forKey: wishExperiencesKey)
        defaults.removeObject(forKey: personalGoalKey)
        defaults.removeObject(forKey: salaryWishesKey)
        sharedDefaults?.removeObject(forKey: personalGoalKey)
        sharedDefaults?.removeObject(forKey: salaryWishesKey)
    }

    private func migrateLegacyWishes() -> [WishExperience] {
        let decoder = JSONDecoder()
        let legacyGoalData = defaults.data(forKey: personalGoalKey)
            ?? sharedDefaults?.data(forKey: personalGoalKey)
        let legacyWishesData = defaults.data(forKey: salaryWishesKey)
            ?? sharedDefaults?.data(forKey: salaryWishesKey)
        let goal = legacyGoalData.flatMap { try? decoder.decode(LegacyPersonalGoal.self, from: $0) }
        let wishes = legacyWishesData.flatMap { try? decoder.decode([LegacySalaryWish].self, from: $0) } ?? []
        let currencyCode = CurrencyCode.defaultCode(for: .systemResolved)

        var migrated: [WishExperience] = []
        if let goal {
            migrated.append(
                WishExperience(
                    title: goal.title,
                    targetAmount: Decimal(goal.targetAmount),
                    currencyCode: currencyCode,
                    createdAt: goal.startedAt,
                    focusedAt: goal.startedAt
                )
            )
        }
        migrated.append(contentsOf: wishes.map { wish in
            WishExperience(
                id: wish.id,
                title: wish.title,
                targetAmount: Decimal(wish.targetAmount),
                currencyCode: currencyCode,
                status: wish.isCompleted ? .completed : .active,
                createdAt: wish.createdAt,
                completedAt: wish.isCompleted ? Date() : nil
            )
        })
        return migrated
    }

    func loadEngagementState() -> EngagementState {
        if let data = defaults.data(forKey: engagementStateKey),
           let state = try? JSONDecoder().decode(EngagementState.self, from: data) {
            return state
        }
        guard let data = sharedDefaults?.data(forKey: engagementStateKey),
              let state = try? JSONDecoder().decode(EngagementState.self, from: data) else {
            return .defaultValue
        }
        return state
    }

    func saveEngagementState(_ state: EngagementState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: engagementStateKey)
        sharedDefaults?.set(data, forKey: engagementStateKey)
    }

    func loadAppleAccount() -> AppleAccount? {
        if let data = defaults.data(forKey: appleAccountKey),
           let account = try? JSONDecoder().decode(AppleAccount.self, from: data) {
            return account
        }
        guard let data = sharedDefaults?.data(forKey: appleAccountKey),
              let account = try? JSONDecoder().decode(AppleAccount.self, from: data) else {
            return nil
        }
        return account
    }

    func saveAppleAccount(_ account: AppleAccount) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        defaults.set(data, forKey: appleAccountKey)
        sharedDefaults?.set(data, forKey: appleAccountKey)
    }

    func clearAppleAccount() {
        defaults.removeObject(forKey: appleAccountKey)
        sharedDefaults?.removeObject(forKey: appleAccountKey)
    }

    func hasInitializedCloudSync(for userIdentifier: String) -> Bool {
        if defaults.string(forKey: cloudSyncInitializedAccountKey) == userIdentifier {
            return true
        }
        return sharedDefaults?.string(forKey: cloudSyncInitializedAccountKey) == userIdentifier
    }

    func markCloudSyncInitialized(for userIdentifier: String) {
        defaults.set(userIdentifier, forKey: cloudSyncInitializedAccountKey)
        sharedDefaults?.set(userIdentifier, forKey: cloudSyncInitializedAccountKey)
    }

    func loadAppLockCredential() -> AppLockCredential? {
        AppLockCredential(
            salt: KeychainAppLockStore.value(for: .salt),
            hash: KeychainAppLockStore.value(for: .hash)
        )
    }

    @discardableResult
    func saveAppLockCredential(_ credential: AppLockCredential) -> Bool {
        guard KeychainAppLockStore.save(credential.salt, for: .salt),
              KeychainAppLockStore.save(credential.hash, for: .hash) else {
            KeychainAppLockStore.clear()
            return false
        }
        return true
    }

    func clearAppLockCredential() {
        KeychainAppLockStore.clear()
    }

    func migrateLegacyAppLockCredential(from preferences: inout AppPreferences) -> AppLockCredential? {
        guard preferences.appLockEnabled else {
            clearAppLockCredential()
            preferences.clearLegacyAppLockCredential()
            return nil
        }

        if let credential = loadAppLockCredential() {
            preferences.clearLegacyAppLockCredential()
            return credential
        }

        guard let legacyCredential = AppLockCredential(
            salt: preferences.appLockPasscodeSalt,
            hash: preferences.appLockPasscodeHash
        ), saveAppLockCredential(legacyCredential) else {
            preferences.appLockEnabled = false
            preferences.clearLegacyAppLockCredential()
            return nil
        }

        preferences.clearLegacyAppLockCredential()
        return legacyCredential
    }

    func clearAllLocalData() {
        [salaryKey, profileKey, preferencesKey, selectedThemeKey, overtimeDaysKey, overtimeRecordsKey, earlyLeaveDaysKey, salaryDayRecordsKey, actualSalaryRecordsKey, lastPaydayCelebrationDateKey, personalGoalKey, salaryWishesKey, wishExperiencesKey, engagementStateKey, appleAccountKey, cloudSyncInitializedAccountKey, bossKeyExitGuideKey].forEach { key in
            defaults.removeObject(forKey: key)
            sharedDefaults?.removeObject(forKey: key)
        }
        clearAppLockCredential()
    }

}

enum EngagementEvent: String, CaseIterable {
    case onboardingStarted
    case onboardingCompleted
    case firstValueReached
    case moodSelected
    case wishCreated
    case closingReceiptOpened
    case closingCapsuleCompleted
    case closingCapsuleShared
    case paywallViewed
    case purchaseStarted
    case purchaseCompleted
}

protocol EngagementAnalytics {
    func record(_ event: EngagementEvent, market: AppMarket)
}

struct LocalEngagementAnalytics: EngagementAnalytics {
    private let defaults: UserDefaults
    private let keyPrefix = "payjoy.analytics.aggregate"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(_ event: EngagementEvent, market: AppMarket) {
        let key = "\(keyPrefix).\(market.rawValue).\(event.rawValue)"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }
}

private enum KeychainAppLockStore {
    enum Account: String {
        case salt = "salt"
        case hash = "hash"
    }

    private static let service = "app.payjoy.kaixin.app-lock"

    static func value(for account: Account) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String, for account: Account) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: Data(value.utf8),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        guard updateStatus == errSecItemNotFound else { return false }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func clear() {
        [Account.salt, .hash].forEach { account in
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account.rawValue
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
