import SwiftUI

struct DailyPayReportCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let snapshot: EarningsSnapshot
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String

    var body: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
            if dynamicTypeSize.isAccessibilitySize {
                reportCopy
            } else {
                HStack(spacing: 12) {
                    reportCopy

                    AssetImage(name: AppTheme.statsTargetWorkerAsset)
                        .frame(width: 104, height: 82)
                        .scaleEffect(AppTheme.cardArtworkScale, anchor: .bottomTrailing)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var reportCopy: some View {
        VStack(alignment: .leading, spacing: 7) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(AppTheme.coin)
                        .accessibilityHidden(true)
                    Text(L10n.t("今日收工"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                }
            } else {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(AppTheme.coin)
                        .accessibilityHidden(true)
                    Text(L10n.t("今日收工"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                }
            }

            Text(L10n.t("今天已完成计薪，打工人安全下线。"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    earnedAmount
                    earnedLabel
                }
                VStack(alignment: .leading, spacing: 7) {
                    earnedAmount
                    earnedLabel
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var earnedAmount: some View {
        Text(PrivacyText.money(snapshot.todayEarned, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.ink)
            .minimumScaleFactor(0.68)
            .lineLimit(1)
    }

    private var earnedLabel: some View {
        Text(L10n.t("今日已赚"))
            .font(.caption2.weight(.black))
            .foregroundStyle(AppTheme.textGray)
    }
}
