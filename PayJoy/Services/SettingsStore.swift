import Foundation

struct SettingsStore {
    private let salaryKey = "payjoy.salary.settings"
    private let profileKey = "payjoy.user.profile"
    private let preferencesKey = "payjoy.app.preferences"
    private let overtimeDaysKey = "payjoy.overtime.days"
    private let appleAccountKey = "payjoy.apple.account"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
            return preferences
        }
        guard let data = sharedDefaults?.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return .defaultValue
        }
        return preferences
    }

    func savePreferences(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: preferencesKey)
        sharedDefaults?.set(data, forKey: preferencesKey)
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

    func clearAllLocalData() {
        [salaryKey, profileKey, preferencesKey, overtimeDaysKey, appleAccountKey].forEach { key in
            defaults.removeObject(forKey: key)
            sharedDefaults?.removeObject(forKey: key)
        }
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    }
}
