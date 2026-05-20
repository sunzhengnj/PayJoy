import CloudKit
import Foundation

struct PayJoyCloudSnapshot: Codable, Equatable {
    var settings: SalarySettings
    var profile: UserProfile
    var preferences: AppPreferences
    var overtimeDateKeys: Set<String>
    var updatedAt: Date
}

struct PayJoyCloudKitService {
    private let container: CKContainer
    private let recordID = CKRecord.ID(recordName: "payjoy-primary-data")

    init(container: CKContainer = CKContainer(identifier: "iCloud.com.sunzheng.PayJoy")) {
        self.container = container
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    func saveSnapshot(_ snapshot: PayJoyCloudSnapshot) async throws {
        let database = container.privateCloudDatabase
        let record = (try? await database.record(for: recordID)) ?? CKRecord(recordType: "PayJoyUserData", recordID: recordID)
        record["payloadJSON"] = try JSONEncoder().encode(snapshot).base64EncodedString()
        record["updatedAt"] = snapshot.updatedAt
        _ = try await database.save(record)
    }

    func fetchSnapshot() async throws -> PayJoyCloudSnapshot? {
        let database = container.privateCloudDatabase
        guard let record = try? await database.record(for: recordID),
              let payload = record["payloadJSON"] as? String,
              let data = Data(base64Encoded: payload) else {
            return nil
        }
        return try JSONDecoder().decode(PayJoyCloudSnapshot.self, from: data)
    }

    func deleteAllPrivateData() async throws {
        let database = container.privateCloudDatabase
        guard (try? await database.record(for: recordID)) != nil else { return }
        _ = try await database.deleteRecord(withID: recordID)
    }
}
