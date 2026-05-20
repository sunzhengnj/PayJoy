import SwiftUI

struct StatsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPeriod: StatsPeriod = .month

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                statsHeader
                summaryCard
                detailsCard
                exchangeCard
                targetCard
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 86)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var period: PeriodEarnings {
        appState.periodEarnings(for: selectedPeriod)
    }

    private var breakdown: PeriodBreakdown {
        appState.periodBreakdown(for: selectedPeriod)
    }

    private var shareText: String {
        "我在开薪已经赚到 \(period.earned.moneyText)，\(selectedPeriod.title)进度 \(String(format: "%.1f", period.progress * 100))%。打工赚钱的每一秒，都是热爱生活的证据！"
    }

    private var dailySalary: Double {
        SalaryCalculator().dailySalary(for: appState.settings)
    }

    private var workHours: Double {
        SalaryCalculator().workingSecondsPerDay(settings: appState.settings) / 3_600
    }

    private var statsHeader: some View {
        VStack(spacing: 12) {
            Text("统计")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .overlay(alignment: .trailing) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.coin)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1.4))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 7)
                }

            ZStack(alignment: .topTrailing) {
                periodPicker

                AssetImage(name: "pro_sunglasses_worker_redraw_v1")
                    .frame(width: 74, height: 54)
                    .offset(x: -32, y: -49)
                    .zIndex(2)
            }
        }
        .padding(.bottom, 8)
    }

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(StatsPeriod.allCases) { period in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedPeriod == period ? AppTheme.coin : AppTheme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.ink, lineWidth: 1.4)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summaryCard: some View {
        ComicCard(radius: 20) {
            ZStack {
                if selectedPeriod == .month {
                    StatsCardCoinRain()
                        .allowsHitTesting(false)
                        .zIndex(0)
                }

                AssetImage(name: "coin_single_v1")
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: 100, y: 0)
                    .opacity(0.9)
                    .zIndex(1)

                AssetImage(name: "stats_coin_worker_redraw_v1")
                    .frame(width: 128, height: 112)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .offset(x: 0, y: 6)
                    .zIndex(2)

                VStack(spacing: 8) {
                    Text("\(selectedPeriod.title)已赚")
                        .font(.headline.weight(.heavy))
                    Text(period.earned.moneyText)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    Spacer().frame(height: 44)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedPeriod.title)预计收入")
                                .font(.caption.weight(.bold))
                            Text(period.projected.moneyText)
                                .font(.headline.weight(.black))
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedPeriod.title)进度")
                                .font(.caption.weight(.bold))
                            Text("\(period.progress * 100, specifier: "%.1f")%")
                                .font(.headline.weight(.black))
                        }
                    }
                    ComicProgressBar(progress: period.progress)
                }
                .zIndex(10)
            }
        }
        .padding(.top, 2)
    }

    private var exchangeCard: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("换算一下，你已经赚到：")
                    .font(.headline.weight(.heavy))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ExchangeItem(image: "exchange_milk_tea_v1", title: "奶茶", amount: period.earned / 19)
                    ExchangeItem(image: "exchange_coffee_v1", title: "咖啡", amount: period.earned / 32)
                    ExchangeItem(image: "exchange_hotpot_v1", title: "火锅", amount: period.earned / 150)
                    ExchangeItem(image: "exchange_iphone_v1", title: "iPhone", amount: period.earned / 5999)
                }
            }
        }
    }

    private var detailsCard: some View {
        ComicCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("计算明细")
                    .font(.headline.weight(.heavy))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    StatsMetric(title: "预计日薪", value: dailySalary.moneyText)
                    StatsMetric(title: "等效时薪", value: workHours > 0 ? (dailySalary / workHours).compactMoneyText : "¥0")
                    StatsMetric(title: "当前状态", value: appState.snapshot.status.title)
                    StatsMetric(title: "还差目标", value: max(0, period.projected - period.earned).compactMoneyText)
                }
                Divider().overlay(AppTheme.divider)
                HStack(spacing: 10) {
                    WorkdayPill(title: "已完成", value: "\(String(format: "%.1f", breakdown.completedWorkdayEquivalent)) 天")
                    WorkdayPill(title: "总工作日", value: "\(breakdown.totalWorkdays) 天")
                    WorkdayPill(title: "剩余", value: "\(breakdown.remainingWorkdays) 天")
                }
                ComicProgressBar(progress: breakdown.workdayProgress)
            }
        }
    }

    private var targetCard: some View {
        ZStack(alignment: .bottomTrailing) {
            ComicCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("距离\(selectedPeriod.title)目标还差")
                            .font(.headline.weight(.heavy))
                        Text(max(0, period.projected - period.earned).moneyText)
                            .font(.title2.weight(.black))
                        Text(targetCaption)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    Color.clear.frame(width: 120, height: 74)
                }
                .frame(minHeight: 92)
            }

            SpeechBubble(text: targetBubbleText, isYellow: false, tailX: 0.52)
                .frame(width: 142)
                .offset(x: -10, y: -86)
                .zIndex(4)

            AssetImage(name: "stats_coin_worker_redraw_v1")
                .frame(width: 126, height: 112)
                .offset(x: 8, y: 26)
                .zIndex(3)

            AssetImage(name: "coin_pile_v1")
                .frame(width: 94, height: 58)
                .offset(x: -98, y: -7)
                .zIndex(2)
        }
        .padding(.top, 20)
        .padding(.bottom, 36)
    }

    private var targetCaption: String {
        switch selectedPeriod {
        case .today:
            "稳住节奏，下班前还有机会回血。"
        case .month:
            "再撑一撑，月末一定能暴富一点点。"
        case .year:
            "把每天的小金币攒成今年的大进度。"
        }
    }

    private var targetBubbleText: String {
        switch selectedPeriod {
        case .today:
            "离下班更近，也离到账更近！"
        case .month:
            "再撑两周，月末一线暴富！"
        case .year:
            "今年的金币，也在偷偷变多！"
        }
    }
}

private struct StatsCardCoinRain: View {
    @State private var fall = false

    private let coins: [(x: CGFloat, delay: Double, speed: Double, size: CGFloat, rotation: Double)] = [
        (0.16, 0.0, 2.7, 28, -18),
        (0.38, 0.4, 2.9, 22, 12),
        (0.62, 0.2, 2.5, 24, 26),
        (0.78, 0.8, 2.8, 30, -8),
        (0.48, 1.1, 2.6, 18, 32),
        (0.88, 1.4, 3.0, 20, -24)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(coins.indices, id: \.self) { index in
                let coin = coins[index]
                AssetImage(name: "coin_single_v1")
                    .frame(width: coin.size, height: coin.size)
                    .rotationEffect(.degrees(fall ? coin.rotation + 360 : coin.rotation))
                    .position(
                        x: proxy.size.width * coin.x,
                        y: fall ? proxy.size.height + 32 : -32
                    )
                    .animation(
                        .linear(duration: coin.speed)
                            .delay(coin.delay)
                            .repeatForever(autoreverses: false),
                        value: fall
                    )
            }
        }
        .clipped()
        .onAppear {
            fall = true
        }
    }
}

private struct StatsMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.subheadline.weight(.black))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.paper.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.85), lineWidth: 1)
        }
    }
}

private struct WorkdayPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.caption.weight(.black))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExchangeItem: View {
    let image: String
    let title: String
    let amount: Double

    var body: some View {
        VStack(spacing: 5) {
            AssetImage(name: image)
                .frame(width: 38, height: 38)
            Text(title)
                .font(.caption2.weight(.bold))
            Text("\(amount, specifier: "%.1f")")
                .font(.caption.weight(.black))
        }
        .frame(maxWidth: .infinity)
    }
}
