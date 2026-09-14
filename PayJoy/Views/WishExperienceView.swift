import LinkPresentation
import PhotosUI
import SwiftUI
import UIKit
@preconcurrency import Vision

private enum WishSheet: Identifiable {
    case capture
    case progress(WishExperience)
    case realization(WishExperience)

    var id: String {
        switch self {
        case .capture:
            "capture"
        case .progress(let wish):
            "progress-\(wish.id)"
        case .realization(let wish):
            "realization-\(wish.id)"
        }
    }
}

struct WishExperienceView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var presentedSheet: WishSheet?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if let wish = appState.focusedWish {
                    focusedWishCard(wish)
                    otherWishes(excluding: wish.id)
                } else {
                    emptyWishCard
                    otherWishes(excluding: nil)
                }

                archiveLink
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.top, 14)
            .padding(.bottom, 90)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            titleBlock
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(AppTheme.paper)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .capture:
                WishCaptureSheet()
                    .environment(appState)
            case .progress(let wish):
                WishProgressEditorSheet(wish: wish) { progress in
                    appState.updateWishProgress(id: wish.id, progress: progress)
                    presentedSheet = nil
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
            case .realization(let wish):
                WishRealizationSheet(wish: wish) { assetReference in
                    appState.completeWish(id: wish.id, realizedAssetReference: assetReference)
                    presentedSheet = nil
                }
            }
        }
        .transaction { transaction in
            guard prefersReducedMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var titleBlock: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    wishTitleCopy
                    captureWishButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    wishTitleCopy
                    Spacer(minLength: 8)
                    captureWishButton
                }
            }
        }
    }

    private var wishTitleCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t("愿望"))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("进度由你填写，节奏由你决定。"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
                .fixedSize(horizontal: false, vertical: true)
        }
        // The title is decorative wayfinding, while the wish cards carry the task content.
        // Keep it readable without letting the largest accessibility sizes consume the screen.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var captureWishButton: some View {
        Button {
            presentedSheet = .capture
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(AppTheme.ink)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(L10n.t("添加愿望"))
                    .font(.caption.weight(.black))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 13)
            .frame(minHeight: 44)
            .background(AppTheme.coin)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.5))
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
        .accessibilityLabel(L10n.t("添加愿望"))
    }

    private var prefersReducedMotion: Bool {
        accessibilityReduceMotion || appState.preferences.reduceMotion
    }

    private func focusedWishCard(_ wish: WishExperience) -> some View {
        ComicCard(background: AppTheme.cream, padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                WishCoverImage(wish: wish)
                    .frame(height: 172)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        Text(L10n.t(wish.archetype.titleKey))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.coin)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                            .padding(12)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Menu {
                            Button(L10n.t("暂停这个愿望"), systemImage: "pause.fill") {
                                appState.setWishStatus(id: wish.id, status: .paused)
                            }
                            Button(L10n.t("它已经发生了"), systemImage: "checkmark.seal.fill") {
                                presentedSheet = .realization(wish)
                            }
                        } label: {
                            Text(L10n.t("管理愿望"))
                                .font(.caption.weight(.black))
                                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(AppTheme.cream.opacity(0.94))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                        }
                        .padding(12)
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Text(wish.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    wishProgressSummary(wish, progress: wish.progress ?? 0)
                }
                .padding(14)
            }
        }
    }

    private func wishProgressSummary(_ wish: WishExperience, progress: Double) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.t("我的进度"))
                    .font(.subheadline.weight(.black))
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.title3.weight(.black))
                    .monospacedDigit()
            }

            ComicProgressBar(progress: progress)

            Text(L10n.t("由你填写，随时可以修改。"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)

            HStack(alignment: .center, spacing: 10) {
                if let targetAmount = wish.targetAmount, targetAmount > 0 {
                    let currencySymbol = wish.currencyCode?.displaySymbol ?? appState.settings.currencySymbol
                    let targetText = NSDecimalNumber(decimal: targetAmount).doubleValue.compactMoneyText(currencySymbol: currencySymbol)
                    Text(L10n.format("参考目标 %@", targetText))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer(minLength: 0)
                Button {
                    presentedSheet = .progress(wish)
                } label: {
                    Text(L10n.t("更新进度"))
                        .font(.caption.weight(.black))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 13)
                        .frame(height: 44)
                        .background(AppTheme.coin)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.2))
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
            }
        }
        .padding(12)
        .background(AppTheme.highlightCardBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    @ViewBuilder
    private func otherWishes(excluding focusedID: UUID?) -> some View {
        let wishes = appState.activeWishes.filter { $0.id != focusedID }
        if !wishes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("也在发光"))
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                ForEach(wishes) { wish in
                    Button {
                        appState.focusWish(id: wish.id)
                    } label: {
                        HStack(spacing: 12) {
                            WishCoverImage(wish: wish)
                                .frame(width: 88, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.outline, lineWidth: 1))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(wish.title)
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(AppTheme.ink)
                                    .lineLimit(2)
                                Text(L10n.format("当前进度 %d%%", Int(((wish.progress ?? 0) * 100).rounded())))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textGray)
                            }
                            Spacer()
                            Text(L10n.t("设为聚焦"))
                                .font(.caption.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(AppTheme.coin)
                                .clipShape(Capsule())
                        }
                        .padding(10)
                        .background(AppTheme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.outline, lineWidth: 1.3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyWishCard: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                AssetImage(name: "wish_journey_preview_v1", contentMode: .fill)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                Text(L10n.t("最近有什么东西，让你一想到就有点开心？"))
                    .font(.title3.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text(L10n.t("一句话、一张截图或一个链接就够了。价格和日期以后再说。"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                PrimaryButton(title: L10n.t("添加这个愿望")) {
                    presentedSheet = .capture
                }
            }
        }
    }

    @ViewBuilder
    private var archiveLink: some View {
        if !appState.archivedWishes.isEmpty {
            NavigationLink {
                WishArchiveView()
                    .environment(appState)
            } label: {
                HStack {
                    Label(L10n.t("已完成与已暂停"), systemImage: "tray.full")
                        .font(.subheadline.weight(.black))
                    Spacer()
                    Text("\(appState.archivedWishes.count)")
                        .font(.caption.weight(.black))
                }
                .foregroundStyle(AppTheme.ink)
                .padding(14)
                .background(AppTheme.softSurface)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppTheme.outline, lineWidth: 1.2))
            }
            .buttonStyle(.plain)
        }
    }

}

struct ScreenshotWishProgressEditorView: View {
    private let wish = WishExperience(
        title: L10n.t("去九寨沟看看秋天"),
        archetype: .journey,
        captureSource: .inspiration,
        targetAmount: 6_000,
        currencyCode: .CNY,
        manualProgress: 0.31
    )

    var body: some View {
        WishProgressEditorSheet(wish: wish) { _ in }
    }
}

struct ScreenshotWishRealizationView: View {
    private let wish = WishExperience(
        title: L10n.t("去九寨沟看看秋天"),
        archetype: .journey,
        captureSource: .inspiration
    )

    var body: some View {
        WishRealizationSheet(wish: wish) { _ in }
    }
}

private struct WishCoverImage: View {
    let wish: WishExperience

    var body: some View {
        Group {
            if let reference = wish.coverAssetReference,
               let image = WishAssetStore.image(for: reference) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                AssetImage(name: wish.archetype.builtInCoverAssetName, contentMode: .fill)
            }
        }
        .accessibilityLabel(wish.title)
    }
}

private struct WishProgressEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let wish: WishExperience
    let save: (Double) -> Void

    @State private var progressValue: Double
    @State private var progressText: String

    init(wish: WishExperience, save: @escaping (Double) -> Void) {
        let initialValue = min(100, max(0, (wish.progress ?? 0) * 100))
        self.wish = wish
        self.save = save
        _progressValue = State(initialValue: initialValue)
        _progressText = State(initialValue: String(Int(initialValue.rounded())))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(L10n.t("更新愿望进度"))
                            .font(.title3.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }

                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            wishProgressHeaderCopy
                        } else {
                            HStack(spacing: 12) {
                                WishCoverImage(wish: wish)
                                    .frame(width: 72, height: 72)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppTheme.outline, lineWidth: 1.2)
                                    }
                                wishProgressHeaderCopy
                            }
                        }
                    }

                    ComicCard(background: AppTheme.highlightCardBackground, padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            Group {
                                if dynamicTypeSize.isAccessibilitySize {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(L10n.t("进度百分比"))
                                            .font(.subheadline.weight(.black))
                                        progressValueField
                                    }
                                } else {
                                    HStack(alignment: .center) {
                                        Text(L10n.t("进度百分比"))
                                            .font(.subheadline.weight(.black))
                                        Spacer()
                                        progressValueField
                                    }
                                }
                            }

                            Slider(value: $progressValue, in: 0...100, step: 1)
                                .tint(AppTheme.coin)
                                .onChange(of: progressValue) { _, newValue in
                                    progressText = String(Int(newValue.rounded()))
                                }

                            if let targetAmount = wish.targetAmount, targetAmount > 0 {
                                let currencySymbol = wish.currencyCode?.displaySymbol ?? ""
                                let targetText = NSDecimalNumber(decimal: targetAmount).doubleValue.compactMoneyText(currencySymbol: currencySymbol)
                                Text(L10n.format("参考目标 %@", targetText))
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(AppTheme.ink)
                            }
                        }
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }

                    Text(L10n.t("这是你的记录，不会和工资或存款联动。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)

                    Button {
                        save(min(1, max(0, progressValue / 100)))
                        dismiss()
                    } label: {
                        Text(L10n.t("保存进度"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .padding(.vertical, 2)
                            .background(AppTheme.coin)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 24)
                .containerRelativeFrame(.horizontal)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(dynamicTypeSize.isAccessibilitySize ? "" : L10n.t("更新愿望进度"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("稍后再说")) { dismiss() }
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
            }
        }
        .payJoyKeyboardDismissToolbar()
    }

    private var wishProgressHeaderCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wish.title)
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("填写一个 0–100 的数字，记录你觉得自己走到了哪里。"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var progressValueField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            TextField("0", text: $progressText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .monospacedDigit()
                .frame(width: 76)
                .onChange(of: progressText) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(3))
                    if digits != newValue {
                        progressText = digits
                    }
                    if let value = Double(digits) {
                        progressValue = min(100, max(0, value))
                    }
                }
            Text("%")
                .font(.title2.weight(.black))
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background(AppTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.2)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

private struct WishRealizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let wish: WishExperience
    let complete: (String?) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var realizedImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Group {
                        if let realizedImage {
                            Image(uiImage: realizedImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            WishCoverImage(wish: wish)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 310)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.outline, lineWidth: 1.5)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text(L10n.t("这个愿望实现了"))
                            .font(.title2.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.t("可以留一张照片，给这份开心做个纪念。"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(
                            realizedImage == nil ? L10n.t("选择真实照片") : L10n.t("换一张照片"),
                            systemImage: "photo.badge.plus"
                        )
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .padding(.vertical, 2)
                        .background(AppTheme.softSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(AppTheme.outline, lineWidth: 1.2)
                        }
                    }
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                    if isLoading {
                        ProgressView()
                            .tint(AppTheme.ink)
                    }

                    PrimaryButton(title: L10n.t("标记为已实现")) {
                        let reference = realizedImage.flatMap(WishAssetStore.save)
                        complete(reference)
                        dismiss()
                    }

                    Button(L10n.t("先标记实现，照片以后再补")) {
                        complete(nil)
                        dismiss()
                    }
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.textGray)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 28)
                .containerRelativeFrame(.horizontal)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("愿望成真"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("取消")) { dismiss() }
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                isLoading = true
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    await MainActor.run {
                        realizedImage = data.flatMap(UIImage.init(data:))
                        isLoading = false
                    }
                }
            }
        }
    }
}

private struct WishArchiveView: View {
    @Environment(AppState.self) private var appState
    @State private var realizingWish: WishExperience?

    var body: some View {
        List {
            ForEach(appState.archivedWishes) { wish in
                WishArchiveCard(
                    wish: wish,
                    continueAction: {
                        appState.setWishStatus(id: wish.id, status: .active)
                        appState.focusWish(id: wish.id)
                    },
                    addPhotoAction: {
                        realizingWish = wish
                    }
                )
                .listRowBackground(AppTheme.paper)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.paper)
        .navigationTitle(L10n.t("愿望收藏"))
        .sheet(item: $realizingWish) { wish in
            WishRealizationSheet(wish: wish) { assetReference in
                appState.completeWish(id: wish.id, realizedAssetReference: assetReference)
                realizingWish = nil
            }
        }
    }
}

private struct WishArchiveCard: View {
    let wish: WishExperience
    let continueAction: () -> Void
    let addPhotoAction: () -> Void

    private var realizedImage: UIImage? {
        wish.realizedAssetReference.flatMap(WishAssetStore.image)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let realizedImage {
                    Image(uiImage: realizedImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    WishCoverImage(wish: wish)
                }
            }
            .frame(height: 188)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 1.3)
            }
            .accessibilityLabel(wish.title)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wish.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                    Text(L10n.t(wish.status == .completed ? "已经发生" : "暂时收好"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                }
                Spacer()
                archiveAction
            }
        }
        .padding(12)
        .background(AppTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.3)
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var archiveAction: some View {
        Group {
            if wish.status != .completed {
                Button(L10n.t("继续"), action: continueAction)
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.black))
            } else if realizedImage == nil {
                Button(L10n.t("补一张真实照片"), action: addPhotoAction)
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.black))
            } else {
                Text(L10n.t("已留照片"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
        .frame(minHeight: 44)
    }
}

private struct WishCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var text = ""
    @State private var selectedArchetype: WishArchetype?
    @State private var selectedItem: PhotosPickerItem?
    @State private var detectedImage: UIImage?
    @State private var captureSource: WishCaptureSource = .text
    @State private var sourceURL: URL?
    @State private var isRecognizing = false
    @State private var errorMessage: String?
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(L10n.t("最近有什么东西，让你一想到就有点开心？"))
                            .font(.title2.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.t("不用填写目标表。先把那个念头交给这里。"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }

                    TextField(L10n.t("比如：想去九寨沟看看"), text: $text, axis: .vertical)
                        .font(.body.weight(.bold))
                        .lineLimit(3...6)
                        .padding(15)
                        .background(AppTheme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.outline, lineWidth: 1.5))
                        .onSubmit { recognizeLinkIfNeeded() }

                    inspirationCards

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            captureButton(title: L10n.t("照片或截图"), systemImage: "photo")
                        }
                        Button {
                            if let pasted = UIPasteboard.general.string {
                                text = pasted
                                recognizeLinkIfNeeded()
                            }
                        } label: {
                            captureButton(title: L10n.t("粘贴链接"), systemImage: "link")
                        }
                        .buttonStyle(.plain)
                    }

                    if isRecognizing {
                        ProgressView(L10n.t("正在看懂这个愿望…"))
                            .tint(AppTheme.ink)
                            .font(.caption.weight(.bold))
                    }

                    if canPreview {
                        confirmationCard
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.red)
                    }
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 28)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("添加愿望"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("关闭")) { dismiss() }
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task { await recognize(item: item) }
            }
            .onChange(of: text) { _, _ in
                sourceURL = firstURL(in: text)
                if sourceURL != nil {
                    captureSource = .link
                }
            }
            .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
                showsProPaywall = true
            }
            .fullScreenCover(isPresented: $showsProPaywall) {
                ProPaywallSheet()
            }
        }
    }

    private var cleanedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedArchetype: WishArchetype {
        selectedArchetype ?? WishArchetype.classify(cleanedText)
    }

    private var canPreview: Bool {
        !cleanedText.isEmpty || detectedImage != nil
    }

    private var inspirationCards: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.t("也可以从一种心动开始"))
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.textGray)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                inspirationButton(.possession, prompt: L10n.t("我想拥有的东西"))
                inspirationButton(.journey, prompt: L10n.t("我想去的地方"))
                inspirationButton(.growth, prompt: L10n.t("我想成为的样子"))
                inspirationButton(.generic, prompt: L10n.t("一个小小的期待"))
            }
        }
    }

    private func inspirationButton(_ archetype: WishArchetype, prompt: String) -> some View {
        Button {
            selectedArchetype = archetype
            captureSource = .inspiration
            if cleanedText.isEmpty {
                text = prompt
            }
        } label: {
            Text(prompt)
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 8)
                .background(selectedArchetype == archetype ? AppTheme.coin : AppTheme.softSurface)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.outline, lineWidth: 1.1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(prompt)
        .accessibilityValue(selectedArchetype == archetype ? L10n.t("已选择") : L10n.t("未选择"))
        .accessibilityAddTraits(selectedArchetype == archetype ? .isSelected : [])
    }

    private func captureButton(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.black))
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8)
            .background(AppTheme.softSurface)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.outline, lineWidth: 1.1))
    }

    private var confirmationCard: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
            VStack(alignment: .leading, spacing: 13) {
                Group {
                    if let detectedImage {
                        Image(uiImage: detectedImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        AssetImage(name: resolvedArchetype.builtInCoverAssetName, contentMode: .fill)
                    }
                }
                .frame(height: 196)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.outline, lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t(resolvedArchetype.titleKey))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.textGray)
                    Text(cleanedText.isEmpty ? L10n.t("这张图里的愿望") : cleanedText)
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(3)
                }

                PrimaryButton(title: L10n.t("就是这个")) {
                    createWish()
                }
            }
        }
    }

    private func recognizeLinkIfNeeded() {
        guard let url = firstURL(in: text) else { return }
        sourceURL = url
        captureSource = .link
        isRecognizing = true
        Task {
            let provider = LPMetadataProvider()
            if let metadata = try? await provider.startFetchingMetadata(for: url),
               let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                await MainActor.run {
                    text = title
                }
            }
            await MainActor.run {
                isRecognizing = false
            }
        }
    }

    @MainActor
    private func recognize(item: PhotosPickerItem) async {
        isRecognizing = true
        defer { isRecognizing = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = L10n.t("没有读到图片，请换一张试试。")
            return
        }
        detectedImage = image
        if let recognized = await WishImageRecognizer.recognizeText(in: image),
           !recognized.isEmpty {
            captureSource = .screenshot
            text = recognized
        } else {
            captureSource = .photo
        }
    }

    private func createWish() {
        guard appState.canCreateWish else {
            showsMembershipPrompt = true
            return
        }
        let title = cleanedText.isEmpty ? L10n.t("这张图里的愿望") : cleanedText
        let reference = detectedImage.flatMap(WishAssetStore.save)
        guard appState.createWish(
            title: title,
            archetype: resolvedArchetype,
            captureSource: captureSource,
            sourceURL: sourceURL,
            coverAssetReference: reference
        ) != nil else {
            errorMessage = L10n.t("这个愿望还没收好，请再试一次。")
            return
        }
        dismiss()
    }

    private func firstURL(in value: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(value.startIndex..., in: value)
        return detector.firstMatch(in: value, options: [], range: range)?.url
    }
}

private enum WishAssetStore {
    private static var directory: URL? {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = root.appendingPathComponent("WishCovers", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func save(_ image: UIImage) -> String? {
        let maxSide: CGFloat = 1_600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.82),
              let directory else {
            return nil
        }
        let name = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(for reference: String) -> UIImage? {
        guard let directory else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(reference).path)
    }
}

private enum WishImageRecognizer {
    static func recognizeText(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .prefix(3)
                    .joined(separator: " ")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
