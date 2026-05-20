import SwiftUI
import UIKit
import AuthenticationServices

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var activeSheet: ProfileSheet?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Text("我的")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                profileHeader
                accountCard
                liveActivityCard
                proCard
                settingsList
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 18)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $activeSheet) { sheet in
            ProfileDetailSheet(sheet: sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            AssetImage(name: "profile_avatar_worker_v1")
                .frame(width: 78, height: 78)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 5) {
                Text(appState.profile.nickname)
                    .font(.title3.weight(.black))
                Text(appState.profile.motto)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                activeSheet = .editProfile
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.coin)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1.3))
            }
            .buttonStyle(.plain)
        }
    }

    private var proCard: some View {
        Button {
            activeSheet = .pro
        } label: {
            ComicCard(background: Color(hex: 0xFFE7A3)) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.preferences.isProUnlocked ? "开薪 PRO 已开通" : "开薪 PRO · ¥6")
                            .font(.title3.weight(.black))
                        Text("同步、灵动岛和主题皮肤，一次解锁。")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(2)
                        Text(appState.preferences.isProUnlocked ? "查看权益" : "查看开通权益")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.coin)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.ink, lineWidth: 1))
                    }
                    Spacer()
                    AssetImage(name: "pro_sunglasses_worker_redraw_v1")
                        .frame(width: 104, height: 72)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var accountCard: some View {
        ComicCard(background: AppTheme.cream.opacity(0.78), padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 38, height: 38)
                        .background(appState.isSignedInWithApple ? AppTheme.coin : AppTheme.divider.opacity(0.6))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1.2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.isSignedInWithApple ? "Apple ID 已连接" : "连接 Apple ID")
                            .font(.subheadline.weight(.heavy))
                        Text(appState.appleAccountDetail)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                if appState.isSignedInWithApple {
                    Button {
                        appState.signOutAppleID()
                    } label: {
                        Label("退出 Apple ID", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .buttonStyle(.plain)
                } else {
                    AppleSignInButton {
                        appState.signInCompleted(credential: $0)
                    } onFailure: {
                        appState.signInFailed($0)
                    }
                    .frame(height: 46)
                }
            }
        }
    }

    private var settingsList: some View {
        ComicCard(padding: 0) {
            VStack(spacing: 0) {
                NavigationLink {
                    SalarySettingsView(mode: .salary)
                } label: {
                    SettingsRow(icon: "yensign.circle.fill", title: "薪资设置", detail: appState.settings.salaryType.title)
                }
                NavigationLink {
                    SalarySettingsView(mode: .workTime)
                } label: {
                    SettingsRow(icon: "clock.fill", title: "工作时间设置", detail: "\(appState.settings.workStart.displayText)-\(appState.settings.workEnd.displayText)")
                }
                profileButton(.reminders)
                profileButton(.data)
                profileButton(.help)
                profileButton(.about)
            }
        }
    }

    private var liveActivityCard: some View {
        LiveActivityControlCard(
            isAvailable: appState.preferences.isProUnlocked && appState.isLiveActivityAvailable,
            isActive: appState.isLiveActivityActive,
            statusTitle: appState.snapshot.status.title,
            errorMessage: appState.preferences.isProUnlocked ? appState.liveActivityErrorMessage : "PRO 功能，开通后可在锁屏和灵动岛展示。"
        ) {
            if appState.isLiveActivityActive {
                appState.endLiveActivity()
            } else {
                appState.startLiveActivity()
            }
        }
    }

    private func profileButton(_ sheet: ProfileSheet) -> some View {
        Button {
            activeSheet = sheet
        } label: {
            SettingsRow(icon: sheet.icon, title: sheet.title, detail: detailText(for: sheet))
        }
        .buttonStyle(.plain)
    }

    private func detailText(for sheet: ProfileSheet) -> String {
        switch sheet {
        case .reminders:
            appState.preferences.remindersEnabled ? "已开启" : "未开启"
        default:
            sheet.detail
        }
    }

}

private enum ProfileSheet: String, Identifiable {
    case pro
    case editProfile
    case reminders
    case data
    case help
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pro: "crown.fill"
        case .editProfile: "pencil"
        case .reminders: "bell.fill"
        case .data: "icloud.fill"
        case .help: "questionmark.circle.fill"
        case .about: "info.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .pro: "开薪 PRO"
        case .editProfile: "编辑资料"
        case .reminders: "开薪提醒"
        case .data: "数据与同步"
        case .help: "帮助与反馈"
        case .about: "关于开薪"
        }
    }

    var detail: String {
        switch self {
        case .pro: "¥6 一次买断"
        case .editProfile: ""
        case .reminders: "未开启"
        case .data: "本地保存"
        case .help: ""
        case .about: "v0.1"
        }
    }

    var bodyText: String {
        switch self {
        case .pro:
            "PRO 是给高频打工人的增强包，当前定价 ¥6，一次开通后解锁 iCloud 同步、锁屏/灵动岛，后续主题皮肤也会放进 PRO。"
        case .editProfile:
            "修改昵称和个性签名后，会立刻保存在本机。"
        case .reminders:
            "提醒功能会用于上班开薪、下班结算和午休暂停提示。首版先不主动申请通知权限，避免一打开就打扰你。"
        case .data:
            "免费版本地保存；PRO 可通过 iCloud 私有数据库同步。也可以在这里删除账号与数据。"
        case .help:
            "计算规则：月薪按月薪 / 21.75 估算日薪，年薪按年薪 / 12 / 21.75，时薪按每日工作时长计算。默认周一到周五计薪。"
        case .about:
            "PayJoy「开薪」v0.1。本版本是原生 SwiftUI 首版，目标是让打工赚钱这件事变得看得见、好笑一点。"
        }
    }
}

private struct ProfileDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let sheet: ProfileSheet
    @State private var showsResetConfirmation = false
    @State private var showsDeleteAccountConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if sheet == .editProfile {
                    ProfileEditSheet()
                } else if sheet == .pro {
                    ProPaywallSheet()
                } else {
                    detailBody
                }
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.ink)
                }
            }
            .alert("恢复示例数据？", isPresented: $showsResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) {
                    appState.resetDemoData()
                }
            } message: {
                Text("薪资设置、昵称和本地偏好都会回到首版默认示例。")
            }
            .alert("删除账号与数据？", isPresented: $showsDeleteAccountConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task { await appState.deleteAccountAndLocalData() }
                }
            } message: {
                Text("这会退出 Apple ID，并删除本机保存的数据；若已连接 iCloud，也会尝试删除开薪的 iCloud 私有库记录。此操作不能撤销。")
            }
        }
    }

    private var detailBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            sheetHeader

            ComicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(sheet.bodyText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineSpacing(4)

                    switch sheet {
                    case .reminders:
                        remindersControls
                    case .data:
                        dataControls
                    case .help:
                        legalControls
                    case .pro:
                        EmptyView()
                    default:
                        EmptyView()
                    }
                }
            }

            Spacer()
        }
        .padding(AppTheme.pagePadding)
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: sheet.icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 48, height: 48)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1.4))
            VStack(alignment: .leading, spacing: 4) {
                Text(sheet.title)
                    .font(.title3.weight(.black))
                Text(sheet.detail.isEmpty ? "首版功能" : sheet.detail)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var remindersControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("上班/下班本地提醒", isOn: Binding {
                appState.preferences.remindersEnabled
            } set: { newValue in
                appState.setRemindersEnabled(newValue)
            })
                .font(.subheadline.weight(.heavy))
                .tint(AppTheme.coin)
            Text(reminderHelpText)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)

            HStack(spacing: 10) {
                Button {
                    appState.refreshReminderAuthorization()
                } label: {
                    Label("检查权限", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.heavy))
                }
                .buttonStyle(.plain)

                if appState.reminderPermissionState == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("打开设置", systemImage: "gearshape.fill")
                            .font(.caption.weight(.heavy))
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(AppTheme.ink)
        }
    }

    private var reminderHelpText: String {
        if appState.preferences.remindersEnabled {
            return "已安排周一到周五 \(appState.settings.workStart.displayText) 开薪、\(appState.settings.workEnd.displayText) 到账提醒。"
        }
        switch appState.reminderPermissionState {
        case .notDetermined:
            return "开启后会请求系统通知权限，只用于上班和下班提醒。"
        case .denied:
            return "系统通知权限已关闭，需要到设置里重新打开。"
        case .authorized, .provisional, .ephemeral:
            return "通知权限可用，打开开关后会安排工作日提醒。"
        case .unknown:
            return "通知权限状态未知，可以点检查权限刷新。"
        }
    }

    private var dataControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(AppTheme.divider)
            HStack {
                ProfileInfoChip(title: "Apple ID", value: appState.isSignedInWithApple ? "已连接" : "未连接")
                ProfileInfoChip(title: "iCloud", value: appState.cloudStatusText)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await appState.syncToCloud() }
                } label: {
                    Label(appState.isSyncing ? "同步中" : "上传 iCloud", systemImage: "icloud.and.arrow.up")
                        .font(.caption.weight(.heavy))
                }
                .buttonStyle(.plain)
                .disabled(appState.isSyncing)

                Button {
                    Task { await appState.restoreFromCloud() }
                } label: {
                    Label("恢复", systemImage: "icloud.and.arrow.down")
                        .font(.caption.weight(.heavy))
                }
                .buttonStyle(.plain)
                .disabled(appState.isSyncing)
            }
            .foregroundStyle(AppTheme.ink)

            Text(appState.syncMessage)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)

            Text("当前薪资：\(appState.settings.salaryType.title) \(appState.settings.salaryAmount.compactMoneyText)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppTheme.textGray)
            Text("工作时间：\(appState.settings.workStart.displayText)-\(appState.settings.workEnd.displayText)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppTheme.textGray)
            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Text("恢复示例数据")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.red)
            }
            .padding(.top, 4)

            Button(role: .destructive) {
                showsDeleteAccountConfirmation = true
            } label: {
                Text("删除账号与数据")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.red)
            }
        }
    }

    private var legalControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Link(destination: PayJoyLegalLinks.privacy) {
                Label("隐私政策", systemImage: "hand.raised.fill")
                    .font(.subheadline.weight(.heavy))
            }
            Link(destination: PayJoyLegalLinks.terms) {
                Label("服务条款", systemImage: "doc.plaintext.fill")
                    .font(.subheadline.weight(.heavy))
            }
            Link(destination: PayJoyLegalLinks.support) {
                Label("支持与反馈", systemImage: "questionmark.circle.fill")
                    .font(.subheadline.weight(.heavy))
            }
            Link(destination: PayJoyLegalLinks.deleteAccount) {
                Label("账号删除说明", systemImage: "trash.fill")
                    .font(.subheadline.weight(.heavy))
            }
        }
        .foregroundStyle(AppTheme.ink)
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding {
            appState.preferences[keyPath: keyPath]
        } set: { newValue in
            var preferences = appState.preferences
            preferences[keyPath: keyPath] = newValue
            appState.preferences = preferences
        }
    }
}

private struct ProfileEditSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var motto = ""
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ComicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("昵称")
                        .font(.headline.weight(.heavy))
                    TextField("打工人小开", text: $nickname)
                        .textFieldStyle(.roundedBorder)

                    Text("个性签名")
                        .font(.headline.weight(.heavy))
                    TextField("努力生活，开心开薪！", text: $motto, axis: .vertical)
                        .lineLimit(2...3)
                        .textFieldStyle(.roundedBorder)
                }
            }

            PrimaryButton(title: "保存资料") {
                appState.profile = UserProfile(
                    nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UserProfile.defaultValue.nickname : nickname,
                    motto: motto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UserProfile.defaultValue.motto : motto
                )
                dismiss()
            }

            Spacer()
        }
        .padding(AppTheme.pagePadding)
        .onAppear {
            guard !didLoad else { return }
            nickname = appState.profile.nickname
            motto = appState.profile.motto
            didLoad = true
        }
    }
}

private struct ProPaywallSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                ComicCard(background: Color(hex: 0xFFE7A3)) {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("开薪 PRO")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                            Text("¥6 一次买断")
                                .font(.title3.weight(.black))
                            Text("把开薪放进锁屏、灵动岛和 iCloud，后续主题皮肤也一起解锁。")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textGray)
                                .lineSpacing(3)
                        }
                        Spacer()
                        AssetImage(name: "pro_sunglasses_worker_redraw_v1")
                            .frame(width: 118, height: 92)
                    }
                }

                ComicCard {
                    VStack(spacing: 12) {
                        ProBenefitRow(icon: "icloud.fill", title: "iCloud 同步", subtitle: "换机或多设备使用时，设置可以备份和恢复。")
                        ProBenefitRow(icon: "sparkles.rectangle.stack.fill", title: "锁屏 / 灵动岛", subtitle: "开薪中也能在系统实时活动里看到收入。")
                        ProBenefitRow(icon: "paintpalette.fill", title: "主题皮肤", subtitle: "后续漫画主题、图标和装饰会优先放进 PRO。")
                    }
                }

                PrimaryButton(title: appState.preferences.isProUnlocked ? "已开通" : "¥6 开通 PRO") {
                    appState.unlockProForCurrentVersion()
                    dismiss()
                }
                .disabled(appState.preferences.isProUnlocked)
                .opacity(appState.preferences.isProUnlocked ? 0.55 : 1)

                Text("当前版本先接入本地解锁流程；正式上架时这里会切到 App Store 内购付款页，实际扣款以 Apple 页面为准。")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(3)
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.paper.ignoresSafeArea())
    }
}

private struct ProBenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 34, height: 34)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.black))
                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(2)
            }
            Spacer()
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 0.7)
                .padding(.leading, 48)
        }
    }
}

private struct ProfileInfoChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.cream.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.ink, lineWidth: 1)
        }
    }
}

private struct AppleSignInButton: View {
    var onSuccess: (ASAuthorizationAppleIDCredential) -> Void
    var onFailure: (Error) -> Void

    @State private var coordinator = AppleSignInCoordinator()

    var body: some View {
        Button {
            coordinator.start(onSuccess: onSuccess, onFailure: onFailure)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .black))
                Text("通过 Apple 继续")
                    .font(.subheadline.weight(.black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var onSuccess: ((ASAuthorizationAppleIDCredential) -> Void)?
    private var onFailure: ((Error) -> Void)?

    func start(
        onSuccess: @escaping (ASAuthorizationAppleIDCredential) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        Task { @MainActor in
            onSuccess?(credential)
            clearCallbacks()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            onFailure?(error)
            clearCallbacks()
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }

    private func clearCallbacks() {
        onSuccess = nil
        onFailure = nil
    }
}

private enum PayJoyLegalLinks {
    static let privacy = URL(string: "https://sunzhengnj.github.io/PayJoy/privacy.html")!
    static let terms = URL(string: "https://sunzhengnj.github.io/PayJoy/terms.html")!
    static let support = URL(string: "https://sunzhengnj.github.io/PayJoy/support.html")!
    static let deleteAccount = URL(string: "https://sunzhengnj.github.io/PayJoy/delete-account.html")!
}
