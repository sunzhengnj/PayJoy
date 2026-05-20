import SwiftUI
import UIKit

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
        ComicCard(background: Color(hex: 0xFFE7A3)) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("开薪 PRO")
                        .font(.title3.weight(.black))
                    Text("一次买断，永久使用")
                        .font(.caption.weight(.bold))
                }
                Spacer()
                AssetImage(name: "pro_sunglasses_worker_redraw_v1")
                    .frame(width: 104, height: 72)
            }
        }
    }

    private var settingsList: some View {
        ComicCard(padding: 0) {
            VStack(spacing: 0) {
                NavigationLink {
                    SalarySettingsView()
                } label: {
                    SettingsRow(icon: "yensign.circle.fill", title: "薪资设置", detail: appState.settings.salaryType.title)
                }
                NavigationLink {
                    SalarySettingsView()
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
    case editProfile
    case reminders
    case data
    case help
    case about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .editProfile: "pencil"
        case .reminders: "bell.fill"
        case .data: "icloud.fill"
        case .help: "questionmark.circle.fill"
        case .about: "info.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .editProfile: "编辑资料"
        case .reminders: "开薪提醒"
        case .data: "数据与同步"
        case .help: "帮助与反馈"
        case .about: "关于开薪"
        }
    }

    var detail: String {
        switch self {
        case .editProfile: ""
        case .reminders: "未开启"
        case .data: "本地保存"
        case .help: ""
        case .about: "v0.1"
        }
    }

    var bodyText: String {
        switch self {
        case .editProfile:
            "修改昵称和个性签名后，会立刻保存在本机。"
        case .reminders:
            "提醒功能会用于上班开薪、下班结算和午休暂停提示。首版先不主动申请通知权限，避免一打开就打扰你。"
        case .data:
            "当前薪资设置保存在本机 UserDefaults，不上传服务器。卸载 App 会清除本地数据。"
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

    var body: some View {
        NavigationStack {
            Group {
                if sheet == .editProfile {
                    ProfileEditSheet()
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
        }
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
