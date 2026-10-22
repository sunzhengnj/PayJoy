import SwiftUI
import UIKit

private struct PayJoyReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PayJoyAmbientMotionKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var payJoyAmbientMotionEnabled: Bool {
        get { self[PayJoyAmbientMotionKey.self] }
        set { self[PayJoyAmbientMotionKey.self] = newValue }
    }

    var payJoyReduceMotion: Bool {
        get { self[PayJoyReduceMotionKey.self] }
        set { self[PayJoyReduceMotionKey.self] = newValue }
    }
}

struct AdaptiveTwoColumn<Primary: View, Secondary: View>: View {
    let primary: Primary
    let secondary: Secondary

    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
#if PAYJOY_DUO_SDK
        if #available(iOS 27.1, *) {
            ArrangementView {
                primary.padding(.trailing, 12)
            } secondary: {
                secondary.padding(.leading, 12)
            }
            .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            fallback
        }
#else
        fallback
#endif
    }

    private var fallback: some View {
        HStack(alignment: .top, spacing: 24) {
            primary.frame(maxWidth: .infinity)
            secondary.frame(maxWidth: .infinity)
        }
    }
}

struct AdaptiveScrollPosition {
    var primary: String?
    var secondary: String?
    var compact: String?
    var lastWidePaneWasSecondary = false

    mutating func transition(
        toExpanded expanded: Bool,
        isSecondary: (String) -> Bool,
        expandedOnlyAnchors: Set<String> = []
    ) {
        if expanded {
            guard let compact else { return }
            lastWidePaneWasSecondary = isSecondary(compact)
            if lastWidePaneWasSecondary {
                secondary = compact
            } else {
                primary = compact
            }
        } else {
            let preferred = lastWidePaneWasSecondary ? secondary : primary
            compact = [preferred, primary, secondary].compactMap { $0 }
                .first { !expandedOnlyAnchors.contains($0) }
        }
    }
}

struct ComicCard<Content: View>: View {
    var background: Color = AppTheme.cream
    var radius: CGFloat = AppTheme.cardRadius
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 1.6)
            }
            .shadow(color: AppTheme.shadow.opacity(0.14), radius: 1, x: 3, y: 3)
    }
}

struct ComicProgressBar: View {
    @Environment(\.payJoyReduceMotion) private var reduceMotion
    @Environment(\.payJoyAmbientMotionEnabled) private var ambientMotionEnabled
    @Environment(\.scenePhase) private var scenePhase
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.softSurface.opacity(0.72))
                Capsule()
                    .fill(AppTheme.coin)
                    .frame(width: max(12, proxy.size.width * CGFloat(min(1, max(0, progress)))))
                    .animation(reduceMotion || !ambientMotionEnabled || scenePhase != .active ? nil : .easeOut(duration: 0.3), value: progress)
            }
            .overlay {
                Capsule().stroke(AppTheme.outline, lineWidth: 1.4)
            }
        }
        .frame(height: 13)
    }
}

struct ComicIdleBob: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.payJoyAmbientMotionEnabled) private var ambientMotionEnabled
    var enabled: Bool
    var amplitude: CGFloat = 3.5
    var rotation: Double = 1.2
    var duration: Double = 2.5
    @State private var lifted = false

    private var isActive: Bool { enabled && ambientMotionEnabled && scenePhase == .active }

    func body(content: Content) -> some View {
        content
            .offset(y: lifted ? -amplitude : 0)
            .rotationEffect(.degrees(lifted ? rotation : 0))
            .onAppear(perform: startIfNeeded)
            .onDisappear(perform: stop)
            .onChange(of: isActive) { _, isEnabled in
                if isEnabled {
                    startIfNeeded()
                } else {
                    stop()
                }
            }
    }

    private func startIfNeeded() {
        guard isActive, !lifted else { return }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            lifted = true
        }
    }

    private func stop() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { lifted = false }
    }
}

struct ComicTwinkleField: View {
    var enabled: Bool

    private let sparks: [(x: CGFloat, y: CGFloat, size: CGFloat, speed: Double, phase: Double)] = [
        (0.10, 0.16, 12, 2.1, 0.2),
        (0.74, 0.10, 10, 1.7, 1.1),
        (0.90, 0.38, 14, 2.4, 1.8),
        (0.16, 0.58, 9, 1.9, 0.6),
        (0.58, 0.07, 11, 2.2, 1.4)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: !enabled)) { timeline in
            GeometryReader { proxy in
                ForEach(sparks.indices, id: \.self) { index in
                    let spark = sparks[index]
                    let wave = enabled
                        ? 0.5 + 0.5 * sin(timeline.date.timeIntervalSinceReferenceDate * spark.speed + spark.phase)
                        : 0
                    AssetImage(name: "decor_sparkle_v1")
                        .frame(width: spark.size, height: spark.size)
                        .opacity(enabled ? 0.28 + 0.72 * wave : 0)
                        .scaleEffect(0.72 + wave * 0.45)
                        .position(x: proxy.size.width * spark.x, y: proxy.size.height * spark.y)
                        .accessibilityHidden(true)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Keep the scroll container and its state in place while the available pane changes.
    func adaptiveSinglePane(in layout: AdaptiveLayoutContext) -> some View {
        let bounds = layout.singleColumnBounds
        // Let system scroll edges reach the screen, but never extend across a fold or camera clearance.
        let topOverflow = bounds.minY <= 0 ? layout.safeAreaInsets.top : 0
        let bottomOverflow = bounds.maxY >= layout.size.height ? layout.safeAreaInsets.bottom : 0
        return frame(width: bounds.width, height: bounds.height)
            .clipShape(Rectangle()
                .size(width: bounds.width, height: bounds.height + topOverflow + bottomOverflow)
                .offset(y: -topOverflow))
            .position(x: bounds.midX, y: bounds.midY)
    }

    func adaptiveSinglePane() -> some View {
        GeometryReader { proxy in
            adaptiveSinglePane(in: AdaptiveLayoutContext(proxy: proxy))
        }
    }

    func comicIdleBob(
        enabled: Bool,
        amplitude: CGFloat = 3.5,
        rotation: Double = 1.2,
        duration: Double = 2.5
    ) -> some View {
        modifier(ComicIdleBob(enabled: enabled, amplitude: amplitude, rotation: rotation, duration: duration))
    }
}

struct PrimaryButton: View {
    let title: String
    var reduceMotion = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.vertical, 2)
                .background(AppTheme.coin)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1.5)
                }
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: reduceMotion))
    }
}

struct PayJoyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.payJoyReduceMotion) private var appReduceMotion

    var scale: CGFloat = 0.985
    var reduceMotion = false

    func makeBody(configuration: Configuration) -> some View {
        let shouldReduceMotion = accessibilityReduceMotion || appReduceMotion || reduceMotion
        configuration.label
            .scaleEffect(configuration.isPressed && !shouldReduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                shouldReduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}

struct AssetImage: View {
    let name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        if let image = UIImage(named: name) ?? UIImage(named: "\(name).png") {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if let url = Bundle.main.url(forResource: name, withExtension: "png"),
                  let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Color.clear
        }
    }
}

struct SpeechBubble: View {
    let text: String
    var isYellow = false
    var tailX: CGFloat = 0.22
    var lineLimit = 2

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(AppTheme.ink)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .padding(.bottom, 17)
            .background(bubbleFill)
            .clipShape(ComicBubbleShape(tailX: tailX))
            .overlay(ComicBubbleShape(tailX: tailX).stroke(AppTheme.outline, lineWidth: 1.8))
            .shadow(color: AppTheme.shadow.opacity(0.08), radius: 0, x: 2, y: 2)
    }

    private var bubbleFill: Color {
        isYellow ? AppTheme.highlightCardBackground : AppTheme.softSurface
    }
}

struct ComicBubbleShape: Shape {
    var tailX: CGFloat = 0.22
    var radius: CGFloat = 15
    var tailWidth: CGFloat = 20
    var tailHeight: CGFloat = 15

    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: max(0, rect.height - tailHeight)
        )
        let tailCenter = min(max(rect.width * tailX, radius + tailWidth / 2), rect.width - radius - tailWidth / 2)
        let tailLeft = bubbleRect.minX + tailCenter - tailWidth / 2
        let tailRight = bubbleRect.minX + tailCenter + tailWidth / 2
        let tailTip = CGPoint(x: bubbleRect.minX + tailCenter - 5, y: rect.maxY)

        var path = Path()
        path.move(to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.minY))
        path.addLine(to: CGPoint(x: bubbleRect.maxX - radius, y: bubbleRect.minY))
        path.addQuadCurve(to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY + radius), control: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY))
        path.addLine(to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: bubbleRect.maxX - radius, y: bubbleRect.maxY), control: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: tailRight, y: bubbleRect.maxY))
        path.addLine(to: tailTip)
        path.addLine(to: CGPoint(x: tailLeft, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.maxY))
        path.addQuadCurve(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY - radius), control: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.minY), control: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY))
        path.closeSubpath()
        return path
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case focus
    case stats
    case wish
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: L10n.t("首页")
        case .focus: L10n.t("专注")
        case .stats: L10n.t("统计")
        case .wish: L10n.t("愿望")
        case .profile: L10n.t("我的")
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .focus: "timer"
        case .stats: "chart.bar.fill"
        case .wish: "sparkles.rectangle.stack.fill"
        case .profile: "person.fill"
        }
    }
}

/// The available scene geometry, rather than a device name or interface orientation,
/// determines whether content can be shown beside or across the fold.
struct AdaptiveLayoutContext {
    var size: CGSize
    var safeAreaInsets: EdgeInsets
    var divisionRegions: [CGRect]
    var occlusionRegions: [CGRect]

    static let compact = AdaptiveLayoutContext(
        size: .zero,
        safeAreaInsets: EdgeInsets(),
        divisionRegions: [],
        occlusionRegions: []
    )

    init(size: CGSize, safeAreaInsets: EdgeInsets, divisionRegions: [CGRect], occlusionRegions: [CGRect]) {
        self.size = size
        self.safeAreaInsets = safeAreaInsets
        self.divisionRegions = divisionRegions
        self.occlusionRegions = occlusionRegions
    }

    init(proxy: GeometryProxy) {
        size = proxy.size
        safeAreaInsets = proxy.safeAreaInsets
#if DEBUG
        if ProcessInfo.processInfo.environment["PAYJOY_DUO_TEST_POSE"] == "tabletop" {
            divisionRegions = [CGRect(x: 0, y: size.height * 0.52, width: size.width, height: 18)]
            occlusionRegions = []
            return
        }
#endif
#if PAYJOY_DUO_SDK
        if #available(iOS 27.1, *) {
            divisionRegions = proxy.reservedRegions(kind: .division).map(\.frame)
            occlusionRegions = proxy.reservedRegions(kind: .occlusion).map(\.frame)
        } else {
            divisionRegions = []
            occlusionRegions = []
        }
#else
        divisionRegions = []
        occlusionRegions = []
#endif
    }

    var usableWidth: CGFloat {
        max(0, size.width)
    }

    var singleColumnWidth: CGFloat {
        verticalDivision.map { max(0, $0.minX - 12) } ?? usableWidth
    }

    var singleColumnBounds: CGRect {
        var bounds = CGRect(x: 0, y: 0, width: singleColumnWidth, height: size.height)
        if let division = horizontalDivision {
            let upperHeight = max(0, division.minY - 12)
            let lowerStart = min(size.height, division.maxY + 12)
            let lowerHeight = max(0, size.height - lowerStart)
            bounds = upperHeight >= lowerHeight
                ? CGRect(x: 0, y: 0, width: usableWidth, height: upperHeight)
                : CGRect(x: 0, y: lowerStart, width: usableWidth, height: lowerHeight)
        }
        // Page titles and result text can occupy the centre as well as either edge.
        let clearance = topContentClearance(in: bounds)
        return CGRect(x: bounds.minX, y: bounds.minY + min(clearance, bounds.height),
                      width: bounds.width, height: max(0, bounds.height - clearance))
    }

    func topContentClearance(in bounds: CGRect) -> CGFloat {
        let header = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: min(60, bounds.height))
        return occlusionRegions.filter { $0.intersects(header) }
            .map { max(0, $0.maxY - bounds.minY) + 8 }.max() ?? 0
    }

    var hasRoomForTwoColumns: Bool {
        guard horizontalDivision == nil else { return false }
        let minimumPaneWidth: CGFloat = 320 + AppTheme.pagePadding + 12
        if let division = verticalDivision {
            let leadingWidth = division.minX
            let trailingWidth = size.width - division.maxX
            return leadingWidth >= minimumPaneWidth && trailingWidth >= minimumPaneWidth
        }
        // A horizontal-only ArrangementView collapses its secondary view in a tall window.
        guard size.width >= size.height else { return false }
        return usableWidth >= 2 * 320 + 24 + 2 * AppTheme.pagePadding
    }

    var horizontalDivision: CGRect? {
        divisionRegions.first { $0.width > $0.height && $0.width >= size.width * 0.7 }
    }

    var verticalDivision: CGRect? {
        divisionRegions.first { $0.height > $0.width && $0.height >= size.height * 0.7 }
    }

    func topControlClearance(in bounds: CGRect) -> CGFloat {
        let edgeWidth = min(160, bounds.width / 2)
        let headerHeight = min(60, bounds.height)
        let leadingControls = CGRect(x: bounds.minX, y: bounds.minY, width: edgeWidth, height: headerHeight)
        let trailingControls = CGRect(x: bounds.maxX - edgeWidth, y: bounds.minY, width: edgeWidth, height: headerHeight)
        return occlusionRegions
            .filter { $0.intersects(leadingControls) || $0.intersects(trailingControls) }
            .map { max(0, $0.maxY - bounds.minY) + 8 }
            .max() ?? 0
    }

    var canShowDeskClock: Bool {
        guard let division = horizontalDivision else { return false }
        let clockBounds = CGRect(x: 0, y: 0, width: size.width, height: division.minY)
        return deskClockTimeFontSize(in: clockBounds) >= 44 && size.height - division.maxY >= 88
    }

    func deskClockTimeFontSize(in bounds: CGRect) -> CGFloat {
        // Reserve the 44pt header, 20pt label, 4pt gap and 8pt bottom padding.
        let timeHeight = max(0, bounds.height - topControlClearance(in: bounds) - 44 - 20 - 4 - 8)
        return max(1, min(132, max(0, bounds.width - 32) * 0.18, timeHeight / 1.25))
    }
}

private struct AdaptiveLayoutContextKey: EnvironmentKey {
    static let defaultValue = AdaptiveLayoutContext.compact
}

private struct DuoDeviceAvailableKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var adaptiveLayoutContext: AdaptiveLayoutContext {
        get { self[AdaptiveLayoutContextKey.self] }
        set { self[AdaptiveLayoutContextKey.self] = newValue }
    }

    var duoDeviceAvailable: Bool {
        get { self[DuoDeviceAvailableKey.self] }
        set { self[DuoDeviceAvailableKey.self] = newValue }
    }

    var payJoyWindowScene: UIWindowScene? {
        get { self[PayJoyWindowSceneKey.self] }
        set { self[PayJoyWindowSceneKey.self] = newValue }
    }
}

private struct PayJoyWindowSceneKey: EnvironmentKey {
    static let defaultValue: UIWindowScene? = nil
}

struct WindowSceneReader: UIViewRepresentable {
    let onSceneChange: (UIWindowScene?) -> Void
    let onHingeAvailabilityChange: (Bool) -> Void
    let onHingeFullyOpen: () -> Void

    func makeUIView(context: Context) -> SceneView {
        let view = SceneView()
        view.onSceneChange = onSceneChange
        view.onHingeAvailabilityChange = onHingeAvailabilityChange
        view.onHingeFullyOpen = onHingeFullyOpen
#if PAYJOY_DUO_SDK
        if #available(iOS 27.1, *) {
            view.addInteraction(UIHingeInteraction { [weak view] _, update in
                let hasHinge = update.hinge != nil
                let isFullyOpen = update.hinge?.status == .fullyOpen
                DispatchQueue.main.async { [weak view] in
                    view?.onHingeAvailabilityChange?(hasHinge)
                    if isFullyOpen { view?.onHingeFullyOpen?() }
                }
            })
        }
#endif
        return view
    }

    func updateUIView(_ view: SceneView, context: Context) {
        view.onSceneChange = onSceneChange
        view.onHingeAvailabilityChange = onHingeAvailabilityChange
        view.onHingeFullyOpen = onHingeFullyOpen
    }

    final class SceneView: UIView {
        var onSceneChange: ((UIWindowScene?) -> Void)?
        var onHingeAvailabilityChange: ((Bool) -> Void)?
        var onHingeFullyOpen: (() -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            let scene = window?.windowScene
            DispatchQueue.main.async { [weak self] in
                self?.onSceneChange?(scene)
            }
        }
    }
}

struct TabChromeOccupancy: Equatable {
    var contentBottomInset: CGFloat
    var barBottomOffset: CGFloat

    static let hidden = TabChromeOccupancy(contentBottomInset: 0, barBottomOffset: 0)

    /// Convert physical-bottom occupancy into padding for a container that already
    /// respects the bottom safe area. Subtracting that inset avoids double-counting
    /// the home indicator; values are never negative.
    func paddingInSafeAreaRespectingContainer(bottomSafeArea: CGFloat) -> TabChromeOccupancy {
        let safeArea = max(0, bottomSafeArea)
        return TabChromeOccupancy(
            contentBottomInset: max(0, contentBottomInset - safeArea),
            barBottomOffset: max(0, barBottomOffset - safeArea)
        )
    }
}

enum TabChromeLayout {
    static let defaultBarHeight: CGFloat = 66
    static let minimumLift: CGFloat = 8

    /// Occupancy from the physical bottom of an edge-to-edge container.
    /// `bottomSafeArea` must come from a reader that still sees the home-indicator
    /// edge — not from a `GeometryReader` that has ignored `.bottom` (that reports 0).
    static func occupancy(
        barVisible: Bool,
        bottomSafeArea: CGFloat,
        barHeight: CGFloat = defaultBarHeight
    ) -> TabChromeOccupancy {
        guard barVisible else { return .hidden }
        let safeArea = max(0, bottomSafeArea)
        let barBottomOffset = max(minimumLift, safeArea)
        return TabChromeOccupancy(
            contentBottomInset: barHeight + barBottomOffset,
            barBottomOffset: barBottomOffset
        )
    }
}

struct ComicTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.payJoyReduceMotion) private var appReduceMotion
    @Binding var selectedTab: AppTab

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
                .shadow(color: AppTheme.shadow.opacity(0.14), radius: 0, x: 0, y: 2)
                .offset(y: 3)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.tabBarBackground)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(AppTheme.softSurface.opacity(0.78))
                        .frame(height: 3)
                        .padding(.horizontal, 34)
                        .padding(.top, 6)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 2.1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.outline.opacity(0.18), lineWidth: 1)
                        .padding(5)
                }

            HStack(spacing: 7) {
                ForEach(AppTab.allCases) { tab in
                    ComicTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(prefersReducedMotion ? nil : .spring(response: 0.30, dampingFraction: 0.70)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(7)
        }
        .frame(height: TabChromeLayout.defaultBarHeight)
        .padding(.horizontal, 18)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private var prefersReducedMotion: Bool {
        accessibilityReduceMotion || appReduceMotion
    }
}

struct LiveActivityControlCard: View {
    let isAvailable: Bool
    let isActive: Bool
    let statusTitle: String
    var statusMessage: String? = nil
    let errorMessage: String?
    let action: () -> Void

    var body: some View {
        ComicCard(background: AppTheme.cream.opacity(0.78), padding: 12) {
            HStack(spacing: 10) {
                Image(systemName: isActive ? "sparkles.rectangle.stack.fill" : "rectangle.inset.filled.and.person.filled")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(isAvailable ? AppTheme.coin : AppTheme.divider)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("锁屏 / 灵动岛"))
                        .font(.subheadline.weight(.heavy))
                    Text(statusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(errorMessage == nil ? AppTheme.textGray : AppTheme.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button(action: action) {
                    Text(isActive ? L10n.t("结束") : L10n.t("开启"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 44)
                        .background(isAvailable ? AppTheme.coin : AppTheme.divider)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.96))
                .disabled(!isAvailable)
                .opacity(isAvailable ? 1 : 0.55)
            }
        }
    }

    private var statusText: String {
        if let errorMessage {
            return errorMessage
        }
        if let statusMessage {
            return statusMessage
        }
        return isAvailable ? L10n.t("%@，可在系统实时活动中展示。", statusTitle) : L10n.t("当前系统未开放实时活动。")
    }
}

extension View {
    func payJoyKeyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.t("完成")) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.body.weight(.heavy))
            }
        }
    }

    func membershipFeatureAlert(
        isPresented: Binding<Bool>,
        onContinue: @escaping () -> Void
    ) -> some View {
        alert(L10n.t("这是会员功能"), isPresented: isPresented) {
            Button(L10n.t("取消"), role: .cancel) {}
            Button(L10n.t("前往开通"), action: onContinue)
        } message: {
            Text(L10n.t("开通会员后即可使用，是否前往会员开通页？"))
        }
    }
}

private struct ComicTabButton: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.payJoyReduceMotion) private var appReduceMotion
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.ink)
                        .offset(x: 2.5, y: 3.5)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accentGradientStart, AppTheme.coin],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 2)
                }

                VStack(spacing: 4) {
                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 24 : 22, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .symbolEffect(.bounce, value: isSelected)
                        .symbolEffectsRemoved(accessibilityReduceMotion || appReduceMotion)
                        .frame(height: 24)
                    Text(tab.title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .offset(y: isSelected ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .opacity(isSelected ? 1 : 0.78)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.96))
        .frame(maxWidth: .infinity)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
