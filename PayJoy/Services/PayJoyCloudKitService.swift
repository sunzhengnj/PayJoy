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
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case settings
        case profile
        case preferences
        case overtimeDateKeys
        case overtimeRecords
        case earlyLeaveDateKeys
        case salaryDayRecords
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
        updatedAt: Date
    ) {
        self.settings = settings
        self.profile = profile
        self.preferences = preferences
        self.overtimeDateKeys = overtimeDateKeys
        self.overtimeRecords = overtimeRecords
        self.earlyLeaveDateKeys = earlyLeaveDateKeys
        self.salaryDayRecords = salaryDayRecords
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
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct PayJoyCloudKitService {
    private let container: CKContainer
    private let recordID = CKRecord.ID(recordName: "payjoy-primary-data")
    private let keyValueStore: NSUbiquitousKeyValueStore
    private let keyValuePayloadKey = "payjoy.primaryData.payloadJSON"
    private let keyValueUpdatedAtKey = "payjoy.primaryData.updatedAt"

    init(
        container: CKContainer = CKContainer(identifier: "iCloud.com.sunzheng.PayJoy"),
        keyValueStore: NSUbiquitousKeyValueStore = .default
    ) {
        self.container = container
        self.keyValueStore = keyValueStore
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    func saveSnapshot(_ snapshot: PayJoyCloudSnapshot) async throws {
        let payload = try JSONEncoder().encode(snapshot).base64EncodedString()
        do {
            try await saveCloudKitPayload(payload, updatedAt: snapshot.updatedAt)
            try? saveKeyValuePayload(payload, updatedAt: snapshot.updatedAt)
        } catch {
            guard shouldFallbackToKeyValueStore(error) else { throw error }
            try saveKeyValuePayload(payload, updatedAt: snapshot.updatedAt)
        }
    }

    func fetchSnapshot() async throws -> PayJoyCloudSnapshot? {
        let fallbackSnapshot = try fetchKeyValueSnapshot()
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
        keyValueStore.removeObject(forKey: keyValuePayloadKey)
        keyValueStore.removeObject(forKey: keyValueUpdatedAtKey)
        _ = keyValueStore.synchronize()

        let database = container.privateCloudDatabase
        guard (try? await database.record(for: recordID)) != nil else { return }
        _ = try await database.deleteRecord(withID: recordID)
    }

    private func saveCloudKitPayload(_ payload: String, updatedAt: Date) async throws {
        let database = container.privateCloudDatabase
        let record = (try? await database.record(for: recordID)) ?? CKRecord(recordType: "PayJoyUserData", recordID: recordID)
        record["payloadJSON"] = payload
        record["updatedAt"] = updatedAt
        _ = try await database.save(record)
    }

    private func fetchCloudKitSnapshot() async throws -> PayJoyCloudSnapshot? {
        let database = container.privateCloudDatabase
        do {
            let record = try await database.record(for: recordID)
            guard let payload = record["payloadJSON"] as? String,
                  let data = Data(base64Encoded: payload) else {
                return nil
            }
            return try JSONDecoder().decode(PayJoyCloudSnapshot.self, from: data)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return nil
            }
            throw error
        }
    }

    private func saveKeyValuePayload(_ payload: String, updatedAt: Date) throws {
        keyValueStore.set(payload, forKey: keyValuePayloadKey)
        keyValueStore.set(updatedAt.timeIntervalSince1970, forKey: keyValueUpdatedAtKey)
        guard keyValueStore.synchronize() else {
            throw PayJoyCloudFallbackError.keyValueStoreUnavailable
        }
    }

    private func fetchKeyValueSnapshot() throws -> PayJoyCloudSnapshot? {
        guard let payload = keyValueStore.string(forKey: keyValuePayloadKey),
              let data = Data(base64Encoded: payload) else {
            return nil
        }
        return try JSONDecoder().decode(PayJoyCloudSnapshot.self, from: data)
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
}

enum PayJoyCloudFallbackError: Error {
    case keyValueStoreUnavailable
}
