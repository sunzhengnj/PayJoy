import ActivityKit
import Foundation

struct PayJoyActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var earned: Double
        var total: Double
        var perSecond: Double
        var progress: Double
        var statusTitle: String
        var endDate: Date
        var remainingText: String
        var countdownTitle: String?
        var isOffDuty: Bool?
        var hidesSensitiveAmounts: Bool
        var currencySymbol: String
        var visualTheme: AppVisualTheme
        var goalTitle: String?
        var goalProgress: Double?
        var goalRemainingText: String?
        var goalCompletionText: String?
    }

    var title: String
}
