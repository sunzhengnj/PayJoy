import SwiftUI
import UIKit
import AuthenticationServices

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var activeSheet: ProfileSheet?
    @State private var showsProPaywall = false
    @State private var showsAccountManagement = false
    @State private var showsWidgetGuide = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Text(L10n.t("我的"))
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
        }
        .sheet(isPresented: $showsAccountManagement) {
            AccountManagementSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
        }
        .sheet(isPresented: $showsWidgetGuide) {
            WidgetGuideSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            ProfileAvatarImage(name: appState.profile.avatarAssetName, size: 78, lineWidth: 1.5)
            VStack(alignment: .leading, spacing: 5) {
                Text(appState.profile.displayNickname)
                    .font(.title3.weight(.black))
                Text(appState.profile.displayMotto)
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
                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.3))
            }
            .buttonStyle(.plain)
        }
    }

    private var proCard: some View {
        Button {
            showsProPaywall = true
        } label: {
            ComicCard(background: AppTheme.proCardBackground) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.hasEffectivePro ? L10n.t("开薪 PRO 已开通") : L10n.t("开薪 PRO · \(appState.proPriceText)"))
                            .font(.title3.weight(.black))
                        Text(L10n.t("同步、灵动岛、密码、午休和主题，一次解锁。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(2)
                        Text(appState.hasEffectivePro ? L10n.t("查看权益") : L10n.t("查看开通权益"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.coin)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                    }
                    Spacer()
                    AssetImage(name: AppTheme.proWorkerAsset)
                        .frame(width: 104, height: 72)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var accountCard: some View {
        if appState.isSignedInWithApple {
            Button {
                showsAccountManagement = true
            } label: {
                ComicCard(background: AppTheme.cream.opacity(0.78), padding: 14) {
                    accountCardContent(showsChevron: true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("管理 Apple ID"))
        } else {
            ComicCard(background: AppTheme.cream.opacity(0.78), padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    accountCardContent(showsChevron: false)

                    AppleSignInButton {
                        appState.signInCompleted(credential: $0)
                    } onFailure: {
                        appState.signInFailed($0)
                    } onStart: {
                        appState.suppressesPrivacyShieldForSystemAuth = true
                        appState.isScenePrivacyShieldVisible = false
                    }
                    .frame(height: 46)
                }
            }
        }
    }

    private func accountCardContent(showsChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "apple.logo")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 46, height: 46)
                .background(appState.isSignedInWithApple ? AppTheme.coin : AppTheme.divider.opacity(0.6))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

            VStack(alignment: .leading, spacing: 3) {
                Text(appState.isSignedInWithApple ? L10n.t("Apple ID 已连接") : L10n.t("连接 Apple ID"))
                    .font(.headline.weight(.black))
                Text(appState.isSignedInWithApple ? L10n.t("查看账号信息、退出登录和删除账号") : appState.appleAccountDetail)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineLimit(2)
            }
            Spacer()

            if appState.isSignedInWithApple {
                Text(L10n.t("已连接"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.coin.opacity(0.72))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var settingsList: some View {
        ComicCard(padding: 0) {
            VStack(spacing: 0) {
                NavigationLink {
                    SalarySettingsView(mode: .salary)
                } label: {
                    SettingsRow(icon: "yensign.circle.fill", title: L10n.t("薪资设置"), detail: appState.settings.salaryType.title)
                }
                NavigationLink {
                    SalarySettingsView(mode: .workTime)
                } label: {
                    SettingsRow(icon: "clock.fill", title: L10n.t("工作时间设置"), detail: "\(appState.settings.workStart.displayText)-\(appState.settings.workEnd.displayText)")
                }
                profileButton(.privacy)
                profileButton(.reminders)
                profileButton(.theme)
                profileButton(.language)
                widgetGuideButton
                profileButton(.data)
                profileButton(.help)
            }
        }
    }

    private var widgetGuideButton: some View {
        Button {
            showsWidgetGuide = true
        } label: {
            SettingsRow(icon: "rectangle.on.rectangle.angled", title: L10n.t("小组件指引"), detail: L10n.t("添加到桌面"))
        }
        .buttonStyle(.plain)
    }

    private var liveActivityCard: some View {
        LiveActivityControlCard(
            isAvailable: appState.hasEffectivePro && appState.isLiveActivityAvailable,
            isActive: appState.isLiveActivityActive,
            statusTitle: appState.snapshot.status.title,
            errorMessage: appState.hasEffectivePro ? appState.liveActivityErrorMessage : L10n.t("PRO 功能，开通后可在锁屏和灵动岛展示。")
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
        case .privacy:
            appState.preferences.appLockEnabled ? L10n.t("已开启") : L10n.t("未开启")
        case .reminders:
            profileRemindersStatusText
        case .theme:
            appState.hasEffectivePro ? "\(appState.preferences.selectedTheme.title) · \(appState.preferences.selectedAppIcon.title)" : "\(L10n.t("PRO 解锁")) · \(L10n.t("默认元气打工"))"
        case .language:
            appState.preferences.appLanguage.title
        default:
            sheet.detail
        }
    }

    private var profileRemindersStatusText: String {
        let enabledCount = [appState.preferences.remindersEnabled, appState.preferences.lunchRemindersEnabled].filter { $0 }.count
        switch enabledCount {
        case 0: return L10n.t("未开启")
        case 1: return L10n.t("已开启 1 项")
        default: return L10n.t("已开启 2 项")
        }
    }

}

private enum ProfileSheet: String, Identifiable {
    case pro
    case editProfile
    case privacy
    case reminders
    case theme
    case language
    case data
    case help
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pro: "crown.fill"
        case .editProfile: "pencil"
        case .privacy: "lock.shield.fill"
        case .reminders: "bell.fill"
        case .theme: "paintpalette.fill"
        case .language: "globe"
        case .data: "icloud.fill"
        case .help: "questionmark.circle.fill"
        case .about: "info.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .pro: L10n.t("开薪 PRO")
        case .editProfile: L10n.t("编辑资料")
        case .privacy: L10n.t("隐私与密码")
        case .reminders: L10n.t("开薪提醒")
        case .theme: L10n.t("主题")
        case .language: L10n.t("语言")
        case .data: L10n.t("数据与同步")
        case .help: L10n.t("帮助与反馈")
        case .about: L10n.t("关于开薪")
        }
    }

    var detail: String {
        switch self {
        case .pro: L10n.t("一次买断")
        case .editProfile: ""
        case .privacy: L10n.t("密码保护")
        case .reminders: ""
        case .theme: L10n.t("主题与 App 图标")
        case .language: L10n.t("自动跟随手机语言")
        case .data: L10n.t("本地保存")
        case .help: ""
        case .about: "v1.0"
        }
    }

    var bodyText: String {
        switch self {
        case .pro:
            L10n.t("PRO 是给高频打工人的增强包；一次开通后解锁 iCloud 同步、锁屏/灵动岛、密码保护、午休时间设置和 PRO 独享主题。实际价格以 App Store 付款页为准。")
        case .editProfile:
            L10n.t("修改昵称和个性签名后，会立刻保存在本机。")
        case .privacy:
            L10n.t("开启密码保护后，每次打开开薪都需要输入 4 位密码；进入多任务切换器时也会自动隐藏页面内容。")
        case .reminders:
            L10n.t("提醒功能会用于上班开薪、下班结算和午休暂停提示。首版先不主动申请通知权限，避免一打开就打扰你。")
        case .theme:
            L10n.t("主题控制 App、小组件、锁屏和灵动岛的视觉风格；App 图标可以单独选择，不和主题绑定。")
        case .language:
            L10n.t("默认跟随手机语言，也可以在这里固定为繁体中文、日文、英语或韩文。")
        case .data:
            L10n.t("免费版本地保存；PRO 可通过 iCloud 私有数据库自动同步，多设备使用时可以恢复设置。")
        case .help:
            L10n.t("计算规则：月薪按月薪 / 21.75 估算日薪，年薪按年薪 / 12 / 21.75，时薪按每日工作时长计算。默认周一到周五计薪。")
        case .about:
            L10n.t("PayJoy「开薪」v1.0。这个版本把实时收入、统计、小组件、PRO 同步和隐私保护整理成了正式首版。")
        }
    }
}

private struct ProfileAvatarImage: View {
    let name: String
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.avatarBackground(for: name))
            AssetImage(name: name)
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.outline, lineWidth: lineWidth))
    }
}

private struct ProfileDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let sheet: ProfileSheet
    @State private var showsProPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if sheet == .editProfile {
                    ProfileEditSheet()
                } else if sheet == .pro {
                    ProPaywallSheet()
                } else if sheet == .privacy {
                    PrivacySettingsSheet()
                } else if sheet == .theme {
                    ThemeSettingsSheet()
                } else if sheet == .language {
                    LanguageSettingsSheet()
                } else {
                    detailBody
                }
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成")) {
                        dismiss()
                    }
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.ink)
                }
            }
            .fullScreenCover(isPresented: $showsProPaywall) {
                ProPaywallSheet()
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
                    case .theme:
                        EmptyView()
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
        .padding(.bottom, 44)
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: sheet.icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 48, height: 48)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.4))
            VStack(alignment: .leading, spacing: 4) {
                Text(sheet.title)
                    .font(.title3.weight(.black))
                Text(sheetHeaderDetail)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var sheetHeaderDetail: String {
        switch sheet {
        case .reminders:
            remindersStatusText
        default:
            sheet.detail.isEmpty ? L10n.t("首版功能") : sheet.detail
        }
    }

    private var remindersStatusText: String {
        let enabledCount = [appState.preferences.remindersEnabled, appState.preferences.lunchRemindersEnabled].filter { $0 }.count
        switch enabledCount {
        case 0: return L10n.t("未开启")
        case 1: return L10n.t("已开启 1 项")
        default: return L10n.t("已开启 2 项")
        }
    }

    private var remindersControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            reminderToggleRow(
                title: L10n.t("上班 / 下班提醒"),
                subtitle: workReminderHelpText,
                isEnabled: appState.preferences.remindersEnabled,
                isAvailable: true,
                action: appState.setRemindersEnabled
            )

            Divider().overlay(AppTheme.divider)

            reminderToggleRow(
                title: L10n.t("午休提醒"),
                subtitle: lunchReminderHelpText,
                isEnabled: appState.preferences.lunchRemindersEnabled,
                isAvailable: appState.canUseLunchReminders,
                action: appState.setLunchRemindersEnabled
            )

            if appState.reminderPermissionState == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(L10n.t("打开系统通知设置"), systemImage: "gearshape.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.coin.opacity(0.65))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reminderToggleRow(
        title: String,
        subtitle: String,
        isEnabled: Bool,
        isAvailable: Bool,
        action: @escaping (Bool) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding {
                isEnabled
            } set: { newValue in
                action(newValue)
            }) {
                Text(title)
                    .font(.subheadline.weight(.heavy))
            }
            .tint(AppTheme.coin)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.55)

            Text(subtitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(isAvailable ? AppTheme.textGray : AppTheme.red)
                .lineSpacing(2)
        }
    }

    private var workReminderHelpText: String {
        if appState.preferences.remindersEnabled {
            return L10n.t("已安排周一到周五 \(appState.settings.workStart.displayText) 开薪、\(appState.settings.workEnd.displayText) 到账提醒。")
        }
        switch appState.reminderPermissionState {
        case .notDetermined:
            return L10n.t("开启时会自动请求系统通知权限。")
        case .denied:
            return L10n.t("系统通知权限已关闭，需要到设置里重新打开。")
        case .authorized, .provisional, .ephemeral:
            return L10n.t("通知权限可用，打开后会安排工作日提醒。")
        case .unknown:
            return L10n.t("通知权限状态未知，打开开关时会自动检查。")
        }
    }

    private var lunchReminderHelpText: String {
        guard appState.hasEffectivePro else {
            return L10n.t("午休提醒是 PRO 功能。")
        }
        guard appState.settings.deductLunch else {
            return L10n.t("请先在工作时间设置里开启午休时间。")
        }
        if appState.preferences.lunchRemindersEnabled {
            return L10n.t("已安排 \(appState.settings.lunchStart.displayText) 午休开始、\(appState.settings.lunchEnd.displayText) 午休结束提醒。")
        }
        switch appState.reminderPermissionState {
        case .denied:
            return L10n.t("系统通知权限已关闭，需要到设置里重新打开。")
        default:
            return L10n.t("打开后会在午休开始和午休结束时提醒。")
        }
    }

    private var dataControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(AppTheme.divider)
            HStack {
                ProfileInfoChip(title: "Apple ID", value: appState.isSignedInWithApple ? L10n.t("已连接") : L10n.t("未连接"))
                ProfileInfoChip(title: "iCloud", value: appState.cloudStatusText)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await appState.syncToCloud() }
                } label: {
                    Label(appState.isSyncing ? L10n.t("同步中") : L10n.t("上传 iCloud"), systemImage: "icloud.and.arrow.up")
                        .font(.caption.weight(.heavy))
                }
                .buttonStyle(.plain)
                .disabled(appState.isSyncing)

                Button {
                    Task { await appState.restoreFromCloud() }
                } label: {
                    Label(L10n.t("恢复"), systemImage: "icloud.and.arrow.down")
                        .font(.caption.weight(.heavy))
                }
                .buttonStyle(.plain)
                .disabled(appState.isSyncing)
            }
            .foregroundStyle(AppTheme.ink)

            Text(appState.syncMessage)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)

        }
    }

    private var legalControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Link(destination: PayJoyLegalLinks.privacy) {
                Label(L10n.t("隐私政策"), systemImage: "hand.raised.fill")
                    .font(.subheadline.weight(.heavy))
            }
            Link(destination: PayJoyLegalLinks.terms) {
                Label(L10n.t("服务条款"), systemImage: "doc.plaintext.fill")
                    .font(.subheadline.weight(.heavy))
            }
            Link(destination: PayJoyLegalLinks.support) {
                Label(L10n.t("支持与反馈"), systemImage: "questionmark.circle.fill")
                    .font(.subheadline.weight(.heavy))
            }
            Link(destination: PayJoyLegalLinks.deleteAccount) {
                Label(L10n.t("账号删除说明"), systemImage: "trash.fill")
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

private struct AccountManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showsSignOutConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var isDeletingAccount = false

    private var account: AppleAccount? {
        appState.appleAccount
    }

    private var identifierText: String {
        guard let id = account?.userIdentifier, !id.isEmpty else {
            return L10n.t("PJ-已连接")
        }
        let compactID = id.replacingOccurrences(of: "-", with: "")
        guard compactID.count > 8 else {
            return "PJ-\(compactID)"
        }
        return "PJ-\(compactID.prefix(4))-\(compactID.suffix(4))"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    accountInfoCard
                    syncCard
                    accountActionsCard
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 30)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("账号管理"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成")) {
                        dismiss()
                    }
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.ink)
                }
            }
            .alert(L10n.t("退出 Apple ID？"), isPresented: $showsSignOutConfirmation) {
                Button(L10n.t("取消"), role: .cancel) {}
                Button(L10n.t("退出"), role: .destructive) {
                    appState.signOutAppleID()
                    dismiss()
                }
            } message: {
                Text(L10n.t("退出后，本机数据会保留；需要同步或恢复时可以再次连接 Apple ID。"))
            }
            .alert(L10n.t("删除账号与数据？"), isPresented: $showsDeleteConfirmation) {
                Button(L10n.t("取消"), role: .cancel) {}
                Button(L10n.t("删除"), role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        await appState.deleteAccountAndLocalData()
                        isDeletingAccount = false
                        dismiss()
                    }
                }
            } message: {
                Text(L10n.t("这会退出 Apple ID，并删除本机保存的数据；若已连接 iCloud，也会尝试删除开薪的 iCloud 私有库记录。此操作不能撤销。"))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "apple.logo")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 54, height: 54)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.4))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Apple ID 已连接"))
                    .font(.title3.weight(.black))
                Text(L10n.t("账号信息、退出和删除都在这里。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }

            Spacer()
        }
    }

    private var accountInfoCard: some View {
        ComicCard(background: AppTheme.cream.opacity(0.86), padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("账户信息"))
                    .font(.headline.weight(.black))

                AccountInfoLine(title: L10n.t("昵称"), value: account?.fullName ?? appState.profile.displayNickname)
                AccountInfoLine(title: L10n.t("用户标识"), value: identifierText)
                AccountInfoLine(title: L10n.t("连接时间"), value: account?.signedInAt.localizedDateText ?? L10n.t("已连接"))
            }
        }
    }

    private var syncCard: some View {
        ComicCard(background: AppTheme.current == .midnight ? AppTheme.cream.opacity(0.86) : Color(hex: 0xE8F4EF), padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.t("同步状态"), systemImage: "icloud.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppTheme.ink)

                HStack {
                    ProfileInfoChip(title: "iCloud", value: appState.cloudStatusText)
                    ProfileInfoChip(title: "PRO", value: appState.hasEffectivePro ? L10n.t("已开通") : L10n.t("未开通"))
                }

                Text(appState.syncMessage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(2)
            }
        }
    }

    private var accountActionsCard: some View {
        ComicCard(background: AppTheme.cream.opacity(0.72), padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("账号操作"))
                    .font(.headline.weight(.black))

                Button {
                    showsSignOutConfirmation = true
                } label: {
                    Label(L10n.t("退出 Apple ID"), systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.red.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.red.opacity(0.55), lineWidth: 1))
                }
                .frame(minHeight: 44, alignment: .leading)
                .buttonStyle(.plain)
                .accessibilityHint(L10n.t("需要再次确认"))

                Divider().overlay(AppTheme.divider)

                Text(L10n.t("删除账号会清空本机数据，并尝试删除 iCloud 私有库里的开薪记录。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(3)

                HStack(spacing: 12) {
                    Link(destination: PayJoyLegalLinks.deleteAccount) {
                        Text(L10n.t("账号删除说明"))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(AppTheme.ink)
                    }

                    Spacer()

                    Button {
                        showsDeleteConfirmation = true
                    } label: {
                        Text(isDeletingAccount ? L10n.t("删除中") : L10n.t("删除账号"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.clear)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.red.opacity(0.45), lineWidth: 1))
                    }
                    .frame(minHeight: 44, alignment: .trailing)
                    .buttonStyle(.plain)
                    .disabled(isDeletingAccount)
                    .opacity(isDeletingAccount ? 0.5 : 1)
                    .accessibilityHint(L10n.t("需要再次确认"))
                }
            }
        }
    }
}

private struct AccountInfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppTheme.textGray)
                .frame(width: 62, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }
}

private struct WidgetGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ComicCard(background: AppTheme.current == .midnight ? AppTheme.cream.opacity(0.86) : Color(hex: 0xFFF7DD), padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            AssetImage(name: "widget_guide_preview_v1")
                                .frame(height: 166)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(AppTheme.outline, lineWidth: 1.2)
                                }

                            Text(L10n.t("把开薪小组件加到桌面"))
                                .font(.title3.weight(.black))
                            Text(L10n.t("不用打开 App，也能看到今日已赚、每秒回血和进度。"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textGray)
                                .lineSpacing(3)
                        }
                    }

                    ComicCard {
                        VStack(alignment: .leading, spacing: 12) {
                            WidgetGuideStep(number: "1", title: L10n.t("长按桌面空白处"), detail: L10n.t("等图标开始晃动后，点左上角的 +。"))
                            WidgetGuideStep(number: "2", title: L10n.t("搜索「开薪」"), detail: L10n.t("选择你喜欢的小组件尺寸。"))
                            WidgetGuideStep(number: "3", title: L10n.t("添加到桌面"), detail: L10n.t("拖到顺手的位置，今天赚多少一眼就知道。"))
                        }
                    }
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 32)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("小组件指引"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成")) {
                        dismiss()
                    }
                    .fontWeight(.heavy)
                    .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }
}

private struct WidgetGuideStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 34, height: 34)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.black))
                Text(detail)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ProfileEditSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var motto = ""
    @State private var selectedAvatar = UserProfile.defaultValue.avatarAssetName
    @State private var didLoad = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                ComicCard(background: AppTheme.highlightCardBackground) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("选择头像"))
                            .font(.headline.weight(.heavy))
                        Text(L10n.t("原创漫画头像，和主题、App 图标分开保存。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                            ForEach(UserProfile.avatarOptions, id: \.self) { avatar in
                                avatarButton(avatar)
                            }
                        }
                    }
                }

                ComicCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("昵称"))
                            .font(.headline.weight(.heavy))
                        TextField(L10n.t("打工人小开"), text: $nickname)
                            .textFieldStyle(.roundedBorder)

                        Text(L10n.t("个性签名"))
                            .font(.headline.weight(.heavy))
                        TextField(L10n.t("努力生活，开心开薪！"), text: $motto, axis: .vertical)
                            .lineLimit(2...3)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                PrimaryButton(title: L10n.t("保存资料")) {
                    appState.profile = UserProfile(
                        nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UserProfile.defaultValue.nickname : nickname,
                        motto: motto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UserProfile.defaultValue.motto : motto,
                        avatarAssetName: selectedAvatar
                    )
                    dismiss()
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 36)
        }
        .onAppear {
            guard !didLoad else { return }
            nickname = appState.profile.nickname
            motto = appState.profile.motto
            selectedAvatar = appState.profile.avatarAssetName
            didLoad = true
        }
    }

    private func avatarButton(_ avatar: String) -> some View {
        Button {
            selectedAvatar = avatar
        } label: {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatarImage(name: avatar, size: 66, lineWidth: selectedAvatar == avatar ? 2.4 : 1.2)
                    .shadow(color: AppTheme.shadow.opacity(0.14), radius: 0, x: 2, y: 2)

                if selectedAvatar == avatar {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 22, height: 22)
                        .background(AppTheme.coin)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1))
                        .offset(x: 2, y: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedAvatar == avatar ? L10n.t("当前头像") : L10n.t("选择头像"))
    }
}

private struct ThemeSettingsSheet: View {
    @Environment(AppState.self) private var appState
    @State private var showsIconChoices = false
    @State private var showsProPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                iconPicker

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(AppVisualTheme.allCases) { theme in
                        themeOption(theme)
                    }

                    Text(L10n.t("更多 PRO 主题敬请期待..."))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 36)
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
    }

    private var iconPicker: some View {
        ComicCard(background: AppTheme.cream, padding: 12) {
            VStack(spacing: 12) {
                Button {
                    if appState.hasEffectivePro {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            showsIconChoices.toggle()
                        }
                    } else {
                        showsProPaywall = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        AssetImage(name: appState.preferences.selectedAppIcon.previewAssetName)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.1)
                            }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t("App 图标"))
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                            Text(appState.preferences.selectedAppIcon.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textGray)
                        }

                        Spacer()

                        Image(systemName: appState.hasEffectivePro ? (showsIconChoices ? "chevron.up" : "chevron.down") : "lock.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(AppTheme.ink)
                    }
                }
                .buttonStyle(.plain)

                if showsIconChoices {
                    HStack(spacing: 12) {
                        ForEach(AppIconChoice.allCases) { icon in
                            appIconOption(icon)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    if let message = appState.appIconMessage {
                        Text(message)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if !appState.hasEffectivePro {
                    Text(L10n.t("App 图标属于 PRO 主题权益，未开通时保持默认元气图标。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func themeOption(_ theme: AppVisualTheme) -> some View {
        let isSelected = appState.preferences.selectedTheme == theme

        return Button {
            guard appState.hasEffectivePro else {
                if theme != .classic {
                    showsProPaywall = true
                }
                return
            }

            withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                var updatedPreferences = appState.preferences
                updatedPreferences.selectedTheme = theme
                appState.preferences = updatedPreferences
            }
        } label: {
            ThemeChoiceCard(theme: theme, isSelected: isSelected, isLocked: !appState.hasEffectivePro && theme != .classic)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? L10n.t("当前主题 \(theme.title)") : L10n.t("切换主题 \(theme.title)"))
    }

    private func appIconOption(_ icon: AppIconChoice) -> some View {
        let isSelected = appState.preferences.selectedAppIcon == icon

        return Button {
            guard appState.hasEffectivePro else {
                if icon != .classic {
                    showsProPaywall = true
                }
                return
            }
            appState.setAppIconChoice(icon)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                AssetImage(name: icon.previewAssetName)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(AppTheme.outline, lineWidth: isSelected ? 2 : 1.1)
                    }
                    .opacity(appState.hasEffectivePro || icon == .classic ? 1 : 0.44)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color(hex: 0x0B73D9))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.4))
                        .offset(x: 4, y: 4)
                } else if !appState.hasEffectivePro && icon != .classic {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 19, height: 19)
                        .background(AppTheme.ink.opacity(0.86))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.2))
                        .offset(x: 4, y: 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? L10n.t("当前 App 图标 \(icon.title)") : L10n.t("切换 App 图标 \(icon.title)"))
    }
}

private struct LanguageSettingsSheet: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                ComicCard(background: AppTheme.highlightCardBackground) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("选择语言"))
                            .font(.headline.weight(.heavy))
                        Text(L10n.t("默认跟随手机语言，也可以在这里固定为繁体中文、日文、英语或韩文。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineSpacing(2)
                    }
                }

                ComicCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                var preferences = appState.preferences
                                preferences.appLanguage = language
                                appState.preferences = preferences
                            } label: {
                                HStack(spacing: 12) {
                                    Text(language.shortTitle)
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(AppTheme.ink)
                                        .frame(width: 48, height: 36)
                                        .background(appState.preferences.appLanguage == language ? AppTheme.coin : AppTheme.paper.opacity(0.7))
                                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .stroke(AppTheme.outline, lineWidth: 1.1)
                                        }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(language.title)
                                            .font(.subheadline.weight(.black))
                                        if language == .system {
                                            Text("\(L10n.t("当前"))：\(AppLanguage.systemPreferred.title)")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(AppTheme.textGray)
                                        }
                                    }

                                    Spacer()

                                    if appState.preferences.appLanguage == language {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22, weight: .black))
                                            .foregroundStyle(AppTheme.coin)
                                    }
                                }
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if language != AppLanguage.allCases.last {
                                Divider().overlay(AppTheme.divider).padding(.leading, 74)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 36)
        }
        .background(AppTheme.paper.ignoresSafeArea())
    }
}

private struct ThemeChoiceCard: View {
    let theme: AppVisualTheme
    let isSelected: Bool
    var isLocked = false

    var body: some View {
        let usesDarkShell = AppTheme.current == .midnight
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(usesDarkShell ? AppTheme.cream.opacity(theme == .midnight ? 1 : 0.92) : theme.cardBackground)

            theme.backgroundDecoration
                .opacity(usesDarkShell && theme != .midnight ? 0.28 : 1)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            AssetImage(name: theme.previewAssetName)
                .frame(width: theme.previewSize.width, height: theme.previewSize.height)
                .scaleEffect(theme.previewScale, anchor: .bottomTrailing)
                .offset(theme.previewOffset)
                .opacity(isLocked ? 0.52 : 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(theme.displayTitle)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(usesDarkShell ? AppTheme.ink : theme.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(theme.subtitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle((usesDarkShell ? AppTheme.textGray : theme.textColor.opacity(0.72)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 18)
            .padding(.top, 16)

            HStack {
                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color(hex: 0x0B73D9))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.7))
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.ink.opacity(0.82))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 138)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderColor, lineWidth: isSelected ? 2.2 : 1.4)
        }
        .shadow(color: AppTheme.shadow.opacity(isSelected ? 0.15 : 0.08), radius: 1, x: 3, y: 3)
    }
}

private struct ThemeBackgroundDecoration: View {
    let theme: AppVisualTheme

    var body: some View {
        ZStack {
            switch theme {
            case .classic:
                LinearGradient(
                    colors: [Color(hex: 0xFFF6DA), Color(hex: 0xFFE3A4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(Color(hex: 0xFFD33D).opacity(0.55))
                        .frame(width: [8, 6, 10, 5, 7, 9][index], height: [28, 20, 24, 16, 18, 22][index])
                        .rotationEffect(.degrees(Double([20, -28, 36, -14, 48, -36][index])))
                        .offset(x: [-86, 22, 84, -12, 132, 54][index], y: [-48, -58, -20, 42, 42, 54][index])
                }
            case .pink:
                LinearGradient(
                    colors: [Color(hex: 0xFFE5F0), Color(hex: 0xFF9CC4), Color(hex: 0xFFDDE9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.34))
                        .frame(width: [54, 22, 34, 18, 42, 26][index])
                        .offset(x: [-128, -42, 122, 70, -4, 154][index], y: [-42, 48, -46, 48, -8, 10][index])
                }
            case .luckyCat:
                LinearGradient(
                    colors: [Color(hex: 0xFFE9E1), Color(hex: 0xFFD86A).opacity(0.56), Color(hex: 0xFFF7E8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: 0xFFD86A).opacity(0.42))
                        .frame(width: [18, 28, 12, 22, 16, 32, 13][index])
                        .overlay(Circle().stroke(AppTheme.outline.opacity(0.35), lineWidth: 1))
                        .offset(x: [-130, -66, 8, 70, 128, 150, -6][index], y: [-28, 44, -60, -22, 38, -46, 52][index])
                }
            case .midnight:
                LinearGradient(
                    colors: [Color(hex: 0x080D1A), Color(hex: 0x182846), Color(hex: 0x10172A)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 3) ? Color(hex: 0xFF758F) : Color(hex: 0x4FC0AB))
                        .frame(width: [4, 7, 3, 5, 8, 4, 6, 3][index])
                        .shadow(color: Color(hex: 0x4FC0AB).opacity(0.28), radius: 4)
                        .offset(x: [-142, -98, -44, 10, 62, 112, 148, 28][index], y: [-48, 36, -12, 48, -54, 20, -26, -62][index])
                }
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(Color(hex: 0x4FC0AB).opacity(0.12))
                        .frame(width: [92, 64, 112, 48][index], height: 1)
                        .offset(x: [-104, 82, 38, 146][index], y: [-18, -46, 50, 18][index])
                }
            }
        }
    }
}

private extension AppVisualTheme {
    var displayTitle: String {
        switch self {
        case .classic: L10n.t("元气打工")
        case .pink: L10n.t("粉桃通勤")
        case .luckyCat: L10n.t("招财喵喵")
        case .midnight: L10n.t("午夜打工台")
        }
    }

    var subtitle: String {
        switch self {
        case .classic: L10n.t("经典金币日常")
        case .pink: L10n.t("轻甜工作日")
        case .luckyCat: L10n.t("好运到账中")
        case .midnight: L10n.t("夜班灵感在线")
        }
    }

    var previewAssetName: String {
        switch self {
        case .classic: "worker_at_desk_v1"
        case .pink: "pink_worker_at_desk_v1"
        case .luckyCat: "lucky_cat_worker_at_desk_v1"
        case .midnight: "midnight_worker_at_desk_v1"
        }
    }

    var accentColor: Color {
        switch self {
        case .classic: Color(hex: 0xFFD33D)
        case .pink: Color(hex: 0xFF9CC4)
        case .luckyCat: Color(hex: 0xFFD86A)
        case .midnight: Color(hex: 0x4FC0AB)
        }
    }

    var cardBackground: Color {
        switch self {
        case .classic: Color(hex: 0xFFF4D3)
        case .pink: Color(hex: 0xFFD5E4)
        case .luckyCat: Color(hex: 0xFFE4DC)
        case .midnight: Color(hex: 0x10182B)
        }
    }

    var backgroundDecoration: ThemeBackgroundDecoration {
        ThemeBackgroundDecoration(theme: self)
    }

    var textColor: Color {
        self == .midnight ? Color(hex: 0xEDF4FF) : AppTheme.ink
    }

    var borderColor: Color {
        self == .midnight ? Color(hex: 0x4FC0AB).opacity(0.78) : AppTheme.ink.opacity(0.9)
    }

    var previewSize: CGSize {
        switch self {
        case .classic: CGSize(width: 176, height: 112)
        case .pink: CGSize(width: 172, height: 116)
        case .luckyCat: CGSize(width: 178, height: 116)
        case .midnight: CGSize(width: 184, height: 122)
        }
    }

    var previewScale: CGFloat {
        switch self {
        case .classic: 1.02
        case .pink: 1.08
        case .luckyCat: 1.12
        case .midnight: 1.08
        }
    }

    var previewOffset: CGSize {
        switch self {
        case .classic: CGSize(width: -10, height: 14)
        case .pink: CGSize(width: -4, height: 14)
        case .luckyCat: CGSize(width: -2, height: 14)
        case .midnight: CGSize(width: -2, height: 15)
        }
    }
}

private struct PrivacySettingsSheet: View {
    @Environment(AppState.self) private var appState
    @State private var firstPasscode = ""
    @State private var confirmPasscode = ""
    @State private var showsProPaywall = false

    private var canSavePasscode: Bool {
        firstPasscode.count == 4 && firstPasscode == confirmPasscode
    }

    private var helperText: String {
        if !appState.hasEffectivePro {
            return L10n.t("密码保护是 PRO 功能；多任务隐私遮罩会始终保护 App 预览。")
        }
        if appState.preferences.appLockEnabled {
            return L10n.t("下次打开 App 或从多任务切回来时，需要输入 4 位密码。")
        }
        if !confirmPasscode.isEmpty && firstPasscode != confirmPasscode {
            return L10n.t("两次输入不一致，请重新确认。")
        }
        return L10n.t("首次设置需要输入两遍 4 位数字密码。请记住它，当前版本暂不提供找回。")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                ComicCard(background: AppTheme.current == .midnight ? AppTheme.cream.opacity(0.86) : Color(hex: 0xE8F4EF)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L10n.t("多任务页面隐私保护"), systemImage: "rectangle.stack.badge.person.crop.fill")
                            .font(.headline.weight(.black))
                        Text(L10n.t("切到多任务页面时，开薪会自动盖上隐私遮罩，避免收入、进度和个人信息出现在系统预览里。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineSpacing(3)
                    }
                }

                ComicCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: 38, height: 38)
                                .background(appState.hasEffectivePro ? AppTheme.coin : AppTheme.divider)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.t("4 位密码保护"))
                                    .font(.headline.weight(.black))
                                Text(appState.hasEffectivePro ? L10n.t("PRO 已解锁") : L10n.t("PRO 功能"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textGray)
                            }
                            Spacer()
                        }

                        Text(helperText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(helperText.contains(L10n.t("不一致")) ? AppTheme.red : AppTheme.textGray)
                            .lineSpacing(3)

                        if appState.hasEffectivePro {
                            if appState.preferences.appLockEnabled {
                                PrimaryButton(title: L10n.t("关闭密码保护")) {
                                    appState.disableAppLock()
                                    firstPasscode = ""
                                    confirmPasscode = ""
                                }
                            } else {
                                VStack(spacing: 10) {
                                    passcodeInput(title: L10n.t("输入 4 位密码"), text: $firstPasscode)
                                    passcodeInput(title: L10n.t("再次确认密码"), text: $confirmPasscode)
                                }

                                PrimaryButton(title: L10n.t("开启密码保护")) {
                                    appState.setAppLockPasscode(firstPasscode)
                                    firstPasscode = ""
                                    confirmPasscode = ""
                                }
                                .disabled(!canSavePasscode)
                                .opacity(canSavePasscode ? 1 : 0.45)
                            }
                        } else {
                            PrimaryButton(title: L10n.t("开通 PRO 后启用")) {
                                showsProPaywall = true
                            }
                        }
                    }
                }

                bossKeyInfoCard
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 56)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
    }

    private var bossKeyInfoCard: some View {
        ComicCard(background: AppTheme.highlightCardBackground) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 38, height: 38)
                        .background(appState.hasEffectivePro ? AppTheme.coin : AppTheme.divider)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("老板键"))
                            .font(.headline.weight(.black))
                        Text(appState.hasEffectivePro ? L10n.t("PRO 已解锁") : L10n.t("PRO 功能"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }

                    Spacer()
                }

                Text(L10n.t("首页右上角公文包按钮可一键伪装成计算器。首次进入会显示退出指引，之后长按计算器上方数字显示区即可返回开薪。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(3)

                if !appState.hasEffectivePro {
                    PrimaryButton(title: L10n.t("开通 PRO 后使用老板键")) {
                        showsProPaywall = true
                    }
                }
            }
        }
    }

    private func passcodeInput(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppTheme.textGray)
            SecureField("0000", text: text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .foregroundStyle(AppTheme.ink)
                .background(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(0.86) : Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1.2)
                }
                .onChange(of: text.wrappedValue) { _, newValue in
                    let sanitized = String(newValue.filter(\.isNumber).prefix(4))
                    if sanitized != newValue {
                        text.wrappedValue = sanitized
                    }
                }
        }
    }
}

struct ProPaywallSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ProPaywallBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ProPaywallHeader {
                        dismiss()
                    }
                    ProPassCoverCard(isUnlocked: appState.hasEffectivePro, priceText: appState.proPriceText)
                    ProMissionBoard()
                    ProComingSoonCard()
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 122)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryButton(title: proButtonTitle) {
                    Task {
                        await appState.purchasePro()
                        if appState.hasEffectivePro {
                            dismiss()
                        }
                    }
                }
                .disabled(!appState.canPurchasePro)
                .opacity(appState.canPurchasePro ? 1 : 0.58)

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await appState.restoreProPurchases()
                            if appState.hasEffectivePro {
                                dismiss()
                            }
                        }
                    } label: {
                        Text(L10n.t("恢复购买"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white.opacity(appState.isPurchasingPro ? 0.42 : 0.92))
                            .frame(minWidth: 86, minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isPurchasingPro)

                    Rectangle()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 1, height: 14)

                    Text(L10n.t("非订阅，一次买断"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.72))

                    Spacer(minLength: 0)
                }

                Text(paywallFootnote)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Text(L10n.t("价格以 App Store 付款页为准"))
                    Text("·")
                    Link(destination: PayJoyLegalLinks.privacy) {
                        Text(L10n.t("隐私政策"))
                    }
                    Text("·")
                    Link(destination: PayJoyLegalLinks.terms) {
                        Text(L10n.t("服务条款"))
                    }
                }
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.54))
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background {
                LinearGradient(
                    colors: [
                        Color(hex: 0x092E31).opacity(0.96),
                        Color(hex: 0x071A20).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 1)
                }
                .ignoresSafeArea()
            }
        }
        .task {
            await appState.loadProProduct()
        }
    }

    private var proButtonTitle: String {
        if appState.hasEffectivePro {
            return L10n.t("PRO 已开通")
        }
        if appState.isPurchasingPro {
            return L10n.t("处理中...")
        }
        if appState.isLoadingProProduct {
            return L10n.t("正在加载价格...")
        }
        return L10n.t("\(appState.proPriceText) 一次买断开通")
    }

    private var paywallFootnote: String {
        if let message = appState.proPurchaseMessage {
            return message
        }
        return appState.hasEffectivePro ? L10n.t("感谢支持，PRO 权益已经生效。") : L10n.t("一次开通，当前版本所有 PRO 权益都可用。")
    }
}

private struct ProPaywallBackground: View {
    var body: some View {
        let isMidnight = AppTheme.current == .midnight
        ZStack {
            LinearGradient(
                colors: isMidnight
                    ? [Color(hex: 0x07101F), Color(hex: 0x0D2430), Color(hex: 0x11131F)]
                    : [Color(hex: 0x071A20), Color(hex: 0x073B3A), Color(hex: 0x1F1806)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(AppTheme.coin.opacity(isMidnight ? 0.12 : 0.28))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: 145, y: -260)
            Circle()
                .fill(Color(hex: 0x2F8F86).opacity(isMidnight ? 0.1 : 0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 36)
                .offset(x: -150, y: 300)
        }
        .ignoresSafeArea()
    }
}

private struct ProPaywallHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("开薪 PRO"))
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(L10n.t("一张打工人的系统通行证"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.coin)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(0.96) : Color.white.opacity(0.94))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.3))
                    .shadow(color: Color.black.opacity(0.24), radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("关闭开薪 PRO"))
        }
        .padding(.top, 6)
    }
}

private struct ProPassCoverCard: View {
    let isUnlocked: Bool
    let priceText: String

    var body: some View {
        let isMidnight = AppTheme.current == .midnight
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(isMidnight ? Color(hex: 0x172238) : Color(hex: 0xFFE8A3))
                .overlay {
                    LinearGradient(
                        colors: isMidnight
                            ? [Color.white.opacity(0.08), AppTheme.coin.opacity(0.34), AppTheme.orange.opacity(0.12)]
                            : [Color.white.opacity(0.32), AppTheme.coin.opacity(0.92), AppTheme.orange.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 2.35)
                }
                .shadow(color: AppTheme.coin.opacity(isMidnight ? 0.12 : 0.26), radius: 18, x: 0, y: 10)

            ProHalftonePattern()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PRO PASS")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(AppTheme.ink.opacity(0.68))
                        Text(isUnlocked ? L10n.t("已开通") : L10n.t("\(priceText) 一次买断"))
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(L10n.t("实时活动、隐私保护、老板键、同步、午休与主题资产一次解锁。"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink.opacity(0.68))
                            .lineSpacing(2)
                            .frame(maxWidth: 236, alignment: .leading)
                    }
                    Spacer()
                    ProSeal()
                        .frame(width: 70, height: 70)
                        .offset(x: 2, y: 0)
                }

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    ProPill(text: L10n.t("非订阅"))
                    ProPill(text: L10n.t("可恢复"))
                    ProPill(text: L10n.t("全部权益"))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)

            AssetImage(name: AppTheme.proPaywallWorkerAsset)
                .frame(width: 150, height: 112)
                .offset(x: 98, y: 58)

            ProTicketCutout()
                .frame(width: 24, height: 150)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 12)
        }
        .frame(height: 218)
        .accessibilityElement(children: .combine)
    }
}

private struct ProSeal: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(0.96) : Color.white.opacity(0.95))
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.45))

            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(AppTheme.coin)
                .frame(width: 48, height: 34)
                .rotationEffect(.degrees(-8))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1.2)
                        .rotationEffect(.degrees(-8))
                }

            Text("PRO")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .rotationEffect(.degrees(-8))

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.86))
                    .frame(width: [6, 4, 5][index])
                    .overlay(Circle().stroke(AppTheme.outline.opacity(0.55), lineWidth: 0.7))
                    .offset(x: [-23, 23, 8][index], y: [-20, -18, 23][index])
            }
        }
    }
}

private struct ProThemeStackIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(0.96) : Color.white.opacity(0.94))
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

            themeCard(color: Color(hex: 0xFFE8A3), icon: "sparkles", rotation: -12, offset: CGSize(width: -17, height: 10))
            themeCard(color: Color(hex: 0xFF9CC4), icon: "paintpalette.fill", rotation: 6, offset: CGSize(width: 5, height: -5))
            themeCard(color: Color(hex: 0xFFD86A), icon: "app.badge.fill", rotation: 17, offset: CGSize(width: 19, height: 13))
        }
    }

    private func themeCard(color: Color, icon: String, rotation: Double, offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(color)
            .frame(width: 42, height: 36)
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 1.1)
            }
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AppTheme.ink)
            }
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .shadow(color: Color.black.opacity(0.16), radius: 0, x: 1.5, y: 1.5)
    }
}

private struct ProTicketCutout: View {
    var body: some View {
        VStack(spacing: 18) {
            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .fill(Color(hex: 0x0A2E2D))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(AppTheme.outline.opacity(0.22), lineWidth: 1))
            }
        }
    }
}

private struct ProHalftonePattern: View {
    var body: some View {
        GeometryReader { proxy in
            let columns = 8
            let rows = 5
            ForEach(0..<(columns * rows), id: \.self) { index in
                let col = index % columns
                let row = index / columns
                Circle()
                    .fill(AppTheme.ink.opacity(0.08))
                    .frame(width: 7 + CGFloat((col + row) % 3) * 2, height: 7 + CGFloat((col + row) % 3) * 2)
                    .position(
                        x: proxy.size.width * 0.08 + CGFloat(col) * 35,
                        y: proxy.size.height * 0.18 + CGFloat(row) * 28
                    )
            }

            Path { path in
                path.move(to: CGPoint(x: proxy.size.width * 0.42, y: 42))
                path.addLine(to: CGPoint(x: proxy.size.width * 0.62, y: 65))
                path.move(to: CGPoint(x: proxy.size.width * 0.37, y: 78))
                path.addLine(to: CGPoint(x: proxy.size.width * 0.58, y: 104))
            }
            .stroke(AppTheme.outline.opacity(0.14), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }
}

private struct ProMissionBoard: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.cream.opacity(0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1.6)
                }
                .shadow(color: Color.black.opacity(0.16), radius: 0, x: 3, y: 3)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("PRO 权益任务板"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.t("开通后立即生效"))
                            .font(.caption2.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    Text("6/6")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.coin)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ProMissionItem(icon: "sparkles.rectangle.stack.fill", title: L10n.t("锁屏 / 灵动岛"), detail: L10n.t("实时收入"))
                    ProMissionItem(icon: "icloud.fill", title: L10n.t("iCloud 同步"), detail: L10n.t("换机恢复"))
                    ProMissionItem(icon: "lock.shield.fill", title: L10n.t("密码保护"), detail: L10n.t("隐私加锁"))
                    ProMissionItem(icon: "briefcase.fill", title: L10n.t("老板键"), detail: L10n.t("秒变计算器"))
                    ProMissionItem(icon: "cup.and.saucer.fill", title: L10n.t("午休时间"), detail: L10n.t("暂停计薪"))
                    ProMissionItem(icon: "paintpalette.fill", title: L10n.t("主题 / 图标"), detail: L10n.t("自由切换"))
                }
            }
            .padding(14)
        }
        .frame(height: 282)
    }
}

private struct ProMissionItem: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 30, height: 30)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(detail)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(0.82) : Color(hex: 0xF4EFE3))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.84), lineWidth: 1)
        }
    }
}

private struct ProComingSoonCard: View {
    var body: some View {
        let isMidnight = AppTheme.current == .midnight
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isMidnight ? [Color(hex: 0x10263B), Color(hex: 0x111A2E)] : [Color(hex: 0x0D4741), Color(hex: 0x172D20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.coin.opacity(isMidnight ? 0.55 : 0.85), lineWidth: 1.5)
                }
                .shadow(color: Color.black.opacity(0.18), radius: 0, x: 3, y: 3)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("PRO 主题已上线"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text(L10n.t("主题、App 图标和整套视觉装饰，开通后立即可切换。"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineSpacing(2)
                    HStack(spacing: 6) {
                        ProDarkPill(text: L10n.t("主题"))
                        ProDarkPill(text: L10n.t("图标"))
                        ProDarkPill(text: L10n.t("装饰"))
                    }
                }
                Spacer(minLength: 0)
                ProThemeStackIcon()
                    .frame(width: 92, height: 92)
                .rotationEffect(.degrees(7))
            }
            .padding(16)
        }
        .frame(height: 132)
    }
}

private struct ProDarkPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(AppTheme.coin)
            .clipShape(Capsule())
    }
}

private struct ProFeatureBento: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProFeatureTile(
                    icon: "sparkles.rectangle.stack.fill",
                    title: L10n.t("锁屏 / 灵动岛"),
                    subtitle: L10n.t("系统实时活动看收入"),
                    style: .hero
                )
                ProMiniComicPanel()
            }

            HStack(spacing: 8) {
                ProFeatureTile(icon: "icloud.fill", title: L10n.t("iCloud 同步"), subtitle: L10n.t("多设备恢复设置"))
                ProFeatureTile(icon: "lock.shield.fill", title: L10n.t("密码保护"), subtitle: L10n.t("4 位密码守隐私"))
                ProFeatureTile(icon: "cup.and.saucer.fill", title: L10n.t("午休时间"), subtitle: L10n.t("暂停计薪更准确"))
            }

            ProFutureBanner()
        }
    }
}

private struct ProMiniComicPanel: View {
    var body: some View {
        let isMidnight = AppTheme.current == .midnight
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isMidnight ? [Color(hex: 0x182640), Color(hex: 0x111A2E)] : [Color(hex: 0xF8DDE8), Color(hex: 0xFFEAF2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1.35)
                }

            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(AppTheme.coin)
                    .frame(width: [14, 10, 12, 9, 11][index], height: [14, 10, 12, 9, 11][index])
                    .overlay(Circle().stroke(AppTheme.outline.opacity(0.7), lineWidth: 1))
                    .offset(x: [-43, -20, 38, 46, 8][index], y: [-26, 20, -18, 20, -34][index])
            }

            AssetImage(name: AppTheme.moyuWorkerAsset)
                .frame(width: 116, height: 98)
                .offset(x: 4, y: 14)

            Text("PRO")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isMidnight ? AppTheme.softSurface.opacity(0.9) : Color.white.opacity(0.82))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                .offset(x: 34, y: -36)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 118)
        .shadow(color: Color.black.opacity(0.16), radius: 0, x: 2, y: 2)
    }
}

private struct ProFutureBanner: View {
    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(0.9) : Color.white.opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1.35)
                }

            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.coin)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("主题资产与未来新功能"))
                        .font(.subheadline.weight(.black))
                    Text(L10n.t("全部主题、图标、装饰，以及后续新增的 PRO 功能。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)

            ProLightningSticker()
                .frame(width: 58, height: 58)
                .offset(x: 12, y: -10)
        }
        .frame(height: 66)
        .shadow(color: Color.black.opacity(0.16), radius: 0, x: 2, y: 2)
    }
}

private struct ProHeroCard: View {
    let isUnlocked: Bool
    let priceText: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFFE3EE), AppTheme.coin, AppTheme.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 2.4)
                }
                .shadow(color: AppTheme.coin.opacity(0.36), radius: 18, x: 0, y: 10)

            ProComicBursts()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(isUnlocked ? L10n.t("PRO 已开通") : L10n.t("\(priceText) 一次买断"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text(L10n.t("同步、锁屏、密码、午休、主题和未来新功能全部打包。"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink.opacity(0.72))
                    .lineSpacing(2)
                    .frame(maxWidth: 220, alignment: .leading)
                HStack(spacing: 7) {
                    ProPill(text: L10n.t("隐私"))
                    ProPill(text: L10n.t("同步"))
                    ProPill(text: L10n.t("主题"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)

            AssetImage(name: AppTheme.proPaywallWorkerAsset)
                .frame(width: 136, height: 102)
                .offset(x: 8, y: 9)

            ProLightningSticker()
                .frame(width: 62, height: 62)
                .offset(x: -98, y: -82)
        }
        .frame(minHeight: 178)
    }
}

private struct ProComicBursts: View {
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Color.white.opacity(0.22) : AppTheme.coin.opacity(0.32))
                    .frame(width: [24, 12, 18, 9, 14, 20, 10][index], height: [24, 12, 18, 9, 14, 20, 10][index])
                    .overlay(Circle().stroke(AppTheme.outline.opacity(0.16), lineWidth: 1))
                    .offset(x: [-118, -72, 70, 112, -16, 32, -104][index], y: [-46, 44, -48, 34, -62, 48, 6][index])
            }

            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 68, y: 22))
                path.move(to: CGPoint(x: 14, y: -22))
                path.addLine(to: CGPoint(x: 78, y: -6))
                path.move(to: CGPoint(x: -10, y: 24))
                path.addLine(to: CGPoint(x: 56, y: 44))
            }
            .stroke(AppTheme.outline.opacity(0.12), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .offset(x: 148, y: 42)
        }
    }
}

private struct ProLightningSticker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(0.9) : Color.white.opacity(0.84))
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.15))
            Image(systemName: "bolt.fill")
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 42, height: 42)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.05))
        }
    }
}

private struct ProPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.black))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(0.72) : Color.white.opacity(0.58))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
    }
}

private struct ProFeatureTile: View {
    enum Style {
        case regular
        case hero
    }

    let icon: String
    let title: String
    let subtitle: String
    var style: Style = .regular

    var body: some View {
        VStack(alignment: .leading, spacing: style == .hero ? 10 : 7) {
            Image(systemName: icon)
                .font(.system(size: style == .hero ? 18 : 14, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: style == .hero ? 40 : 32, height: style == .hero ? 40 : 32)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: style == .hero ? 118 : 86, alignment: .topLeading)
        .padding(style == .hero ? 13 : 10)
        .background(AppTheme.current == .midnight ? AppTheme.softSurface.opacity(style == .hero ? 0.92 : 0.82) : (style == .hero ? Color(hex: 0xFFE6F0) : Color.white.opacity(0.94)))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.35)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 0, x: 2, y: 2)
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
                .stroke(AppTheme.outline, lineWidth: 1)
        }
    }
}

private struct AppleSignInButton: View {
    var onSuccess: (ASAuthorizationAppleIDCredential) -> Void
    var onFailure: (Error) -> Void
    var onStart: () -> Void

    @State private var coordinator = AppleSignInCoordinator()

    var body: some View {
        Button {
            onStart()
            coordinator.start(onSuccess: onSuccess, onFailure: onFailure)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .black))
                Text(L10n.t("通过 Apple 继续"))
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
    private static var languagePath: String {
        switch L10n.currentLanguage.resolved {
        case .zhHans:
            "zh-hans"
        case .zhHant:
            "zh-hant"
        case .en:
            "en"
        case .ja:
            "ja"
        case .ko:
            "ko"
        case .system:
            "zh-hans"
        }
    }

    private static func url(_ path: String) -> URL {
        URL(string: "https://sunzhengnj.github.io/PayJoy/\(languagePath)/\(path)")!
    }

    static var privacy: URL { url("privacy.html") }
    static var terms: URL { url("terms.html") }
    static var support: URL { url("support.html") }
    static var deleteAccount: URL { url("delete-account.html") }
}
