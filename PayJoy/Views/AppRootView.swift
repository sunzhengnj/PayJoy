import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var didPrepareAppLock = false

    var body: some View {
        @Bindable var appState = appState

        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                AppTheme.paper.ignoresSafeArea()

                Group {
                    switch appState.selectedTab {
                    case .home:
                        NavigationStack { HomeView() }
                    case .stats:
                        NavigationStack { StatsView() }
                    case .profile:
                        NavigationStack { ProfileView() }
                    }
                }
                .padding(.bottom, appState.isTabBarHidden ? 0 : 58)

                if !appState.isTabBarHidden {
                    ComicTabBar(selectedTab: $appState.selectedTab)
                        .padding(.bottom, max(-22, -proxy.safeAreaInsets.bottom + 8))
                        .ignoresSafeArea(.container, edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if appState.shouldShowPrivacyShield {
                    AppPrivacyShield(
                        requiresPasscode: appState.isAppLocked,
                        message: appState.appLockMessage,
                        onSubmit: { passcode in
                            appState.unlockApp(with: passcode)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: appState.isTabBarHidden)
            .animation(.easeOut(duration: 0.16), value: appState.shouldShowPrivacyShield)
        }
        .onAppear {
            guard !didPrepareAppLock else { return }
            appState.prepareAppLockOnLaunch()
            didPrepareAppLock = true
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                appState.applicationDidBecomeActive()
            case .inactive, .background:
                appState.applicationWillResignActive()
            @unknown default:
                appState.applicationWillResignActive()
            }
        }
        .task {
            while !Task.isCancelled {
                appState.updateClock()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct AppPrivacyShield: View {
    let requiresPasscode: Bool
    let message: String?
    let onSubmit: (String) -> Bool
    @State private var passcode = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x063B42),
                    Color(hex: 0x0A1A22),
                    Color(hex: 0x083A35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: requiresPasscode ? "lock.fill" : "eye.slash.fill")
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 98, height: 98)
                    .background(
                        RadialGradient(
                            colors: [AppTheme.coin, AppTheme.orange],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 88
                        )
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 3))
                    .shadow(color: AppTheme.coin.opacity(0.35), radius: 18, x: 0, y: 8)

                VStack(spacing: 6) {
                    Text(requiresPasscode ? L10n.t("开薪已锁定") : L10n.t("开薪隐私保护中"))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(requiresPasscode ? L10n.t("请输入 4 位密码继续。") : L10n.t("多任务预览已隐藏你的收入和工作信息。"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.74))
                        .multilineTextAlignment(.center)
                }

                if requiresPasscode {
                    VStack(spacing: 18) {
                        HiddenPasscodeField(passcode: $passcode) {
                            submit()
                        }
                        PasscodeDots(count: passcode.count)
                        NumberPad(passcode: $passcode) {
                            submit()
                        }
                        if let message {
                            Text(message)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(AppTheme.coin)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 34)
        }
        .onChange(of: passcode) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(4))
            if digits != newValue {
                passcode = digits
                return
            }
            if digits.count == 4 {
                submit()
            }
        }
    }

    private func submit() {
        guard passcode.count == 4 else { return }
        if onSubmit(passcode) {
            passcode = ""
        } else {
            passcode = ""
        }
    }
}

private struct HiddenPasscodeField: View {
    @Binding var passcode: String
    let onSubmit: () -> Void

    var body: some View {
        TextField("", text: $passcode)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .onSubmit(onSubmit)
    }
}

private struct PasscodeDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < count ? AppTheme.coin : Color.white.opacity(0.26))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 1.4))
            }
        }
        .padding(.vertical, 2)
    }
}

private struct NumberPad: View {
    @Binding var passcode: String
    let onSubmit: () -> Void

    private let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "delete.left.fill"]
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { value in
                        Button {
                            tap(value)
                        } label: {
                            Group {
                                if value == "delete.left.fill" {
                                    Image(systemName: value)
                                } else {
                                    Text(value)
                                }
                            }
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 74, height: 58)
                            .background(value.isEmpty ? Color.clear : Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(value.isEmpty)
                    }
                }
            }
        }
    }

    private func tap(_ value: String) {
        if value == "delete.left.fill" {
            if !passcode.isEmpty {
                passcode.removeLast()
            }
            return
        }
        guard passcode.count < 4, !value.isEmpty else { return }
        passcode.append(value)
        if passcode.count == 4 {
            onSubmit()
        }
    }
}
