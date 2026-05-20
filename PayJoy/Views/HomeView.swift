import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var amountPulse = false
    @State private var lastEarnedCents = 0
    @State private var heroBubbleText = HomeView.randomBubbleText()

    var body: some View {
        ZStack {
            if appState.snapshot.status == .working,
               appState.preferences.showCoinRain,
               !appState.preferences.reduceMotion {
                CoinRainLayer()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    hero
                        .padding(.bottom, -8)
                    EarningsCard(
                        snapshot: appState.snapshot,
                        pulse: amountPulse,
                        showDecimalCents: appState.preferences.showDecimalCents
                    )
                    if appState.canEnableOvertimeToday {
                        OvertimePromptCard {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                                appState.enableOvertimeToday()
                            }
                        }
                    }
                    ProgressSummaryCard(snapshot: appState.snapshot)
                    HStack(spacing: 10) {
                        SmallMetricCard(title: "下班倒计时", value: appState.snapshot.secondsUntilOffWork.countdownText, caption: appState.settings.workEnd.displayText)
                        SmallMetricCard(title: "今天还可赚", value: appState.snapshot.remainingToday.compactMoneyText, caption: "继续回血")
                    }
                    MoyuCard(snapshot: appState.snapshot)
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 10)
            }
        }
        .background(AppTheme.paper)
        .navigationBarHidden(true)
        .onAppear {
            heroBubbleText = Self.randomBubbleText(excluding: heroBubbleText)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            heroBubbleText = Self.randomBubbleText(excluding: heroBubbleText)
        }
        .onChange(of: appState.snapshot.todayEarned) { _, newValue in
            let cents = Int(newValue * 100)
            guard cents != lastEarnedCents else { return }
            lastEarnedCents = cents
            withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
                amountPulse.toggle()
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            AssetImage(name: "home_header_lettering_spaced_v2")
                .frame(width: 258, height: 186)
                .offset(x: -2, y: 0)
                .accessibilityLabel(Text("开薪！打工赚钱的每一秒，都是热爱生活的证据！"))

            AssetImage(name: "coin_single_v1")
                .frame(width: 34, height: 34)
                .rotationEffect(.degrees(22))
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.trailing, 48)
                .offset(y: 22)

            AssetImage(name: "coin_single_v1")
                .frame(width: 26, height: 26)
                .rotationEffect(.degrees(-24))
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.trailing, 118)
                .offset(y: 102)

            NavigationLink {
                SalarySettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.coin)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1.4))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .topTrailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 146)
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            AssetImage(name: "worker_at_desk_v1")
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .offset(y: -2)
            SpeechBubble(text: heroBubbleText, isYellow: false, tailX: 0.24)
                .frame(width: 144)
                .offset(x: -6, y: -6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 118)
    }

    private static func randomBubbleText(excluding current: String? = nil) -> String {
        let messages = [
            "每一秒都在回血。",
            "工资正在努力加载。",
            "摸鱼也有现金流。",
            "今天又多赚一点点。",
            "老板看不见，金币看得见。",
            "打工人钱包复活中。",
            "先别崩，钱在涨。",
            "只要数字在跳，我就还能撑。",
            "键盘一响，金币到账。",
            "开薪中，请保持微笑。"
        ]
        let candidates = messages.filter { $0 != current }
        return candidates.randomElement() ?? messages[0]
    }
}

private struct OvertimePromptCard: View {
    let action: () -> Void

    var body: some View {
        ComicCard(background: Color(hex: 0xFFF1A8), padding: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.coin)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1.2))

                VStack(alignment: .leading, spacing: 3) {
                    Text("今天是休息日")
                        .font(.subheadline.weight(.heavy))
                    Text("临时加班？点一下，今天按工作时间计薪。")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                }

                Spacer(minLength: 4)

                Button(action: action) {
                    Text("加班计薪")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(AppTheme.coin)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.ink, lineWidth: 1.1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct EarningsCard: View {
    let snapshot: EarningsSnapshot
    let pulse: Bool
    let showDecimalCents: Bool

    var body: some View {
        ComicCard(background: AppTheme.cream.opacity(0.62), radius: 20) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text("今日已赚")
                        .font(.headline.weight(.heavy))
                    Text(amountText)
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.64)
                        .lineLimit(1)
                        .scaleEffect(pulse ? 1.045 : 1)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pulse)
                    Text("≈ ¥\(String(format: "%.4f", snapshot.earnedPerSecond)) / 秒")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                    Text(snapshot.status.title)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.coin.opacity(0.7))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.ink, lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var amountText: String {
        showDecimalCents ? snapshot.todayEarned.moneyText : snapshot.todayEarned.compactMoneyText
    }
}

private struct CoinRainLayer: View {
    private let coins: [FallingCoin] = [
        FallingCoin(x: 0.08, phase: 0.1, duration: 4.2, size: 24, asset: "coin_rain_left_v1"),
        FallingCoin(x: 0.18, phase: 1.7, duration: 5.1, size: 18, asset: "coin_single_v1"),
        FallingCoin(x: 0.27, phase: 3.0, duration: 4.7, size: 30, asset: "coin_rain_side_v1"),
        FallingCoin(x: 0.36, phase: 0.9, duration: 5.6, size: 16, asset: "coin_rain_right_v1"),
        FallingCoin(x: 0.45, phase: 2.2, duration: 4.4, size: 22, asset: "coin_single_v1"),
        FallingCoin(x: 0.55, phase: 3.8, duration: 5.3, size: 19, asset: "coin_rain_left_v1"),
        FallingCoin(x: 0.64, phase: 1.2, duration: 4.8, size: 32, asset: "coin_rain_right_v1"),
        FallingCoin(x: 0.73, phase: 2.8, duration: 5.7, size: 17, asset: "coin_rain_side_v1"),
        FallingCoin(x: 0.83, phase: 0.4, duration: 4.6, size: 26, asset: "coin_single_v1"),
        FallingCoin(x: 0.93, phase: 3.4, duration: 5.4, size: 20, asset: "coin_rain_left_v1"),
        FallingCoin(x: 0.14, phase: 4.0, duration: 6.0, size: 15, asset: "decor_sparkle_v1"),
        FallingCoin(x: 0.50, phase: 4.5, duration: 5.8, size: 14, asset: "decor_sparkle_v1"),
        FallingCoin(x: 0.88, phase: 5.2, duration: 6.2, size: 15, asset: "decor_sparkle_v1")
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            GeometryReader { proxy in
                ZStack {
                    ForEach(coins) { coin in
                        let progress = coin.progress(at: timeline.date)
                        let x = proxy.size.width * coin.x
                        let y = -70 + progress * (proxy.size.height + 160)

                        AssetImage(name: coin.asset)
                            .frame(width: coin.size, height: coin.size)
                            .rotationEffect(.degrees(progress * 760 + coin.phase * 90))
                            .position(x: x, y: y)
                            .opacity(coin.opacity(at: progress))
                            .scaleEffect(0.86 + progress * 0.22)
                    }
                }
                .clipped()
            }
        }
    }
}

private struct FallingCoin: Identifiable {
    let id = UUID()
    let x: CGFloat
    let phase: Double
    let duration: Double
    let size: CGFloat
    let asset: String

    func progress(at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate + phase
        return elapsed.truncatingRemainder(dividingBy: duration) / duration
    }

    func opacity(at progress: Double) -> Double {
        if progress < 0.08 {
            return progress / 0.08
        }
        if progress > 0.88 {
            return max(0, (1 - progress) / 0.12)
        }
        return 0.9
    }
}

private struct ProgressSummaryCard: View {
    let snapshot: EarningsSnapshot

    var body: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日进度")
                            .font(.headline.weight(.heavy))
                        Text("\(snapshot.progress * 100, specifier: "%.1f")%")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                    }
                    Spacer()
                    AssetImage(name: "decor_sun_progress_v1")
                        .frame(width: 42, height: 42)
                }
                ComicProgressBar(progress: snapshot.progress)
                HStack {
                    Text("目标")
                    Spacer()
                    Text(snapshot.todayTotal.moneyText)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            }
        }
    }
}

private struct SmallMetricCard: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        ComicCard(padding: 12) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.heavy))
                Text(value)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text(caption)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MoyuCard: View {
    let snapshot: EarningsSnapshot

    private var paidMoyu: Double {
        snapshot.earnedPerSecond * 10 * 60
    }

    var body: some View {
        ComicCard {
            HStack(alignment: .center, spacing: 8) {
                SpeechBubble(text: "摸鱼 10 分钟，公司为你的快乐支付了 \(paidMoyu.moneyText)", isYellow: false)
                Spacer(minLength: 0)
                AssetImage(name: "moyu_chair_worker_redraw_v1")
                    .frame(width: 116, height: 96)
            }
        }
    }
}
