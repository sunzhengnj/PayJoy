import SwiftUI

struct PersonalGoalCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.payJoyReduceMotion) private var appReduceMotion
    let goal: WishExperience?
    let progress: PersonalGoalProgress?
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String
    let editGoalAction: () -> Void
    let celebrateGoalAction: (() -> Void)?

    var body: some View {
        ComicCard(background: AppTheme.cream, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("开薪目标"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.t("让每一笔工资，都有想去的地方。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.78)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "target")
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.coin)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.1))
                        .accessibilityHidden(true)
                }

                goalSection
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        goalLabel
                        Spacer(minLength: 4)
                        editGoalButton
                    }
                    goalTitle
                }
            } else {
                HStack(spacing: 8) {
                    goalLabel
                    goalTitle
                    Spacer(minLength: 4)
                    editGoalButton
                }
            }

            if let goal, let progress {
                Text(PrivacyText.money(progress.earnedAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol) + " / " + PrivacyText.money(NSDecimalNumber(decimal: goal.targetAmount ?? 0).doubleValue, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.textGray)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    ComicProgressBar(progress: progress.progress)
                    Text("\(progress.progress * 100, specifier: "%.0f")%")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .monospacedDigit()
                }

                if progress.progress >= 1, let celebrateGoalAction {
                    Button(action: celebrateGoalAction) {
                        Label(L10n.t("庆祝一下"), systemImage: "party.popper.fill")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(AppTheme.coin)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("打开目标达成庆祝卡"))
                } else {
                    Text(L10n.format("还差 %@，预计还要上 %@ 天。", PrivacyText.compactMoney(progress.remainingAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol), "\(progress.estimatedWorkdaysRemaining)"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(L10n.t("把想买的东西或想去的地方写下来。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(AppTheme.highlightCardBackground.opacity(0.56))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.58), lineWidth: 1)
        }
    }

    private var goalLabel: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(AppTheme.orange)
                .frame(width: 5, height: 20)
                .accessibilityHidden(true)
            Text(L10n.t("主目标"))
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.textGray)
        }
    }

    private var goalTitle: some View {
        Text(goal?.title ?? L10n.t("未设置"))
            .font(.subheadline.weight(.black))
            .foregroundStyle(AppTheme.ink)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var editGoalButton: some View {
        Button(action: editGoalAction) {
            Text(L10n.t(goal == nil ? "设置" : "编辑"))
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(AppTheme.coin)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: appReduceMotion || accessibilityReduceMotion))
        .accessibilityLabel(L10n.t(goal == nil ? "设置一个目标" : "编辑开薪目标"))
    }

}

struct GoalCelebrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let goal: WishExperience
    let progress: PersonalGoalProgress
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String
    let reducesMotion: Bool
    @State private var isBurstVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.paper.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        GoalCelebrationBurst(
                            isVisible: isBurstVisible,
                            reducesMotion: reducesMotion
                        )
                            .frame(height: 198)
                            .accessibilityHidden(true)

                        ComicCard(background: AppTheme.highlightCardBackground, padding: 18) {
                            VStack(spacing: 13) {
                                Text(L10n.t("目标达成！"))
                                    .font(.system(size: 29, weight: .black, design: .rounded))
                                    .foregroundStyle(AppTheme.ink)

                                Text(goal.title)
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(AppTheme.ink)
                                    .multilineTextAlignment(.center)

                                Text(L10n.t("这一刻，工资终于有了名字。"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.textGray)
                                    .multilineTextAlignment(.center)

                                Text(L10n.format("你完成了 %@ 目标。", goal.title))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.textGray)
                                    .multilineTextAlignment(.center)

                                VStack(spacing: 5) {
                                    Text(L10n.t("已累计"))
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(AppTheme.textGray)
                                    Text(PrivacyText.money(progress.earnedAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                                        .font(.system(size: 38, weight: .black, design: .rounded))
                                        .foregroundStyle(AppTheme.ink)
                                        .minimumScaleFactor(0.65)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .stroke(AppTheme.outline, lineWidth: 1.2)
                                }
                            }
                        }

                        Button(L10n.t("完成庆祝")) {
                            dismiss()
                        }
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.coin)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.2)
                            }
                        .buttonStyle(.plain)
                    }
                    .padding(AppTheme.pagePadding)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(L10n.t("目标达成"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("关闭")) {
                        dismiss()
                    }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                }
            }
            .onAppear {
                withAnimation(prefersReducedMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72)) {
                    isBurstVisible = true
                }
            }
        }
        .environment(\.locale, Locale(identifier: L10n.currentLanguage.localeIdentifier))
    }

    private var prefersReducedMotion: Bool {
        reducesMotion || accessibilityReduceMotion
    }
}

private struct GoalCelebrationBurst: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let isVisible: Bool
    let reducesMotion: Bool

    private let pieces: [(x: CGFloat, y: CGFloat, rotation: Double, color: Color)] = [
        (-86, -56, -18, AppTheme.coin),
        (-62, -91, 24, AppTheme.highlightCardBackground),
        (-24, -105, -12, AppTheme.coin),
        (25, -97, 18, AppTheme.highlightCardBackground),
        (66, -69, -26, AppTheme.coin),
        (92, -20, 16, AppTheme.highlightCardBackground),
        (80, 35, -18, AppTheme.coin),
        (46, 72, 25, AppTheme.highlightCardBackground),
        (-46, 73, -22, AppTheme.coin),
        (-83, 32, 15, AppTheme.highlightCardBackground),
        (-98, -18, -15, AppTheme.coin)
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.coin.opacity(0.28))
                .frame(width: 172, height: 172)
                .scaleEffect(isVisible ? 1 : 0.72)

            AssetImage(name: AppTheme.personalGoalWorkerAsset)
                .frame(width: 144, height: 128)
                .scaleEffect(AppTheme.cardArtworkScale * (isVisible ? 1 : 0.78), anchor: .bottom)

            Image(systemName: "sparkles")
                .font(.system(size: 25, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .offset(x: 67, y: -72)
                .scaleEffect(isVisible ? 1 : 0.2)

            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(piece.color)
                    .frame(width: 9, height: 18)
                    .rotationEffect(.degrees(piece.rotation))
                    .offset(x: isVisible ? piece.x : 0, y: isVisible ? piece.y : 0)
                    .opacity(isVisible ? 1 : 0)
            }
        }
        .animation(prefersReducedMotion ? nil : .spring(response: 0.62, dampingFraction: 0.72), value: isVisible)
    }

    private var prefersReducedMotion: Bool {
        reducesMotion || accessibilityReduceMotion
    }
}
