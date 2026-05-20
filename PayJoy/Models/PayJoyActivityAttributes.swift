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
    }

    var title: String
}
