import CloudKit
import Foundation

struct PayJoyCloudSnapshot: Codable, Equatable {
    var settings: SalarySettings
    var profile: UserProfile
    var preferences: AppPreferences
    var overtimeDateKeys: Set<String>
    var overtimeRecords: [OvertimeRecord]
    var earlyLeaveDateKeys: Set<String>
    var salaryDayRecords: [SalaryDayRecord]
    var actualSalaryRecords: [ActualSalaryRecord]
    var wishExperiences: [WishExperience]?
    var personalGoal: LegacyPersonalGoal?
    var salaryWishes: [LegacySalaryWish]?
    var engagementState: EngagementState?
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case settings
        case profile
        case preferences
        case overtimeDateKeys
        case overtimeRecords
        case earlyLeaveDateKeys
        case salaryDayRecords
        case actualSalaryRecords
        case wishExperiences
        case personalGoal
        case salaryWishes
        case engagementState
        case updatedAt
    }

    init(
        settings: SalarySettings,
        profile: UserProfile,
        preferences: AppPreferences,
        overtimeDateKeys: Set<String>,
        overtimeRecords: [OvertimeRecord],
        earlyLeaveDateKeys: Set<String>,
        salaryDayRecords: [SalaryDayRecord],
        actualSalaryRecords: [ActualSalaryRecord] = [],
        wishExperiences: [WishExperience] = [],
        engagementState: EngagementState? = nil,
        updatedAt: Date
    ) {
        self.settings = settings
        self.profile = profile
        self.preferences = preferences
        self.overtimeDateKeys = overtimeDateKeys
        self.overtimeRecords = overtimeRecords
        self.earlyLeaveDateKeys = earlyLeaveDateKeys
        self.salaryDayRecords = salaryDayRecords
        self.actualSalaryRecords = actualSalaryRecords
        self.wishExperiences = wishExperiences
        self.personalGoal = nil
        self.salaryWishes = nil
        self.engagementState = engagementState
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(SalarySettings.self, forKey: .settings)
        profile = try container.decode(UserProfile.self, forKey: .profile)
        preferences = try container.decode(AppPreferences.self, forKey: .preferences)
        overtimeDateKeys = try container.decodeIfPresent(Set<String>.self, forKey: .overtimeDateKeys) ?? []
        overtimeRecords = try container.decodeIfPresent([OvertimeRecord].self, forKey: .overtimeRecords) ?? []
        earlyLeaveDateKeys = try container.decodeIfPresent(Set<String>.self, forKey: .earlyLeaveDateKeys) ?? []
        salaryDayRecords = try container.decodeIfPresent([SalaryDayRecord].self, forKey: .salaryDayRecords) ?? []
        actualSalaryRecords = try container.decodeIfPresent([ActualSalaryRecord].self, forKey: .actualSalaryRecords) ?? []
        wishExperiences = try container.decodeIfPresent([WishExperience].self, forKey: .wishExperiences)
        personalGoal = try container.decodeIfPresent(LegacyPersonalGoal.self, forKey: .personalGoal)
        salaryWishes = try container.decodeIfPresent([LegacySalaryWish].self, forKey: .salaryWishes)
        engagementState = try container.decodeIfPresent(EngagementState.self, forKey: .engagementState)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum PayJoyCloudPayloadCodec {
    private static let compressedPrefix = "lzfse:"

    static func encode(_ snapshot: PayJoyCloudSnapshot) throws -> String {
        let data = try JSONEncoder().encode(snapshot)
        let compressedData = try (data as NSData).compressed(using: .lzfse)
        return compressedPrefix + Data(compressedData).base64EncodedString()
    }

    static func decode(_ payload: String) throws -> PayJoyCloudSnapshot {
        let isCompressed = payload.hasPrefix(compressedPrefix)
        let encodedPayload = isCompressed
            ? String(payload.dropFirst(compressedPrefix.count))
            : payload
        guard let payloadData = Data(base64Encoded: encodedPayload) else {
            throw PayJoyCloudFallbackError.invalidPayload
        }
        let data: Data
        if isCompressed {
            data = Data(try (payloadData as NSData).decompressed(using: .lzfse))
        } else {
            data = payloadData
        }
        return try JSONDecoder().decode(PayJoyCloudSnapshot.self, from: data)
    }
}

struct PayJoyCloudKitService {
    private let container: CKContainer?
    private let recordID = CKRecord.ID(recordName: "payjoy-primary-data")
    private let keyValueStore: NSUbiquitousKeyValueStore?
    private let keyValuePayloadKey = "payjoy.primaryData.payloadJSON"
    private let keyValueUpdatedAtKey = "payjoy.primaryData.updatedAt"

    init(
        container: CKContainer? = Self.defaultContainer(),
        keyValueStore: NSUbiquitousKeyValueStore? = Self.defaultKeyValueStore()
    ) {
        self.container = container
        self.keyValueStore = keyValueStore
    }

    func accountStatus() async throws -> CKAccountStatus {
        guard let container else { throw PayJoyCloudFallbackError.cloudKitUnavailable }
        return try await container.accountStatus()
    }

    func saveSnapshot(_ snapshot: PayJoyCloudSnapshot) async throws {
        let payload = try PayJoyCloudPayloadCodec.encode(snapshot)
        guard container != nil else {
            guard keyValueStore != nil else { throw PayJoyCloudFallbackError.cloudKitUnavailable }
            try saveKeyValuePayload(payload, updatedAt: snapshot.updatedAt)
            return
        }
        do {
            try await saveCloudKitPayload(payload, updatedAt: snapshot.updatedAt)
            try? saveKeyValuePayload(payload, updatedAt: snapshot.updatedAt)
        } catch {
            guard shouldFallbackToKeyValueStore(error) else { throw error }
            try saveKeyValuePayload(payload, updatedAt: snapshot.updatedAt)
        }
    }

    func fetchSnapshot() async throws -> PayJoyCloudSnapshot? {
        guard container != nil || keyValueStore != nil else {
            throw PayJoyCloudFallbackError.cloudKitUnavailable
        }
        let fallbackSnapshot = try fetchKeyValueSnapshot()
        guard container != nil else { return fallbackSnapshot }
        do {
            guard let cloudKitSnapshot = try await fetchCloudKitSnapshot() else {
                return fallbackSnapshot
            }
            if let fallbackSnapshot, fallbackSnapshot.updatedAt > cloudKitSnapshot.updatedAt {
                return fallbackSnapshot
            }
            return cloudKitSnapshot
        } catch {
            guard shouldFallbackToKeyValueStore(error) else { throw error }
            return fallbackSnapshot
        }
    }

    func deleteAllPrivateData() async throws {
        keyValueStore?.removeObject(forKey: keyValuePayloadKey)
        keyValueStore?.removeObject(forKey: keyValueUpdatedAtKey)
        _ = keyValueStore?.synchronize()

        guard let container else { return }
        let database = container.privateCloudDatabase
        guard (try? await database.record(for: recordID)) != nil else { return }
        _ = try await database.deleteRecord(withID: recordID)
    }

    private func saveCloudKitPayload(_ payload: String, updatedAt: Date) async throws {
        guard let container else { throw PayJoyCloudFallbackError.cloudKitUnavailable }
        let database = container.privateCloudDatabase
        let record = (try? await database.record(for: recordID)) ?? CKRecord(recordType: "PayJoyUserData", recordID: recordID)
        record["payloadJSON"] = payload
        record["updatedAt"] = updatedAt
        _ = try await database.save(record)
    }

    private func fetchCloudKitSnapshot() async throws -> PayJoyCloudSnapshot? {
        guard let container else { throw PayJoyCloudFallbackError.cloudKitUnavailable }
        let database = container.privateCloudDatabase
        do {
            let record = try await database.record(for: recordID)
            guard let payload = record["payloadJSON"] as? String else {
                return nil
            }
            return try PayJoyCloudPayloadCodec.decode(payload)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return nil
            }
            throw error
        }
    }

    private func saveKeyValuePayload(_ payload: String, updatedAt: Date) throws {
        guard let keyValueStore else { throw PayJoyCloudFallbackError.cloudKitUnavailable }
        keyValueStore.set(payload, forKey: keyValuePayloadKey)
        keyValueStore.set(updatedAt.timeIntervalSince1970, forKey: keyValueUpdatedAtKey)
        guard keyValueStore.synchronize() else {
            throw PayJoyCloudFallbackError.keyValueStoreUnavailable
        }
    }

    private func fetchKeyValueSnapshot() throws -> PayJoyCloudSnapshot? {
        guard let keyValueStore else { return nil }
        guard let payload = keyValueStore.string(forKey: keyValuePayloadKey) else {
            return nil
        }
        return try PayJoyCloudPayloadCodec.decode(payload)
    }

    private func shouldFallbackToKeyValueStore(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        switch ckError.code {
        case .serverRejectedRequest, .invalidArguments, .constraintViolation, .partialFailure, .unknownItem, .serverRecordChanged:
            return true
        default:
            return false
        }
    }

    private static func defaultContainer() -> CKContainer? {
#if targetEnvironment(simulator)
        return nil
#else
        return CKContainer(identifier: "iCloud.com.sunzheng.PayJoy")
#endif
    }

    private static func defaultKeyValueStore() -> NSUbiquitousKeyValueStore? {
#if targetEnvironment(simulator)
        return nil
#else
        return .default
#endif
    }
}

enum PayJoyCloudFallbackError: Error {
    case keyValueStoreUnavailable
    case cloudKitUnavailable
    case invalidPayload
}
