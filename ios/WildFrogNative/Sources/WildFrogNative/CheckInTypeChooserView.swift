import SwiftUI

enum CheckInTypeChoice: Equatable {
    case ranked
    case freePhoto
    case trip
}

struct CheckInTypeChooserState: Equatable {
    private(set) var isPresented = false
    private(set) var previousTab: AppTab
    private var pendingChoice: CheckInTypeChoice?

    init(previousTab: AppTab = .home) {
        self.previousTab = previousTab
    }

    mutating func present(from tab: AppTab? = nil) {
        if let tab { previousTab = tab }
        pendingChoice = nil
        isPresented = true
    }

    mutating func dismissWithoutSelection() {
        pendingChoice = nil
        isPresented = false
    }

    mutating func select(_ choice: CheckInTypeChoice) {
        pendingChoice = choice
        isPresented = false
    }

    mutating func consumePendingChoice() -> CheckInTypeChoice? {
        defer { pendingChoice = nil }
        return pendingChoice
    }
}

struct CheckInTypeChooserView: View {
    let onSelect: (CheckInTypeChoice) -> Void
    let onDismiss: () -> Void
    let onCancel: () -> Void
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(FrogTheme.ink.opacity(0.16))
                .frame(width: 38, height: 5)
                .padding(.top, 10)

            VStack(spacing: 5) {
                Text(AppText.value(zh: "今次想做咩？", en: "What are you doing today?"))
                    .font(.frogTitle.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                Text(AppText.value(zh: "打卡、自由拍照，或者淨係記錄行程", en: "Check in, take a free photo, or simply record a trip"))
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    onSelect(.ranked)
                } label: {
                    choiceRow(
                        title: AppText.value(zh: "排行榜打卡", en: "Ranked Check-In"),
                        detail: AppText.value(zh: "指定山峰附近 · 加入紀錄及排行榜", en: "Near a listed peak · Adds to records and rankings"),
                        systemImage: "checkmark.seal.fill",
                        iconColor: FrogTheme.orange,
                        titleColor: FrogTheme.ink,
                        detailColor: FrogTheme.muted,
                        backgroundColor: FrogTheme.orangeSoft,
                        borderColor: FrogTheme.moss.opacity(0.3)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onSelect(.freePhoto)
                } label: {
                    choiceRow(
                        title: AppText.value(zh: "自由拍照", en: "Free Photo"),
                        detail: AppText.value(zh: "任何地方影相 · 自訂地名 · 不計排名", en: "Shoot anywhere · Custom place name · No ranking score"),
                        systemImage: "camera.fill",
                        iconColor: FreePhotoPalette.blue,
                        titleColor: FreePhotoPalette.navy,
                        detailColor: FreePhotoPalette.navy.opacity(0.62),
                        backgroundColor: FreePhotoPalette.mist,
                        borderColor: FreePhotoPalette.blue.opacity(0.28)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onSelect(.trip)
                } label: {
                    choiceRow(
                        title: AppText.value(zh: "記錄行程", en: "Record a Trip"),
                        detail: AppText.value(zh: "毋須打卡 · GPS 軌跡及裝備清單", en: "No check-in required · GPS route and packing list"),
                        systemImage: "figure.hiking",
                        iconColor: FrogTheme.moss,
                        titleColor: FrogTheme.forest,
                        detailColor: FrogTheme.muted,
                        backgroundColor: FrogTheme.leaf.opacity(0.13),
                        borderColor: FrogTheme.moss.opacity(0.25)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FrogSpace.screenPadding)

            Button(AppText.value(zh: "取消", en: "Cancel"), action: onCancel)
                .font(.frogRow.weight(.bold))
                .foregroundStyle(FrogTheme.muted)
                .padding(.top, 2)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(FrogTheme.paper)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 30,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 30,
            style: .continuous
        ))
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { dragOffset = max(0, $0.translation.height) }
                .onEnded { value in
                    if value.translation.height > 80 || value.predictedEndTranslation.height > 160 {
                        onDismiss()
                    }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        dragOffset = 0
                    }
                }
        )
    }

    private func choiceRow(
        title: String,
        detail: String,
        systemImage: String,
        iconColor: Color,
        titleColor: Color,
        detailColor: Color,
        backgroundColor: Color,
        borderColor: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.frogRow.weight(.black))
                    .foregroundStyle(titleColor)
                Text(detail)
                    .font(.frogCaption)
                    .foregroundStyle(detailColor)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(titleColor.opacity(0.52))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
