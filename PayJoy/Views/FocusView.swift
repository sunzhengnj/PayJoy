import SwiftUI

struct FocusView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.duoDeviceAvailable) private var duoDeviceAvailable
    @Environment(\.payJoyWindowScene) private var windowScene
    @AppStorage("payjoy.focus.keepScreenAwake") private var keepsScreenAwake = false
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @Binding var showsOffWorkTime: Bool
    var embeddedInTab = false
    var onDeskClose: () -> Void = {}
    @State private var selectedMinutes = 25
    @State private var customMinutes = ""
    @State private var showsCustomMinutes = false
    @State private var showsEndConfirmation = false
    @State private var showsMoyuConfirmation = false
    @State private var showsFocusStartUnavailable = false
    @State private var pendingStart: PendingStart?
    @FocusState private var customFieldFocused: Bool

    private enum PendingStart {
        case minutes(Int)
        case offWork
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveLayoutContext(proxy: geometry)
            let focusBounds = layout.singleColumnBounds
            ZStack {
                background.ignoresSafeArea()

                if layout.canShowDeskClock || (layout.verticalDivision != nil && layout.hasRoomForTwoColumns),
                   appState.focusData.active != nil {
                    DeskClockView(showsOffWorkTime: $showsOffWorkTime) {
                        onDeskClose()
                        appState.selectedTab = .home
                        appState.isFocusPresented = false
                    }
                    .transition(.opacity)
                } else if let session = appState.focusData.active {
                    runningView(
                        session: session,
                        size: focusBounds.size,
                        showsRotationControl: !duoDeviceAvailable && layout.divisionRegions.isEmpty,
                        topControlClearance: 0
                    )
                    .adaptiveSinglePane(in: layout)
                    .transition(.opacity)
                } else if let result = appState.focusData.pendingResult {
                    if layout.canShowDeskClock || (layout.verticalDivision != nil && layout.hasRoomForTwoColumns) {
                        foldedResultView(result, layout: layout)
                            .transition(.opacity)
                    } else {
                        resultView(result, availableHeight: focusBounds.height)
                            .adaptiveSinglePane(in: layout)
                            .transition(.opacity)
                    }
                } else {
                    // One input subtree across poses preserves the custom draft and keyboard focus.
                    setupView(layout: layout)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.adaptiveLayoutContext, layout)
            .animation(prefersReducedMotion ? nil : .easeInOut(duration: 0.22), value: displayPhase)
            .animation(prefersReducedMotion ? nil : .easeInOut(duration: 0.18), value: appState.focusData.prefersDarkBackground)
        }
        .preferredColorScheme(appState.focusData.active == nil && appState.focusData.pendingResult == nil
            ? (AppTheme.current == .midnight ? .dark : .light)
            : (appState.focusData.prefersDarkBackground ? .dark : .light))
        .alert(L10n.t("结束这段专注？"), isPresented: $showsEndConfirmation) {
            Button(L10n.t("继续专注"), role: .cancel) {}
            Button(L10n.t("结束"), role: .destructive) { appState.endFocus() }
        } message: {
            Text(L10n.t("已专注的时间会保留。"))
        }
        .alert(L10n.t("正在摸鱼"), isPresented: $showsMoyuConfirmation) {
            Button(L10n.t("取消"), role: .cancel) { pendingStart = nil }
            Button(L10n.t("结束摸鱼并开始专注")) {
                beginPendingStart()
            }
        } message: {
            Text(L10n.t("两种计时不能同时进行。"))
        }
        .alert(L10n.t("现在无法专注到下班"), isPresented: $showsFocusStartUnavailable) {
            Button(L10n.t("知道了"), role: .cancel) {}
        } message: {
            Text(L10n.t("工作状态或剩余时间已变化，原有计时未改变。"))
        }
    }

    private var background: Color {
        if appState.focusData.active == nil && appState.focusData.pendingResult == nil {
            return AppTheme.paper
        }
        return appState.focusData.prefersDarkBackground ? .black : .white
    }

    private enum DisplayPhase: Equatable {
        case setup, running, result
    }

    private var displayPhase: DisplayPhase {
        if appState.focusData.active != nil {
            return .running
        }
        return appState.focusData.pendingResult == nil ? .setup : .result
    }

    private var prefersReducedMotion: Bool {
        accessibilityReduceMotion || appState.preferences.reduceMotion
    }

    private var foreground: Color {
        appState.focusData.prefersDarkBackground ? .white : .black
    }

    private var secondary: Color {
        foreground.opacity(0.62)
    }

    private var accessibleTextScale: CGFloat {
        min(textScale, 2)
    }

    private func runningView(
        session: FocusSession,
        size: CGSize,
        showsRotationControl: Bool,
        topControlClearance: CGFloat
    ) -> some View {
        let displaysOffWork = showsOffWorkTime && appState.canShowFocusOffWorkTime
        let title = Self.clockTitle(isPaused: session.isPaused, showsOffWorkTime: displaysOffWork)
        let offWorkRemaining = session.endsAtWork
            ? max(0, session.endDate.timeIntervalSince(appState.now))
            : appState.snapshot.secondsUntilOffWork
        let remaining = displaysOffWork ? offWorkRemaining : session.remaining(at: appState.now)

        return ZStack {
            VStack {
                HStack {
                    Button {
                        appState.selectedTab = .home
                        appState.isFocusPresented = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.t("收起专注，计时继续"))

                    Spacer()
                    if showsRotationControl {
                        Button {
                            FocusOrientationPolicy.update(
                                orientation: size.width > size.height ? .portrait : .landscapeRight,
                                in: windowScene
                            )
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(foreground, lineWidth: 2)
                                .frame(width: size.width > size.height ? 14 : 22,
                                       height: size.width > size.height ? 22 : 14)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(size.width > size.height ? L10n.t("切换竖屏") : L10n.t("切换横屏"))
                    }
                    appearanceButton
                    Menu {
                        Toggle(L10n.t("屏幕常亮"), isOn: $keepsScreenAwake)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.t("专注设置"))
                }
                Spacer()
                HStack(spacing: 52) {
                    Button {
                        session.isPaused ? appState.resumeFocus() : appState.pauseFocus()
                    } label: {
                        Text(session.isPaused ? L10n.t("继续") : L10n.t("暂停"))
                            .frame(minWidth: 72, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    Button {
                        showsEndConfirmation = true
                    } label: {
                        Text(L10n.t("结束"))
                            .frame(minWidth: 72, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                .font(.system(size: 17 * accessibleTextScale, weight: .medium))
                .buttonStyle(PayJoyPressStyle(scale: 0.98))
                .contentTransition(.opacity)
                .animation(prefersReducedMotion ? nil : .easeOut(duration: 0.18), value: session.isPaused)
                .frame(minHeight: 52)
            }
            .padding(.horizontal, 22)
            .padding(.top, max(8, topControlClearance))
            .padding(.bottom, 16)

            VStack(spacing: size.height < 500 ? 8 : 16) {
                if appState.canShowFocusOffWorkTime {
                    Menu {
                        Button(L10n.t("本段剩余")) {
                            withAnimation(prefersReducedMotion ? nil : .easeOut(duration: 0.2)) { showsOffWorkTime = false }
                        }
                        Button(L10n.t("距下班")) {
                            withAnimation(prefersReducedMotion ? nil : .easeOut(duration: 0.2)) { showsOffWorkTime = true }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .accessibilityHint(L10n.t("切换显示的时间"))
                } else {
                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .accessibilityHidden(true)
                }

                Text(Self.timeText(remaining))
                    .font(.system(size: min(size.width * 0.33, size.height * 0.4, 158), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(prefersReducedMotion ? .identity : .numericText(countsDown: true))
                    .animation(prefersReducedMotion ? nil : .easeOut(duration: 0.18), value: Self.timeText(remaining))
                    .foregroundStyle(foreground)
                    .accessibilityLabel(title)
                    .accessibilityValue(Self.timeText(remaining))
            }
            .font(.system(size: 16 * accessibleTextScale, weight: .regular))
            .foregroundStyle(secondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .offset(y: -10)
            .contentTransition(.opacity)
            .animation(prefersReducedMotion ? nil : .easeOut(duration: 0.18), value: session.isPaused)
        }
        .foregroundStyle(foreground)
    }

    private func setupView(layout: AdaptiveLayoutContext) -> some View {
        let division = layout.hasRoomForTwoColumns ? layout.verticalDivision : nil
        let bounds = division == nil ? layout.singleColumnBounds : CGRect(origin: .zero, size: layout.size)
        let leadingWidth = division.map { max(0, $0.minX - 48) }
        let trailingWidth = division.map { max(0, layout.size.width - $0.maxX - 48) }
        let columns = division == nil
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            : AnyLayout(HStackLayout(alignment: .top, spacing: (division?.width ?? 0) + 48))
        return ScrollView(showsIndicators: false) {
            columns {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        if embeddedInTab {
                            Text(L10n.t("专注"))
                                .font(.system(size: 29 * accessibleTextScale, weight: .black, design: .rounded))
                        } else {
                            Button(L10n.t("返回")) { appState.isFocusPresented = false }
                                .font(.system(size: 17 * accessibleTextScale, weight: .semibold))
                                .frame(minHeight: 44)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 10)

                    ComicCard(background: AppTheme.cream, radius: 26, padding: 20) {
                        VStack(alignment: .leading, spacing: 18) {
                            Label(L10n.t("专注多久？"), systemImage: "timer")
                                .font(.system(size: 19 * accessibleTextScale, weight: .heavy, design: .rounded))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(showsCustomMinutes && !FocusSession.durationMinuteRange.contains(chosenMinutes) ? "—" : "\(chosenMinutes)")
                                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 58 : 86, weight: .black, design: .rounded))
                                        .monospacedDigit()
                                        .contentTransition(prefersReducedMotion ? .identity : .numericText())
                                    Text(L10n.t("分钟"))
                                        .font(.system(size: 18 * accessibleTextScale, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppTheme.textGray)
                                    Spacer(minLength: 0)
                                }
                                if FocusSession.durationMinuteRange.contains(chosenMinutes) {
                                    Text(L10n.format("预计 %@ 结束", estimatedEndTime))
                                        .font(.system(size: 14 * accessibleTextScale, weight: .medium))
                                        .foregroundStyle(AppTheme.textGray)
                                }
                            }
                            .accessibilityElement(children: .combine)

                            let durationLayout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(spacing: 8))
                                : AnyLayout(HStackLayout(spacing: 8))
                            durationLayout {
                                durationButton(25)
                                durationButton(45)
                                Button {
                                    withAnimation(prefersReducedMotion ? nil : .snappy(duration: 0.24)) {
                                        showsCustomMinutes = true
                                    }
                                    customFieldFocused = true
                                } label: {
                                    Text(L10n.t("自定"))
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .background(showsCustomMinutes ? AppTheme.coin : AppTheme.paper, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.outline, lineWidth: showsCustomMinutes ? 2 : 1))
                                        .contentShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(PayJoyPressStyle())
                                .accessibilityAddTraits(showsCustomMinutes ? .isSelected : [])
                            }
                            .font(.system(size: 15 * accessibleTextScale, weight: .bold, design: .rounded))

                            if showsCustomMinutes {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        TextField(L10n.t("分钟"), text: $customMinutes)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.center)
                                            .focused($customFieldFocused)
                                            .frame(maxWidth: 100)
                                        Text(L10n.t("分钟"))
                                        Spacer()
                                        if customFieldFocused {
                                            Button(L10n.t("完成")) { customFieldFocused = false }
                                        }
                                    }
                                    Text(L10n.format(
                                        "请输入 %d–%d 分钟（整数）",
                                        FocusSession.durationMinuteRange.lowerBound,
                                        FocusSession.durationMinuteRange.upperBound
                                    ))
                                    .font(.system(size: 12 * accessibleTextScale, weight: .medium))
                                    .foregroundStyle(AppTheme.textGray)
                                    .fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.system(size: 17 * accessibleTextScale, weight: .medium))
                                .padding(12)
                                .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                                .transition(prefersReducedMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

                }
                .padding(.top, division.map {
                    layout.topContentClearance(in: CGRect(x: 0, y: 0, width: $0.minX, height: layout.size.height))
                } ?? 0)
                .frame(width: leadingWidth)

                VStack(spacing: 18) {
                    Button {
                        requestStart(.minutes(chosenMinutes))
                    } label: {
                        HStack {
                            Spacer()
                            Text(L10n.t("开始专注"))
                            Image(systemName: "arrow.right")
                            Spacer()
                        }
                        .font(.system(size: 18 * accessibleTextScale, weight: .heavy, design: .rounded))
                        .frame(minHeight: 58)
                        .background(AppTheme.coin, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.outline, lineWidth: 1.6))
                        .shadow(color: AppTheme.shadow.opacity(0.14), radius: 1, x: 3, y: 3)
                    }
                    .buttonStyle(PayJoyPressStyle())
                    .disabled(!FocusSession.durationMinuteRange.contains(chosenMinutes))
                    .opacity(FocusSession.durationMinuteRange.contains(chosenMinutes) ? 1 : 0.4)

                    if let duration = appState.focusToOffWorkDuration {
                        Button {
                            requestStart(.offWork)
                        } label: {
                            Text(L10n.format("专注到下班 · %d 分钟", Int(ceil(duration / 60))))
                                .font(.system(size: 16 * accessibleTextScale, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(AppTheme.cream, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.outline, lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(PayJoyPressStyle())
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "sun.max")
                            .font(.system(size: 18, weight: .bold))
                        Toggle(L10n.t("屏幕常亮"), isOn: $keepsScreenAwake)
                            .tint(AppTheme.coin)
                    }
                    .font(.system(size: 15 * accessibleTextScale, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(AppTheme.cream, in: RoundedRectangle(cornerRadius: 16))

                    Spacer(minLength: 24)
                    Label(setupFocusSummary, systemImage: "chart.bar.fill")
                        .font(.system(size: 13 * accessibleTextScale, weight: .medium))
                        .foregroundStyle(AppTheme.textGray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.cream, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.top, division.map {
                    layout.topContentClearance(in: CGRect(x: $0.maxX, y: 0, width: layout.size.width - $0.maxX, height: layout.size.height))
                } ?? 0)
                .frame(width: trailingWidth)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(minHeight: bounds.height, alignment: .top)
            .frame(maxWidth: division == nil ? 520 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppTheme.ink)
        .frame(width: bounds.width, height: bounds.height)
        .clipped()
        .position(x: bounds.midX, y: bounds.midY)
    }

    private func resultView(_ record: FocusRecord, availableHeight: CGFloat) -> some View {
        let canCloseDay = record.endsAtWork && appState.canOpenClosingReceipt
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 16)
                Text(record.completed ? L10n.t("这一段完成了") : L10n.t("这一段已结束"))
                    .font(.system(size: 25 * accessibleTextScale, weight: .medium))
                Text(Self.timeText(record.focusedDuration))
                    .font(.system(size: 66, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel(L10n.t("实际专注时间"))
                    .accessibilityValue(Self.timeText(record.focusedDuration))
                Text(L10n.t("实际专注时间"))
                    .font(.system(size: 14 * accessibleTextScale))
                    .foregroundStyle(secondary)
                    .accessibilityHidden(true)
                Text(todayFocusSummary)
                    .font(.system(size: 15 * accessibleTextScale))
                    .foregroundStyle(secondary)
                Spacer(minLength: 16)
                resultActions(canCloseDay: canCloseDay, spacing: 22)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(minHeight: availableHeight)
        }
        .foregroundStyle(foreground)
    }

    private func foldedResultView(_ record: FocusRecord, layout: AdaptiveLayoutContext) -> some View {
        let isBook = layout.verticalDivision != nil
        let division = layout.verticalDivision ?? layout.horizontalDivision ?? .zero
        let resultSize = CGSize(width: isBook ? division.minX : layout.size.width,
                                height: isBook ? layout.size.height : division.minY)
        let actionsSize = CGSize(width: isBook ? max(0, layout.size.width - division.maxX) : layout.size.width,
                                 height: isBook ? layout.size.height : max(0, layout.size.height - division.maxY))
        let topClearance = layout.topContentClearance(in: CGRect(origin: .zero, size: resultSize))
        let canCloseDay = record.endsAtWork && appState.canOpenClosingReceipt
        let arrangement = isBook ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))

        return arrangement {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Text(record.completed ? L10n.t("这一段完成了") : L10n.t("这一段已结束"))
                    .font(.system(size: 22 * accessibleTextScale, weight: .medium))
                Text(Self.timeText(record.focusedDuration))
                    .font(.system(size: min(resultSize.width * 0.18, max(0, resultSize.height - topClearance) * 0.35, 132), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel(L10n.t("实际专注时间"))
                    .accessibilityValue(Self.timeText(record.focusedDuration))
                Text(L10n.t("实际专注时间"))
                    .font(.system(size: 14 * accessibleTextScale))
                    .foregroundStyle(secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, topClearance)
            .frame(width: resultSize.width, height: resultSize.height)
            .clipped()

            Color.clear.frame(width: isBook ? max(0, division.width) : nil, height: isBook ? nil : max(0, division.height))

            ScrollView {
                VStack(spacing: 14) {
                    Spacer(minLength: 0)
                    Text(todayFocusSummary)
                        .font(.system(size: 15 * accessibleTextScale))
                        .foregroundStyle(secondary)
                    resultActions(canCloseDay: canCloseDay, spacing: 10)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
                .frame(minHeight: actionsSize.height)
            }
            .frame(width: actionsSize.width, height: actionsSize.height)
        }
        .foregroundStyle(foreground)
    }

    private func resultActions(canCloseDay: Bool, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            Button {
                if canCloseDay {
                    appState.dismissFocusResult(openClosingReceipt: true)
                } else {
                    appState.focusData.pendingResultID = nil
                }
            } label: {
                Text(L10n.t(canCloseDay ? "收下今天" : "再来一段"))
                    .font(.system(size: 17 * accessibleTextScale, weight: .semibold))
                    .foregroundStyle(background)
                    .frame(maxWidth: 260, minHeight: 52)
                    .background(foreground, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(PayJoyPressStyle(scale: 0.98))
            if canCloseDay {
                Button {
                    appState.focusData.pendingResultID = nil
                } label: {
                    Text(L10n.t("再来一段"))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
            Button {
                appState.dismissFocusResult()
            } label: {
                Text(L10n.t("完成"))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    private var appearanceButton: some View {
        Button {
            appState.focusData.prefersDarkBackground.toggle()
        } label: {
            Image(systemName: appState.focusData.prefersDarkBackground ? "sun.max" : "moon")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(appState.focusData.prefersDarkBackground ? L10n.t("切换为白底") : L10n.t("切换为黑底"))
    }

    private func durationButton(_ minutes: Int) -> some View {
        let selected = !showsCustomMinutes && selectedMinutes == minutes
        return Button {
            withAnimation(prefersReducedMotion ? nil : .snappy(duration: 0.24)) {
                selectedMinutes = minutes
                showsCustomMinutes = false
            }
        } label: {
            Text(L10n.format("%d 分钟", minutes))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(selected ? AppTheme.coin : AppTheme.paper, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.outline, lineWidth: selected ? 2 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PayJoyPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var chosenMinutes: Int {
        showsCustomMinutes ? (FocusSession.customMinutes(from: customMinutes) ?? 0) : selectedMinutes
    }

    private var estimatedEndTime: String {
        let endDate = appState.now.addingTimeInterval(TimeInterval(chosenMinutes * 60))
        let dateStyle: Date.FormatStyle.DateStyle = Calendar.current.isDate(endDate, inSameDayAs: appState.now)
            ? .omitted : .abbreviated
        return endDate.formatted(Date.FormatStyle(date: dateStyle, time: .shortened)
            .locale(Locale(identifier: L10n.currentLanguage.localeIdentifier)))
    }

    private var todayFocusSummary: String {
        let duration = appState.todayFocusDuration
        if duration > 0 && duration < 60 {
            return L10n.format("今天累计 %d 秒", Int(ceil(duration)))
        }
        return L10n.format("今天累计 %d 分钟", Int(duration / 60))
    }

    private var setupFocusSummary: String {
        let duration = appState.todayFocusDuration
        let recentMinutes = Int(appState.recentFocusDuration / 60)
        if duration > 0 && duration < 60 {
            return L10n.format("今天 %d 秒 · 近七天 %d 分钟", Int(ceil(duration)), recentMinutes)
        }
        return L10n.format("今天 %d 分钟 · 近七天 %d 分钟", Int(duration / 60), recentMinutes)
    }

    private func requestStart(_ start: PendingStart) {
        pendingStart = start
        if appState.moyuStartedAt != nil {
            showsMoyuConfirmation = true
        } else {
            beginPendingStart()
        }
    }

    private func beginPendingStart() {
        guard let pendingStart else { return }
        switch pendingStart {
        case .minutes(let minutes): appState.startFocus(minutes: minutes)
        case .offWork:
            if !appState.startFocus(minutes: 25, endsAtWork: true) {
                Task { @MainActor in
                    await Task.yield()
                    showsFocusStartUnavailable = true
                }
            }
        }
        self.pendingStart = nil
    }

    static func clockTitle(isPaused: Bool, showsOffWorkTime: Bool) -> String {
        let meaning = showsOffWorkTime ? L10n.t("距下班") : L10n.t("本段剩余")
        return isPaused ? "\(meaning) · \(L10n.t("专注已暂停"))" : meaning
    }

    static func timeText(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(ceil(interval)))
        let hours = seconds / 3600
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, (seconds % 3600) / 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

enum DeskClockMode: Equatable {
    case focus
    case overtime
    case offWork
    case nextWork
    case resting

    static func select(status: WorkdayStatus, hasFocus: Bool, hasOvertime: Bool, hasNextWork: Bool) -> Self {
        if hasFocus { return .focus }
        if hasOvertime { return .overtime }
        switch status {
        case .working, .lunchBreak: return .offWork
        case .beforeWork, .afterWork, .restDay: return hasNextWork ? .nextWork : .resting
        }
    }
}

struct DeskClockView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("payjoy.focus.keepScreenAwake") private var keepsScreenAwake = false
    @Binding var showsOffWorkTime: Bool
    let onClose: () -> Void
    let onStopOvertime: (OvertimeRecord) -> Void

    init(
        showsOffWorkTime: Binding<Bool>,
        onStopOvertime: @escaping (OvertimeRecord) -> Void = { _ in },
        onClose: @escaping () -> Void
    ) {
        _showsOffWorkTime = showsOffWorkTime
        self.onStopOvertime = onStopOvertime
        self.onClose = onClose
    }

    @State private var showsEndConfirmation = false
    @State private var showsMoyuConfirmation = false
    @State private var pendingDeskFocusEndsAtWork = false
    @State private var showsFocusStartUnavailable = false

    private var foreground: Color { appState.focusData.prefersDarkBackground ? .white : .black }
    private var secondary: Color { foreground.opacity(0.62) }
    private var prefersReducedMotion: Bool { accessibilityReduceMotion || appState.preferences.reduceMotion }
    private var mode: DeskClockMode {
        DeskClockMode.select(
            status: appState.snapshot.status,
            hasFocus: appState.focusData.active != nil,
            hasOvertime: appState.activeOvertimeRecord != nil,
            hasNextWork: appState.nextWorkStartDate != nil
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveLayoutContext(proxy: geometry)
            let bookDivision = layout.verticalDivision
            let isBook = bookDivision != nil
            let division = bookDivision ?? layout.horizontalDivision
            let firstExtent = isBook ? (division?.minX ?? 0) : (division?.minY ?? geometry.size.height * 0.55)
            let gap = isBook ? (division?.width ?? 0) : (division?.height ?? 0)
            let clockSize = CGSize(width: isBook ? firstExtent : geometry.size.width,
                                   height: isBook ? geometry.size.height : firstExtent)
            let controlSize = CGSize(width: isBook ? max(0, geometry.size.width - firstExtent - gap) : geometry.size.width,
                                     height: isBook ? geometry.size.height : max(0, geometry.size.height - firstExtent - gap))
            let clockBounds = CGRect(origin: .zero, size: clockSize)
            let arrangement = isBook
                ? AnyLayout(HStackLayout(spacing: 0))
                : AnyLayout(VStackLayout(spacing: 0))

            arrangement {
                clockFace(
                    timeFontSize: layout.deskClockTimeFontSize(in: clockBounds),
                    topControlClearance: layout.topControlClearance(in: clockBounds)
                )
                .frame(width: clockSize.width, height: clockSize.height)
                Color.clear.frame(width: isBook ? gap : nil, height: isBook ? nil : gap)
                ScrollView {
                    controls
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: controlSize.height)
                        .padding(.horizontal, 16)
                }
                .frame(width: controlSize.width, height: controlSize.height)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background((appState.focusData.prefersDarkBackground ? Color.black : Color.white).ignoresSafeArea())
            .animation(prefersReducedMotion ? nil : .easeInOut(duration: 0.18), value: appState.focusData.prefersDarkBackground)
        }
        .preferredColorScheme(appState.focusData.prefersDarkBackground ? .dark : .light)
        .alert(L10n.t("结束这段专注？"), isPresented: $showsEndConfirmation) {
            Button(L10n.t("继续专注"), role: .cancel) {}
            Button(L10n.t("结束"), role: .destructive) { appState.endFocus() }
        } message: {
            Text(L10n.t("已专注的时间会保留。"))
        }
        .alert(L10n.t("正在摸鱼"), isPresented: $showsMoyuConfirmation) {
            Button(L10n.t("取消"), role: .cancel) {}
            Button(L10n.t("结束摸鱼并开始专注")) {
                if !appState.startFocus(minutes: 25, endsAtWork: pendingDeskFocusEndsAtWork),
                   pendingDeskFocusEndsAtWork {
                    Task { @MainActor in
                        await Task.yield()
                        showsFocusStartUnavailable = true
                    }
                }
            }
        } message: {
            Text(L10n.t("两种计时不能同时进行。"))
        }
        .alert(L10n.t("现在无法专注到下班"), isPresented: $showsFocusStartUnavailable) {
            Button(L10n.t("知道了"), role: .cancel) {}
        } message: {
            Text(L10n.t("工作状态或剩余时间已变化，原有计时未改变。"))
        }
    }

    private func clockFace(timeFontSize: CGFloat, topControlClearance: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.t("返回"))
                Spacer()
                if appState.focusData.active != nil && appState.canShowFocusOffWorkTime {
                    Menu {
                        Button(L10n.t("本段剩余")) {
                            withAnimation(prefersReducedMotion ? nil : .easeOut(duration: 0.2)) { showsOffWorkTime = false }
                        }
                        Button(L10n.t("距下班")) {
                            withAnimation(prefersReducedMotion ? nil : .easeOut(duration: 0.2)) { showsOffWorkTime = true }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.t("切换显示的时间"))
                }
                Button {
                    appState.focusData.prefersDarkBackground.toggle()
                } label: {
                    Image(systemName: appState.focusData.prefersDarkBackground ? "sun.max" : "moon")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(appState.focusData.prefersDarkBackground ? L10n.t("切换为白底") : L10n.t("切换为黑底"))
            }
            .padding(.horizontal, 16)
            .padding(.top, topControlClearance)

            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text(clockTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: 20)
                    .contentTransition(.opacity)
                    .accessibilityHidden(true)
                Text(clockValue)
                    .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(height: timeFontSize * 1.25)
                    .contentTransition(prefersReducedMotion ? .identity : .numericText(countsDown: mode != .overtime))
                    .animation(prefersReducedMotion ? nil : .easeOut(duration: 0.18), value: clockValue)
                    .accessibilityLabel(clockTitle)
                    .accessibilityValue(clockValue)
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if let session = appState.focusData.active {
                HStack(spacing: 12) {
                    deskAction(session.isPaused ? L10n.t("继续") : L10n.t("暂停"), prominent: true) {
                        session.isPaused ? appState.resumeFocus() : appState.pauseFocus()
                    }
                    deskAction(L10n.t("结束"), prominent: false) { showsEndConfirmation = true }
                }
            } else if let record = appState.activeOvertimeRecord {
                deskAction(L10n.t("结束加班"), prominent: true) { onStopOvertime(record) }
            } else {
                deskAction("\(L10n.t("开始专注")) · \(L10n.format("%d 分钟", 25))", prominent: true) {
                    if appState.moyuStartedAt != nil {
                        pendingDeskFocusEndsAtWork = false
                        showsMoyuConfirmation = true
                    } else {
                        appState.startFocus(minutes: 25)
                    }
                }
                if let duration = appState.focusToOffWorkDuration {
                    deskAction(L10n.format("专注到下班 · %d 分钟", Int(ceil(duration / 60))), prominent: false) {
                        if appState.moyuStartedAt != nil {
                            pendingDeskFocusEndsAtWork = true
                            showsMoyuConfirmation = true
                        } else {
                            if !appState.startFocus(minutes: 25, endsAtWork: true) {
                                showsFocusStartUnavailable = true
                            }
                        }
                    }
                }
                if appState.canOpenClosingReceipt {
                    deskAction(L10n.t("收下今天"), prominent: false) { appState.openClosingReceipt() }
                }
            }
            Toggle(L10n.t("屏幕常亮"), isOn: $keepsScreenAwake)
                .font(.footnote)
                .tint(foreground)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func deskAction(_ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(prominent ? (appState.focusData.prefersDarkBackground ? Color.black : Color.white) : foreground)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(prominent ? foreground : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(foreground, lineWidth: 1.5))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98))
    }

    private var clockTitle: String {
        switch mode {
        case .focus:
            return FocusView.clockTitle(
                isPaused: appState.focusData.active?.isPaused == true,
                showsOffWorkTime: showsOffWorkTime && appState.canShowFocusOffWorkTime
            )
        case .overtime:
            return L10n.t("本次加班时长")
        case .offWork:
            return appState.snapshot.status == .lunchBreak
                ? "\(L10n.t("午休暂停")) · \(L10n.t("距下班"))"
                : L10n.t("距下班")
        case .nextWork:
            return L10n.t("下次上班")
        case .resting:
            return L10n.t("今天")
        }
    }

    private var clockValue: String {
        switch mode {
        case .focus:
            guard let session = appState.focusData.active else { return FocusView.timeText(0) }
            let remaining = showsOffWorkTime && appState.canShowFocusOffWorkTime
                ? (session.endsAtWork ? session.endDate.timeIntervalSince(appState.now) : appState.snapshot.secondsUntilOffWork)
                : session.remaining(at: appState.now)
            return FocusView.timeText(remaining)
        case .overtime:
            return FocusView.timeText(appState.activeOvertimeDuration)
        case .offWork:
            return FocusView.timeText(appState.snapshot.secondsUntilOffWork)
        case .nextWork:
            guard let nextStart = appState.nextWorkStartDate else { return L10n.t("休息中") }
            return FocusView.timeText(nextStart.timeIntervalSince(appState.now))
        case .resting:
            return L10n.t("休息中")
        }
    }

}
