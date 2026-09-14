import SwiftUI
import UIKit
import AuthenticationServices
import StoreKit

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var activeSheet: ProfileSheet?
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false
    @State private var showsAccountManagement = false
    @State private var showsWidgetGuide = false
    @State private var showsClosingReceipts = false

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
        .defaultScrollAnchor(isLowerScreenshot ? .bottom : .top)
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
        .sheet(isPresented: $showsClosingReceipts) {
            NavigationStack {
                ClosingReceiptHistoryView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.paper)
        }
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsProPaywall = true
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
        .transaction { transaction in
            guard appState.preferences.reduceMotion || accessibilityReduceMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var profileHeader: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 14) {
                        ProfileAvatarImage(name: appState.profile.avatarAssetName, size: 72, lineWidth: 1.5)
                        Spacer(minLength: 8)
                        editProfileButton
                    }
                    Text(appState.profile.displayNickname)
                        .font(.title3.weight(.black))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(appState.profile.displayMotto)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
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
                    editProfileButton
                }
            }
        }
    }

    private var editProfileButton: some View {
        Button {
            activeSheet = .editProfile
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 44, height: 44)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.3))
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.92, reduceMotion: prefersReducedMotion))
        .accessibilityLabel(L10n.t("编辑资料"))
    }

    private var prefersReducedMotion: Bool {
        accessibilityReduceMotion || appState.preferences.reduceMotion
    }

    private var proCard: some View {
        Button {
            if appState.hasEffectivePro {
                showsProPaywall = true
            } else {
                showsMembershipPrompt = true
            }
        } label: {
            ComicCard(background: AppTheme.proCardBackground) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(proCardTitle)
                            .font(.title3.weight(.black))
                        Text(L10n.t("工资报告、同步、密码、午休和主题集中管理。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.t("查看详情"))
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
        .buttonStyle(PayJoyPressStyle())
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
            .buttonStyle(PayJoyPressStyle())
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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 12) {
                        appleAccountMark
                        Text(appState.isSignedInWithApple ? L10n.t("Apple ID 已连接") : L10n.t("连接 Apple ID"))
                            .font(.headline.weight(.black))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        if showsChevron {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(AppTheme.textGray)
                        }
                    }
                    Text(appState.isSignedInWithApple ? L10n.t("查看账号信息、退出登录和删除账号") : appState.appleAccountDetail)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    appleAccountMark

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
                        connectedBadge
                    }

                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(AppTheme.textGray)
                    }
                }
            }
        }
    }

    private var appleAccountMark: some View {
        Image(systemName: "apple.logo")
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(AppTheme.ink)
            .frame(width: 46, height: 46)
            .background(appState.isSignedInWithApple ? AppTheme.coin : AppTheme.divider.opacity(0.6))
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))
    }

    private var connectedBadge: some View {
        Text(L10n.t("已连接"))
            .font(.caption2.weight(.black))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.coin.opacity(0.72))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
    }

    private var settingsList: some View {
        VStack(spacing: 14) {
            SettingsGroup(title: L10n.t("工作与收入")) {
                NavigationLink {
                    SalarySettingsView(mode: .salary)
                } label: {
                    SettingsRow(title: L10n.t("薪资设置"), detail: appState.settings.salaryType.title)
                }
                .buttonStyle(SettingsRowButtonStyle())

                NavigationLink {
                    SalarySettingsView(mode: .workTime)
                } label: {
                    SettingsRow(title: L10n.t("工作时间设置"), detail: "\(appState.settings.workStart.displayText)-\(appState.settings.workEnd.displayText)")
                }
                .buttonStyle(SettingsRowButtonStyle())

                Button {
                    showsClosingReceipts = true
                } label: {
                    SettingsRow(title: L10n.t("收工回执"), detail: L10n.t("查看往日回执"))
                }
                .buttonStyle(SettingsRowButtonStyle())

                profileButton(.reminders, showsDivider: false)
            }

            SettingsGroup(title: L10n.t("外观与使用")) {
                profileButton(.displayEffects)
                profileButton(.theme)
                profileButton(.language)
                widgetGuideButton
            }

            SettingsGroup(title: L10n.t("隐私与支持")) {
                profileButton(.privacy)
                profileButton(.data)
                profileButton(.help, showsDivider: false)
            }
        }
    }

    private var widgetGuideButton: some View {
        Button {
            showsWidgetGuide = true
        } label: {
            SettingsRow(title: L10n.t("小组件指引"), detail: L10n.t("添加到桌面"), showsDivider: false)
        }
        .buttonStyle(SettingsRowButtonStyle())
    }

    private var liveActivityCard: some View {
        LiveActivityControlCard(
            isAvailable: appState.isLiveActivityAvailable,
            isActive: appState.isLiveActivityActive,
            statusTitle: appState.snapshot.status.title,
            errorMessage: appState.liveActivityErrorMessage
        ) {
            if appState.isLiveActivityActive {
                appState.endLiveActivity()
            } else {
                appState.startLiveActivity()
            }
        }
    }

    private func profileButton(_ sheet: ProfileSheet, showsDivider: Bool = true) -> some View {
        Button {
            activeSheet = sheet
        } label: {
            SettingsRow(title: sheet.title, detail: detailText(for: sheet), showsDivider: showsDivider)
        }
        .buttonStyle(SettingsRowButtonStyle())
    }

    private func detailText(for sheet: ProfileSheet) -> String {
        switch sheet {
        case .privacy:
            appState.preferences.appLockEnabled ? L10n.t("已开启") : L10n.t("未开启")
        case .reminders:
            profileRemindersStatusText
        case .displayEffects:
            appState.preferences.reduceMotion ? L10n.t("减少动态效果") : L10n.t("工作中显示金币雨")
        case .theme:
            appState.hasEffectivePro ? "\(appState.preferences.selectedTheme.title) · \(appState.preferences.selectedAppIcon.title)" : L10n.t("默认元气打工")
        case .language:
            appState.preferences.appLanguage.title
        case .data:
            dataSyncStatusText
        default:
            sheet.detail
        }
    }

    private var dataSyncStatusText: String {
        guard appState.hasEffectivePro else { return L10n.t("本地保存") }
        guard appState.isSignedInWithApple else { return L10n.t("未连接") }
        return appState.cloudStatusText
    }

    private var profileRemindersStatusText: String {
        let enabledCount = [appState.preferences.remindersEnabled, appState.preferences.lunchRemindersEnabled, appState.preferences.goalRemindersEnabled].filter { $0 }.count
        switch enabledCount {
        case 0: return L10n.t("未开启")
        case 1: return L10n.t("已开启 1 项")
        case 2: return L10n.t("已开启 2 项")
        default: return L10n.t("已开启 3 项")
        }
    }

    private var isLowerScreenshot: Bool {
        AppState.isScreenshotMode && ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] == "profile-lower"
    }

    private var proCardTitle: String {
        L10n.t("更多功能")
    }
}

enum ProfileSheet: String, Identifiable {
    case pro
    case editProfile
    case displayEffects
    case privacy
    case reminders
    case theme
    case language
    case data
    case help

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pro: "crown.fill"
        case .editProfile: "pencil"
        case .displayEffects: "sparkles"
        case .privacy: "lock.shield.fill"
        case .reminders: "bell.fill"
        case .theme: "paintpalette.fill"
        case .language: "globe"
        case .data: "icloud.fill"
        case .help: "questionmark.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .pro: L10n.t("开薪会员")
        case .editProfile: L10n.t("编辑资料")
        case .displayEffects: L10n.t("显示与动效")
        case .privacy: L10n.t("隐私与密码")
        case .reminders: L10n.t("开薪提醒")
        case .theme: L10n.t("主题")
        case .language: L10n.t("语言")
        case .data: L10n.t("数据与同步")
        case .help: L10n.t("帮助与反馈")
        }
    }

    var detail: String {
        switch self {
        case .pro: L10n.t("一次买断")
        case .editProfile: ""
        case .displayEffects: L10n.t("保留显示精度和动态效果的偏好。")
        case .privacy: L10n.t("密码保护")
        case .reminders: ""
        case .theme: L10n.t("主题与 App 图标")
        case .language: L10n.t("自动跟随手机语言")
        case .data: L10n.t("本地保存")
        case .help: ""
        }
    }

    var bodyText: String {
        switch self {
        case .pro:
            L10n.t("一次开通后可使用 iCloud 同步、锁屏与灵动岛、密码保护、午休时间和全部主题。实际价格以 App Store 付款页为准。")
        case .editProfile:
            L10n.t("修改昵称和个性签名后，会立刻保存在本机。")
        case .displayEffects:
            L10n.t("保留显示精度和动态效果的偏好。")
        case .privacy:
            L10n.t("开启密码保护后，每次打开开薪都需要输入 4 位密码；进入多任务切换器时也会自动隐藏页面内容。")
        case .reminders:
            L10n.t("提醒功能会用于上班开薪、下班结算、午休暂停和目标达成提示。默认关闭，只有你主动开启后才会请求通知权限。")
        case .theme:
            L10n.t("主题控制 App、小组件、锁屏和灵动岛的视觉风格；App 图标可以单独选择，不和主题绑定。")
        case .language:
            L10n.t("默认跟随手机语言，也可以在这里固定为繁体中文、日文、英语或韩文。")
        case .data:
            L10n.t("数据默认保存在本机，也可以通过 iCloud 在多台设备间同步和恢复设置。")
        case .help:
            L10n.t("计算规则：月薪按月薪 / 21.75 估算日薪，年薪按年薪 / 12 / 21.75，时薪按每日工作时长计算。默认周一到周五计薪。")
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

struct ProfileDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let sheet: ProfileSheet
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false
    @State private var showsClearLocalDataConfirmation = false
    @State private var showsCloudUploadConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if sheet == .editProfile {
                    ProfileEditSheet()
                } else if sheet == .pro {
                    ProPaywallSheet()
                } else if sheet == .privacy {
                    PrivacySettingsSheet()
                } else if sheet == .displayEffects {
                    DisplayEffectsSettingsSheet()
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
            .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
                showsProPaywall = true
            }
            .fullScreenCover(isPresented: $showsProPaywall) {
                ProPaywallSheet()
            }
            .alert(L10n.t("清除本机数据？"), isPresented: $showsClearLocalDataConfirmation) {
                Button(L10n.t("取消"), role: .cancel) {}
                Button(L10n.t("删除"), role: .destructive) {
                    Task { await appState.clearLocalData() }
                }
            } message: {
                Text(L10n.t("这会删除本机保存的薪资、记录、目标和设置，并退出 Apple ID。若曾同步到 iCloud，云端数据不会被删除，可在之后重新连接并恢复。"))
            }
            .alert(L10n.t("上传到 iCloud？"), isPresented: $showsCloudUploadConfirmation) {
                Button(L10n.t("取消"), role: .cancel) {}
                Button(L10n.t("上传并开启自动同步"), role: .destructive) {
                    Task { await appState.syncToCloud() }
                }
            } message: {
                Text(L10n.t("这会用这台设备上的数据替换 iCloud 中已有的开薪数据。确认后将开启自动同步。"))
            }
        }
    }

    private var detailBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                sheetHeader

                ComicCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(sheet.bodyText)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        switch sheet {
                        case .reminders:
                            remindersControls
                        case .theme:
                            EmptyView()
                        case .data:
                            dataControls
                        case .help:
                            legalControls
                        case .displayEffects:
                            EmptyView()
                        case .pro:
                            EmptyView()
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 44)
        }
    }

    private var sheetHeader: some View {
        Group {
            if sheet == .help {
                VStack(alignment: .leading, spacing: 5) {
                    Text("01 · \(sheet.title)")
                        .font(.title3.weight(.black))
                    Text(L10n.t("规则、支持与法律信息"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
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
        }
    }

    private var sheetHeaderDetail: String {
        switch sheet {
        case .reminders:
            remindersStatusText
        default:
            sheet.detail
        }
    }

    private var remindersStatusText: String {
        let enabledCount = [appState.preferences.remindersEnabled, appState.preferences.lunchRemindersEnabled, appState.preferences.goalRemindersEnabled].filter { $0 }.count
        switch enabledCount {
        case 0: return L10n.t("未开启")
        case 1: return L10n.t("已开启 1 项")
        case 2: return L10n.t("已开启 2 项")
        default: return L10n.t("已开启 3 项")
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
                isAvailable: !appState.hasEffectivePro || appState.canUseLunchReminders,
                action: { newValue in
                    if appState.hasEffectivePro {
                        appState.setLunchRemindersEnabled(newValue)
                    } else {
                        showsMembershipPrompt = true
                    }
                }
            )

            Divider().overlay(AppTheme.divider)

            reminderToggleRow(
                title: L10n.t("目标达成提醒"),
                subtitle: goalReminderHelpText,
                isEnabled: appState.preferences.goalRemindersEnabled,
                isAvailable: appState.personalGoal != nil,
                action: appState.setGoalRemindersEnabled
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
            return L10n.t("已安排 \(appState.settings.workdaySummary) \(appState.settings.workStart.displayText) 开薪、\(appState.settings.workEnd.displayText) 到账提醒。")
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
            return L10n.t("打开后会在午休开始和午休结束时提醒。")
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

    private var goalReminderHelpText: String {
        guard appState.personalGoal != nil else {
            return L10n.t("请先设置一个开薪目标。")
        }
        if appState.preferences.goalRemindersEnabled {
            return L10n.t("会在预计达成日的下班时间提醒你。")
        }
        switch appState.reminderPermissionState {
        case .notDetermined:
            return L10n.t("开启时会自动请求系统通知权限。")
        case .denied:
            return L10n.t("系统通知权限已关闭，需要到设置里重新打开。")
        default:
            return L10n.t("开启后会在预计目标达成时提醒。")
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
                    if !appState.hasEffectivePro {
                        showsMembershipPrompt = true
                    } else if appState.requiresCloudSyncSourceConfirmation {
                        showsCloudUploadConfirmation = true
                    } else {
                        Task { await appState.syncToCloud() }
                    }
                } label: {
                    Label(appState.isSyncing ? L10n.t("同步中") : L10n.t("上传 iCloud"), systemImage: "icloud.and.arrow.up")
                        .font(.caption.weight(.heavy))
                }
                .buttonStyle(.plain)
                .disabled((appState.hasEffectivePro && !canManuallySync) || appState.isSyncing)

                Button {
                    if appState.hasEffectivePro {
                        Task { await appState.restoreFromCloud() }
                    } else {
                        showsMembershipPrompt = true
                    }
                } label: {
                    Label(L10n.t("恢复"), systemImage: "icloud.and.arrow.down")
                        .font(.caption.weight(.heavy))
                }
                .buttonStyle(.plain)
                .disabled((appState.hasEffectivePro && !canManuallySync) || appState.isSyncing)
            }
            .foregroundStyle(AppTheme.ink)
            .opacity(appState.hasEffectivePro && !canManuallySync ? 0.45 : 1)

            Text(dataSyncMessage)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)

            Divider().overlay(AppTheme.divider)

            Button(role: .destructive) {
                showsClearLocalDataConfirmation = true
            } label: {
                Label(L10n.t("删除本机数据"), systemImage: "trash")
                    .font(.caption.weight(.heavy))
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.t("仅删除这台设备上的数据，不会删除 iCloud 记录。"))

        }
    }

    private var canManuallySync: Bool {
        appState.hasEffectivePro && appState.isSignedInWithApple
    }

    private var dataSyncMessage: String {
        guard appState.hasEffectivePro else {
            return L10n.t("在多台设备间同步设置和历史记录。")
        }
        guard appState.isSignedInWithApple else {
            return L10n.t("请先连接 Apple ID，再同步到 iCloud。")
        }
        return appState.syncMessage
    }

    private var legalControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                requestAppStoreReview()
            } label: {
                HStack(spacing: 10) {
                    Text("02")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.coin)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.outline, lineWidth: 1))
                        .dynamicTypeSize(.large)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("去 App Store 给开薪评分"))
                            .font(.subheadline.weight(.black))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.t("轻点即可打开系统评分"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(AppTheme.ink)
                .padding(12)
                .background(AppTheme.softSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            legalLink(index: "03", title: L10n.t("隐私政策"), destination: PayJoyLegalLinks.privacy)
            legalLink(index: "04", title: L10n.t("服务条款"), destination: PayJoyLegalLinks.terms)
            legalLink(index: "05", title: L10n.t("支持与反馈"), destination: PayJoyLegalLinks.support)
            legalLink(index: "06", title: L10n.t("账号删除说明"), destination: PayJoyLegalLinks.deleteAccount)
        }
        .foregroundStyle(AppTheme.ink)
    }

    private func legalLink(index: String, title: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(alignment: .center, spacing: 10) {
                Text(index)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textGray)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.softSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .dynamicTypeSize(.large)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.heavy))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    private func requestAppStoreReview() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }
        SKStoreReviewController.requestReview(in: windowScene)
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
    @State private var deletionResultMessage: String?

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
                    .disabled(isDeletingAccount)
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
                        deletionResultMessage = appState.syncMessage
                    }
                }
            } message: {
                Text(L10n.t("这会退出 Apple ID，并删除本机保存的数据；若已连接 iCloud，也会尝试删除开薪的 iCloud 私有库记录。此操作不能撤销。"))
            }
            .alert(
                L10n.t("删除结果"),
                isPresented: Binding(
                    get: { deletionResultMessage != nil },
                    set: { if !$0 { deletionResultMessage = nil } }
                )
            ) {
                Button(L10n.t("完成")) {
                    dismiss()
                }
            } message: {
                Text(deletionResultMessage ?? "")
            }
            .interactiveDismissDisabled(isDeletingAccount)
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

struct DisplayEffectsSettingsSheet: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(showsIndicators: false) {
            ComicCard(background: AppTheme.cream, padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("显示与动效"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.t("保留显示精度和动态效果的偏好。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }

                    displayToggle(
                        title: L10n.t("收入显示到分"),
                        subtitle: L10n.t("关闭后金额会省略小数。"),
                        keyPath: \.showDecimalCents
                    )

                    Divider().overlay(AppTheme.divider)

                    displayToggle(
                        title: L10n.t("工作中显示金币雨"),
                        subtitle: L10n.t("工作时显示背景金币动画；减少动态效果时会自动停用。"),
                        keyPath: \.showCoinRain
                    )

                    Divider().overlay(AppTheme.divider)

                    displayToggle(
                        title: L10n.t("减少动态效果"),
                        subtitle: L10n.t("关闭金币雨、数字弹跳和界面过渡动画。"),
                        keyPath: \.reduceMotion
                    )
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 36)
        }
    }

    private func displayToggle(
        title: String,
        subtitle: String,
        keyPath: WritableKeyPath<AppPreferences, Bool>
    ) -> some View {
        Toggle(isOn: preferenceBinding(keyPath)) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(2)
            }
        }
        .tint(AppTheme.coin)
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

private struct ThemeSettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var showsIconChoices = false
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                iconPicker
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(AppVisualTheme.allCases) { theme in
                        themeOption(theme)
                    }
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 36)
        }
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsProPaywall = true
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
    }

    private var iconPicker: some View {
        ComicCard(background: AppTheme.cream, padding: 12) {
            VStack(spacing: 12) {
                Button {
                    withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.86)) {
                        showsIconChoices.toggle()
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

                        Image(systemName: showsIconChoices ? "chevron.up" : "chevron.down")
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
                }
            }
        }
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private func themeOption(_ theme: AppVisualTheme) -> some View {
        let isSelected = appState.preferences.selectedTheme == theme

        return Button {
            guard appState.hasEffectivePro else {
                if theme != .classic {
                    showsMembershipPrompt = true
                } else {
                    applyTheme(theme)
                }
                return
            }
            applyTheme(theme)
        } label: {
            ThemeChoiceCard(theme: theme, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? L10n.t("当前主题 \(theme.title)") : L10n.t("切换主题 \(theme.title)"))
    }

    private func appIconOption(_ icon: AppIconChoice) -> some View {
        let isSelected = appState.preferences.selectedAppIcon == icon

        return Button {
            guard appState.hasEffectivePro else {
                if icon != .classic {
                    showsMembershipPrompt = true
                } else {
                    appState.setAppIconChoice(icon)
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

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color(hex: 0x0B73D9))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.4))
                        .offset(x: 4, y: 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? L10n.t("当前 App 图标 \(icon.title)") : L10n.t("切换 App 图标 \(icon.title)"))
    }

    private func applyTheme(_ theme: AppVisualTheme) {
        // Theme colors are global computed values. Keep the switch atomic so text remains readable.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            var updatedPreferences = appState.preferences
            updatedPreferences.selectedTheme = theme
            appState.preferences = updatedPreferences
        }
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
                            .accessibilityLabel(language.title)
                            .accessibilityValue(
                                appState.preferences.appLanguage == language
                                    ? L10n.t("已选择")
                                    : L10n.t("未选择")
                            )
                            .accessibilityAddTraits(
                                appState.preferences.appLanguage == language ? .isSelected : []
                            )

                            if language != AppLanguage.allCases.last {
                                Divider().overlay(AppTheme.divider).padding(.leading, 74)
                            }
                        }
                    }
                }

                ComicCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("地区语气与格式"))
                            .font(.headline.weight(.heavy))
                        Text(L10n.t("决定台湾、香港、日本或韩国的用词、日期与默认货币；不会修改你的工资金额。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)

                        Menu {
                            Button {
                                var preferences = appState.preferences
                                preferences.marketOverride = nil
                                appState.preferences = preferences
                            } label: {
                                Label(
                                    "\(L10n.t("跟随系统")) · \(AppMarket.systemResolved.title)",
                                    systemImage: appState.preferences.marketOverride == nil ? "checkmark" : "globe"
                                )
                            }

                            ForEach(AppMarket.allCases) { market in
                                Button {
                                    var preferences = appState.preferences
                                    preferences.marketOverride = market
                                    appState.preferences = preferences
                                } label: {
                                    Label(
                                        market.title,
                                        systemImage: appState.preferences.marketOverride == market ? "checkmark" : "mappin"
                                    )
                                }
                            }
                        } label: {
                            HStack {
                                Text(appState.preferences.marketOverride?.title ?? "\(L10n.t("跟随系统")) · \(AppMarket.systemResolved.title)")
                                    .font(.subheadline.weight(.black))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.black))
                            }
                            .foregroundStyle(AppTheme.ink)
                            .padding(13)
                            .background(AppTheme.softSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false

    private var canSavePasscode: Bool {
        firstPasscode.count == 4 && firstPasscode == confirmPasscode
    }

    private var hasPasscodeMismatch: Bool {
        firstPasscode.count == 4 && confirmPasscode.count == 4 && firstPasscode != confirmPasscode
    }

    private var helperText: String {
        if !appState.hasEffectivePro {
            return L10n.t("为打开 App 和从多任务返回增加 4 位密码保护。")
        }
        if appState.preferences.appLockEnabled {
            return L10n.t("下次打开 App 或从多任务切回来时，需要输入 4 位密码。")
        }
        if hasPasscodeMismatch {
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
                                .background(AppTheme.coin)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.t("4 位密码保护"))
                                    .font(.headline.weight(.black))
                            }
                            Spacer()
                        }

                        Text(helperText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(hasPasscodeMismatch ? AppTheme.red : AppTheme.textGray)
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
                            PrimaryButton(title: L10n.t("开启密码保护")) {
                                showsMembershipPrompt = true
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
        .payJoyKeyboardDismissToolbar()
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsProPaywall = true
        }
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
                        .background(AppTheme.coin)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("老板键"))
                            .font(.headline.weight(.black))
                    }

                    Spacer()
                }

                Text(L10n.t("首页右上角公文包按钮可一键伪装成计算器。首次进入会显示退出指引，之后长按计算器上方数字显示区即可返回开薪。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineSpacing(3)

                if !appState.hasEffectivePro {
                    PrimaryButton(title: L10n.t("使用老板键")) {
                        showsMembershipPrompt = true
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

enum ProPaywallContext: Equatable {
    case general
    case salaryReport

    var subtitle: String {
        switch self {
        case .general:
            L10n.t("让每天的世界，更像你喜欢的样子")
        case .salaryReport:
            L10n.t("把每个月的努力，变成看得见的战绩")
        }
    }

    var coverDescription: String {
        switch self {
        case .general:
            L10n.t("实际薪资、完整回执历史、额外语气和全部主题，一次开通。")
        case .salaryReport:
            L10n.t("四套主题工资报告、月度趋势和年度累计，一次解锁。")
        }
    }
}

struct ProPaywallSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let context: ProPaywallContext

    init(context: ProPaywallContext = .general) {
        self.context = context
    }

    var body: some View {
        ZStack {
            ProPaywallBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ProPassportArtwork {
                        dismiss()
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 6)
                .padding(.bottom, 136)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                primaryActionButton

                if let message = appState.proPurchaseMessage {
                    purchaseNotice(message)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        restorePurchaseButton

                        Rectangle()
                            .fill(Color.white.opacity(0.24))
                            .frame(width: 1, height: 14)

                        oneTimePurchaseLabel
                        Spacer(minLength: 0)
                    }

                    VStack(spacing: 2) {
                        restorePurchaseButton
                        oneTimePurchaseLabel
                    }
                    .frame(maxWidth: .infinity)
                }

                if appState.proPurchaseMessage == nil {
                    Text(paywallFootnote)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        finalPriceLabel
                        Text("·")
                        legalLinks
                    }

                    VStack(spacing: 3) {
                        finalPriceLabel
                        legalLinks
                    }
                }
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.54))
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .background {
                LinearGradient(
                    colors: [
                        Color(hex: 0x0B2430).opacity(0.96),
                        Color(hex: 0x07151D).opacity(0.98)
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
            .animation(prefersReducedMotion ? nil : .easeInOut(duration: 0.2), value: appState.proPurchaseMessage)
        }
        .task {
            appState.recordPaywallViewed()
            await appState.loadProProduct()
        }
        .sensoryFeedback(.success, trigger: appState.hasEffectivePro)
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private var primaryActionButton: some View {
        Button {
            Task {
                if appState.isProProductAvailable {
                    await appState.purchasePro()
                } else {
                    await appState.loadProProduct()
                }
                if appState.hasEffectivePro {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 10) {
                if isPrimaryActionBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.ink)
                        .accessibilityHidden(true)
                }
                Text(proButtonTitle)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xFFE27B), Color(hex: 0xFFC54A)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.58), lineWidth: 1)
            }
            .shadow(color: Color(hex: 0xFFC54A).opacity(0.24), radius: 13, x: 0, y: 6)
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
        .disabled(!appState.canStartProPrimaryAction)
        .opacity(appState.canStartProPrimaryAction ? 1 : 0.58)
        .accessibilityValue(isPrimaryActionBusy ? proButtonTitle : "")
    }

    private var isPrimaryActionBusy: Bool {
        appState.isLoadingProProduct || appState.isPurchasingPro
    }

    private func purchaseNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(appState.hasEffectivePro ? AppTheme.coin : AppTheme.orange)
                .frame(width: 4, height: 30)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var restorePurchaseButton: some View {
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
                .frame(minWidth: 86, minHeight: 44)
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
        .disabled(appState.isPurchasingPro)
    }

    private var oneTimePurchaseLabel: some View {
        Text(L10n.t("非订阅，一次买断"))
            .font(.caption.weight(.black))
            .foregroundStyle(.white.opacity(0.76))
            .multilineTextAlignment(.center)
    }

    private var finalPriceLabel: some View {
        Text(L10n.t("价格以 App Store 付款页为准"))
            .multilineTextAlignment(.center)
    }

    private var legalLinks: some View {
        HStack(spacing: 8) {
            Link(destination: PayJoyLegalLinks.privacy) {
                Text(L10n.t("隐私政策"))
            }
            Text("·")
            Link(destination: PayJoyLegalLinks.terms) {
                Text(L10n.t("服务条款"))
            }
        }
    }

    private var proButtonTitle: String {
        if appState.hasEffectivePro {
            return L10n.t("会员已开通")
        }
        if appState.isPurchasingPro {
            return L10n.t("处理中...")
        }
        if appState.isLoadingProProduct {
            return L10n.t("正在加载价格...")
        }
        if !appState.isProProductAvailable {
            return L10n.t("重新加载商品")
        }
        return L10n.t("\(appState.proPriceText) 一次买断开通")
    }

    private var paywallFootnote: String {
        if let message = appState.proPurchaseMessage {
            return message
        }
        return appState.hasEffectivePro ? L10n.t("感谢支持，会员权益已经生效。") : L10n.t("一次开通，当前版本所有会员权益都可用。")
    }
}

private struct ProPassportArtwork: View {
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("pro_passport_reference_v1")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 610, alignment: .top)
                .clipped()

            Button(action: onClose) {
                Color.clear
                    .frame(width: 66, height: 66)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .padding(.top, 8)
            .padding(.trailing, 8)
            .accessibilityLabel(L10n.t("关闭会员页面"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t("开薪权益：无限愿望、工资报告、实际薪资、完整回执历史、更多回执语气、iCloud 同步、密码保护、午休设置与提醒、老板键、全部主题与图标。"))
    }
}

private struct ProPaywallBackground: View {
    var body: some View {
        let isMidnight = AppTheme.current == .midnight
        ZStack {
            LinearGradient(
                colors: isMidnight
                    ? [Color(hex: 0x091224), Color(hex: 0x16254A), Color(hex: 0x0C302F)]
                    : [Color(hex: 0x091C2C), Color(hex: 0x0B4540), Color(hex: 0x172D49)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(hex: 0xFFD15A).opacity(isMidnight ? 0.12 : 0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 42)
                .offset(x: 150, y: -285)
            Circle()
                .fill(Color(hex: 0x7B9CFF).opacity(isMidnight ? 0.1 : 0.17))
                .frame(width: 310, height: 310)
                .blur(radius: 52)
                .offset(x: -165, y: 290)
        }
        .ignoresSafeArea()
    }
}

private struct ProPaywallHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        proTitle
                        Spacer()
                        closeButton
                    }
                    subtitleText
                }
            } else {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        proTitle
                        subtitleText
                    }
                    Spacer()
                    closeButton
                }
            }
        }
        .padding(.top, 6)
    }

    private var proTitle: some View {
        HStack(spacing: 8) {
            Text("薪")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: 0x073D3B))
                .frame(width: 30, height: 30)
                .background(AppTheme.coin)
                .clipShape(Circle())
            Text(L10n.t("开薪会员"))
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.caption.weight(.black))
            .foregroundStyle(AppTheme.coin)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Text("×")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Color.white.opacity(0.14))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("关闭会员页面"))
    }
}

private struct ProPassCoverCard: View {
    let isUnlocked: Bool
    let description: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            AssetImage(name: "pro_passport_cover_v1", contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 278)
                .clipped()

            LinearGradient(
                colors: [Color(hex: 0x052D2C).opacity(0.96), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("PAYJOY · LIFE PASS")
                    .font(.caption2.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.coin.opacity(0.88))
                Text(passTitle)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                Text(L10n.t("给努力一张长期通行证"))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.coin)
                Text(description)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(2)
                    .lineLimit(3)
                    .frame(maxWidth: 205, alignment: .leading)
                Spacer(minLength: 0)
                Text(L10n.t("一次买断，永久拥有"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color(hex: 0x073D3B))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(AppTheme.coin)
                    .clipShape(Capsule())
            }
            .padding(18)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            AssetImage(name: AppTheme.proPaywallWorkerAsset)
                .frame(width: 138, height: 104)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 8)
                .padding(.bottom, 2)
        }
        .frame(height: 278)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.coin.opacity(0.7), lineWidth: 1.2)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 18, x: 0, y: 10)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .combine)
    }

    private var passTitle: String {
        if isUnlocked {
            return L10n.t("会员已开通")
        }
        return L10n.t("人生加薪护照")
    }
}

private struct ProSalaryReportBenefitCard: View {
    var body: some View {
        ZStack(alignment: .leading) {
            AssetImage(name: AppTheme.salaryReportHeroAsset, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 156)
                .clipped()

            LinearGradient(
                colors: [
                    Color(hex: 0xFFF5DD).opacity(0.98),
                    Color(hex: 0xFFF5DD).opacity(0.86),
                    Color(hex: 0xFFF5DD).opacity(0.12)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.t("工资报告"))
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text(L10n.t("能量站、漫画战报、工资旅程"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.textGray)
                    .lineLimit(2)
                Text(L10n.t("真实工资数据，三种年轻化表达。"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.coin)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
            }
            .frame(maxWidth: 215, alignment: .leading)
            .padding(14)
        }
        .frame(height: 156)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.5)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 0, x: 3, y: 3)
        .accessibilityElement(children: .combine)
    }
}

private struct ProMissionBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("开薪权益"))
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text(L10n.t("解锁更完整的开薪体验"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("10 / 10")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color(hex: 0x073D3B))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.coin)
                    .clipShape(Capsule())
            }

            HStack(alignment: .center, spacing: 13) {
                Text("∞")
                    .font(.system(size: 39, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: 0x073D3B))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("愿望不设上限"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color(hex: 0x073D3B))
                    Text(L10n.t("免费版最多同时保留 2 个；会员不限。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: 0x315A55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color(hex: 0xFFE49A))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.coin.opacity(0.9), lineWidth: 1.2)
            }

            ProPassportBenefitPage(
                assetName: "pro_passport_benefits_left_v1",
                titles: [
                    L10n.t("无限愿望"),
                    L10n.t("实际薪资记录"),
                    L10n.t("更多回执语气"),
                    L10n.t("密码保护"),
                    L10n.t("老板键")
                ]
            )

            ProPassportBenefitPage(
                assetName: "pro_passport_benefits_right_v1",
                titles: [
                    L10n.t("工资报告"),
                    L10n.t("完整回执历史"),
                    L10n.t("iCloud 同步"),
                    L10n.t("午休设置与提醒"),
                    L10n.t("全部主题 / 图标")
                ]
            )
        }
    }
}

private struct ProPassportBenefitPage: View {
    let assetName: String
    let titles: [String]

    var body: some View {
        AssetImage(name: assetName, contentMode: .fit)
            .aspectRatio(0.75, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
                            Text(title)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: 0x173E3A))
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .padding(.horizontal, 40)
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(.vertical, proxy.size.height * 0.018)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.24), radius: 14, x: 0, y: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(titles.joined(separator: "、"))
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

            Text(L10n.t("会员"))
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
                    Text(L10n.t("全部主题、图标、装饰，以及后续新增的会员功能。"))
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
                Text(isUnlocked ? L10n.t("会员已开通") : L10n.t("\(priceText) 一次买断"))
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
            .fixedSize(horizontal: true, vertical: false)
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

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ComicCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Capsule()
                        .fill(AppTheme.coin)
                        .frame(width: 28, height: 7)
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                    Text(title)
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.textGray)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 13)
                .padding(.bottom, 6)

                content
            }
        }
    }
}

private struct SettingsRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let detail: String
    var showsDivider = true

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                titleText
                Spacer(minLength: 8)
                detailText
                disclosureMark
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    titleText
                    detailText
                }
                Spacer(minLength: 8)
                disclosureMark
            }
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(AppTheme.divider)
                    .frame(height: 0.7)
                    .padding(.leading, 14)
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var detailText: some View {
        if !detail.isEmpty {
            Text(detail)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.paper.opacity(0.72))
                .clipShape(Capsule())
        }
    }

    private var disclosureMark: some View {
        Text("›")
            .font(.system(size: 23, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.ink.opacity(0.78))
            .accessibilityHidden(true)
    }
}

private struct SettingsRowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.payJoyReduceMotion) private var appReduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? AppTheme.coin.opacity(0.14) : Color.clear)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(
                accessibilityReduceMotion || appReduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
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
