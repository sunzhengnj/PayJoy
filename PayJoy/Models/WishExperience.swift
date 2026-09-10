import Foundation

enum WishArchetype: String, Codable, CaseIterable, Identifiable {
    case possession
    case companion
    case journey
    case growth
    case generic

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .possession: "想买"
        case .companion: "想拥有"
        case .journey: "想去"
        case .growth: "想学会"
        case .generic: "一个愿望"
        }
    }

    var builtInCoverAssetName: String {
        switch self {
        case .possession: "wish_possession_preview_v1"
        case .companion: "wish_companion_preview_v1"
        case .journey: "wish_journey_preview_v1"
        case .growth, .generic: "wish_journey_preview_v1"
        }
    }

    static func classify(_ text: String) -> WishArchetype {
        let normalized = text.lowercased()
        let companionWords = ["玩偶", "毛绒", "jellycat", "公仔", "娃娃", "小狮子", "狮子", "plush", "lion", "ぬいぐるみ", "인형", "宠物", "猫", "狗"]
        let journeyWords = ["去", "旅行", "旅游", "trip", "travel", "tour", "visit", "旅", "여행", "concert", "演唱会", "演出", "乐园"]
        let growthWords = ["学", "课程", "证书", "健身", "跑步", "语言", "course", "learn", "study", "fitness", "勉強", "習う", "배우", "공부"]
        let possessionWords = ["买", "手机", "电脑", "相机", "耳机", "包", "鞋", "phone", "iphone", "camera", "laptop", "headphone", "買", "欲しい", "사고", "구매"]

        if companionWords.contains(where: normalized.contains) { return .possession }
        if journeyWords.contains(where: normalized.contains) { return .journey }
        if growthWords.contains(where: normalized.contains) { return .growth }
        if possessionWords.contains(where: normalized.contains) { return .possession }
        return .generic
    }
}

enum WishCaptureSource: String, Codable, CaseIterable {
    case text
    case link
    case photo
    case screenshot
    case inspiration
}

enum WishStatus: String, Codable, CaseIterable {
    case active
    case paused
    case completed
    case abandoned
}

struct ExternalPlanningLink: Codable, Equatable {
    var providerID: String
    var externalWishID: String?
    var linkedAt: Date?
}

struct WishExperience: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var archetype: WishArchetype
    var captureSource: WishCaptureSource
    var sourceURL: URL?
    var coverAssetReference: String?
    var targetAmount: Decimal?
    var currencyCode: CurrencyCode?
    var manualProgress: Double?
    var status: WishStatus
    var createdAt: Date
    var focusedAt: Date?
    var completedAt: Date?
    var planningLink: ExternalPlanningLink?
    var realizedAssetReference: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case archetype
        case captureSource
        case sourceURL
        case coverAssetReference
        case targetAmount
        case currencyCode
        case manualProgress
        case status
        case createdAt
        case focusedAt
        case completedAt
        case planningLink
        case realizedAssetReference
        // Retired story fields are decoded only when needed for one-time progress migration.
        case workValueProgress
        case storyboardID
        case sceneStates
        case futureFrames
        case companionName
    }

    init(
        id: UUID = UUID(),
        title: String,
        archetype: WishArchetype? = nil,
        captureSource: WishCaptureSource = .text,
        sourceURL: URL? = nil,
        coverAssetReference: String? = nil,
        targetAmount: Decimal? = nil,
        currencyCode: CurrencyCode? = nil,
        manualProgress: Double? = nil,
        status: WishStatus = .active,
        createdAt: Date = Date(),
        focusedAt: Date? = nil,
        completedAt: Date? = nil,
        planningLink: ExternalPlanningLink? = nil,
        realizedAssetReference: String? = nil
    ) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedArchetype = archetype ?? WishArchetype.classify(cleanedTitle)
        self.id = id
        self.title = cleanedTitle
        self.archetype = resolvedArchetype
        self.captureSource = captureSource
        self.sourceURL = sourceURL
        self.coverAssetReference = coverAssetReference
        self.targetAmount = targetAmount.map { max(0, $0) }
        self.currencyCode = currencyCode
        self.manualProgress = manualProgress.map { min(1, max(0, $0)) }
        self.status = status
        self.createdAt = createdAt
        self.focusedAt = focusedAt
        self.completedAt = completedAt
        self.planningLink = planningLink
        self.realizedAssetReference = realizedAssetReference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        let decodedTarget = try container.decodeIfPresent(Decimal.self, forKey: .targetAmount).map { max(0, $0) }
        let decodedManualProgress = try container.decodeIfPresent(Double.self, forKey: .manualProgress)
        let legacyWorkValue = try container.decodeIfPresent(Decimal.self, forKey: .workValueProgress)
        let migratedProgress: Double?
        if let decodedManualProgress {
            migratedProgress = min(1, max(0, decodedManualProgress))
        } else if let decodedTarget, decodedTarget > 0, let legacyWorkValue {
            migratedProgress = min(1, max(0, NSDecimalNumber(decimal: legacyWorkValue / decodedTarget).doubleValue))
        } else {
            migratedProgress = nil
        }

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = decodedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        archetype = try container.decodeIfPresent(WishArchetype.self, forKey: .archetype)
            ?? WishArchetype.classify(title)
        captureSource = try container.decodeIfPresent(WishCaptureSource.self, forKey: .captureSource) ?? .text
        sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
        coverAssetReference = try container.decodeIfPresent(String.self, forKey: .coverAssetReference)
        targetAmount = decodedTarget
        currencyCode = try container.decodeIfPresent(CurrencyCode.self, forKey: .currencyCode)
        manualProgress = migratedProgress
        status = try container.decodeIfPresent(WishStatus.self, forKey: .status) ?? .active
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        focusedAt = try container.decodeIfPresent(Date.self, forKey: .focusedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        planningLink = try container.decodeIfPresent(ExternalPlanningLink.self, forKey: .planningLink)
        realizedAssetReference = try container.decodeIfPresent(String.self, forKey: .realizedAssetReference)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(archetype, forKey: .archetype)
        try container.encode(captureSource, forKey: .captureSource)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encodeIfPresent(coverAssetReference, forKey: .coverAssetReference)
        try container.encodeIfPresent(targetAmount, forKey: .targetAmount)
        try container.encodeIfPresent(currencyCode, forKey: .currencyCode)
        try container.encodeIfPresent(manualProgress, forKey: .manualProgress)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(focusedAt, forKey: .focusedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(planningLink, forKey: .planningLink)
        try container.encodeIfPresent(realizedAssetReference, forKey: .realizedAssetReference)
    }

    var progress: Double? {
        manualProgress.map { min(1, max(0, $0)) }
    }

    var coverAssetName: String {
        coverAssetReference ?? archetype.builtInCoverAssetName
    }

    var isFocused: Bool {
        status == .active && focusedAt != nil
    }

    var isActive: Bool {
        status == .active
    }

    mutating func updateProgress(_ progress: Double) {
        manualProgress = min(1, max(0, progress))
    }
}

struct WishPlanningDraft: Codable, Equatable {
    var schemaVersion: Int
    var sourceWishID: UUID
    var title: String
    var archetype: WishArchetype
    var targetAmount: Decimal?
    var currencyCode: CurrencyCode?
    var desiredDate: Date?
    var coverAssetReference: String?
}

protocol WishPlanningExporting {
    var isAvailable: Bool { get }
    func prepareExport(for wish: WishExperience) async throws -> WishPlanningDraft
}

struct DisabledWishPlanningExporter: WishPlanningExporting {
    let isAvailable = false

    func prepareExport(for wish: WishExperience) async throws -> WishPlanningDraft {
        WishPlanningDraft(
            schemaVersion: 1,
            sourceWishID: wish.id,
            title: wish.title,
            archetype: wish.archetype,
            targetAmount: wish.targetAmount,
            currencyCode: wish.currencyCode,
            desiredDate: nil,
            coverAssetReference: wish.coverAssetReference
        )
    }
}

struct LegacyPersonalGoal: Codable, Equatable {
    var title: String
    var targetAmount: Double
    var startedAt: Date
}

struct LegacySalaryWish: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var targetAmount: Double
    let createdAt: Date
    var isCompleted: Bool
}
