import SwiftUI
#if canImport(UIKit)
import Photos
import UIKit
#endif

struct CheckInCameraView: View {
    let mountain: Mountain

    @Environment(\.dismiss) private var dismiss
    @State private var isSavingWatermark = false
    @State private var saveMessage: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                MountainPhoto(mountain: mountain, dimming: 0)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.22),
                        Color.black.opacity(0.02),
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 18) {
                    checkInTopBar(topInset: proxy.safeAreaInsets.top)
                    statusStrip
                    Spacer()
                    checkInBottomSheet
                        .padding(.bottom, 98)
                }
                .padding(.horizontal, FrogSpace.screenPadding)
            }
        }
        .hiddenNavigationBar()
        .background(FrogTheme.warmPaper)
    }

    private func checkInTopBar(topInset: CGFloat) -> some View {
        HStack(alignment: .top) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.white.opacity(0.22), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("關閉")

            Spacer()

            HStack(spacing: 9) {
                WildFrogBrandMark(size: 32, cornerRadius: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WildFrog")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.forest)
                    Text("山系足跡 · 香港山峰護照")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.forest.opacity(0.72))
                }
            }
            .padding(.top, 6)

            Spacer()

            Color.clear
                .frame(width: 54, height: 54)
        }
        .padding(.top, topInset + 8)
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            CheckInStatusChip(systemImage: "mappin.circle.fill", title: "GPS Ready", subtitle: nil)
            CheckInStatusChip(systemImage: "mountain.2", title: "\(mountain.height)m", subtitle: "summit")
            CheckInStatusChip(systemImage: "sun.max", title: "Weather", subtitle: "Clear")
        }
    }

    private var watermarkPreview: some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: mountain, dimming: 0.34)
            VStack(alignment: .leading, spacing: 2) {
                Text("WILDFROG")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                Text("\(mountain.nameZh) · \(mountain.height)m")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .padding(8)
        }
        .frame(width: 154, height: 102)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var checkInBottomSheet: some View {
        VStack(alignment: .leading, spacing: 15) {
            Capsule()
                .fill(FrogTheme.line)
                .frame(width: 46, height: 5)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(mountain.nameZh)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(FrogTheme.ink)
                            .lineLimit(1)
                        Image(systemName: "mountain.2.circle")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(FrogTheme.slate)
                    }

                    Text(mountain.nameEn)
                        .font(.frogTitle)
                        .foregroundStyle(FrogTheme.forest)
                        .lineLimit(1)
                    Text("\(mountain.height)m")
                        .font(.frogTitle)
                        .foregroundStyle(FrogTheme.forest)

                    HStack(spacing: 8) {
                        CheckInConfidencePill(systemImage: "checkmark.shield.fill", text: "位置吻合")
                        Text("·")
                            .foregroundStyle(FrogTheme.muted)
                        Text("信心度")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.muted)
                        Text("高")
                            .font(.frogCaption.weight(.black))
                            .foregroundStyle(FrogTheme.moss)
                    }
                    .padding(.top, 6)

                    Text("根據 GPS、海拔及方向核對")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Watermark Preview")
                        .font(.frogCaption.weight(.black))
                        .foregroundStyle(FrogTheme.forest)
                    watermarkPreview
                }
            }

            Button {
                saveWatermarkImage()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .black))
                        .frame(width: 46, height: 46)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    Text(isSavingWatermark ? "正在儲存..." : "完成打卡")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 66)
                .primaryCTAStyle(cornerRadius: 24)
            }
            .buttonStyle(.plain)
            .disabled(isSavingWatermark)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text(saveMessage ?? "打卡後將生成水印圖並儲存到相簿")
            }
            .font(.frogCaption.weight(.semibold))
            .foregroundStyle(FrogTheme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(FrogTheme.warmPaper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: -4)
    }

    @MainActor
    private func saveWatermarkImage() {
        #if canImport(UIKit)
        guard let image = renderWatermarkImage() else {
            saveMessage = "未能生成水印圖，請再試一次。"
            return
        }

        isSavingWatermark = true
        saveMessage = nil

        Task {
            let status = await requestPhotoAddPermission()
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isSavingWatermark = false
                    saveMessage = "未獲相簿儲存權限。"
                }
                return
            }

            do {
                try await saveToPhotoLibrary(image)
                await MainActor.run {
                    isSavingWatermark = false
                    saveMessage = "已儲存水印圖到相簿。"
                }
            } catch {
                await MainActor.run {
                    isSavingWatermark = false
                    saveMessage = "儲存失敗：\(error.localizedDescription)"
                }
            }
        }
        #else
        saveMessage = "此平台暫不支援儲存到相簿。"
        #endif
    }

    #if canImport(UIKit)
    @MainActor
    private func renderWatermarkImage() -> UIImage? {
        let renderer = ImageRenderer(
            content: CheckInWatermarkExportView(mountain: mountain)
                .frame(width: 1080, height: 1080)
        )
        renderer.scale = 1
        return renderer.uiImage
    }

    private func requestPhotoAddPermission() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func saveToPhotoLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WatermarkSaveError.unknown)
                }
            }
        }
    }
    #endif
}

#if canImport(UIKit)
private enum WatermarkSaveError: LocalizedError {
    case unknown

    var errorDescription: String? {
        "未能寫入相簿。"
    }
}
#endif

private struct CheckInWatermarkExportView: View {
    let mountain: Mountain

    var body: some View {
        ZStack(alignment: .topLeading) {
            MountainPhoto(mountain: mountain, dimming: 0.46)

            LinearGradient(
                colors: [.black.opacity(0.72), .black.opacity(0.08), .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("WildFrog", systemImage: "mountain.2.fill")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                        Text("HONG KONG MOUNTAINEER")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                    }

                    Spacer()

                    Text("\(mountain.nameZh) · \(mountain.height)m")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(mountain.displayName)
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.58)
                        Text("挑戰紀錄 · \(max(1, mountain.checkIns + 1))/100 mt.")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                    }

                    Spacer()

                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 82, weight: .black))
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.42), radius: 12)
            .padding(54)

            VStack {
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 10, height: 150)
                }
                Spacer()
                HStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 10, height: 150)
                    Spacer()
                }
            }
            .padding(48)
        }
        .background(FrogTheme.ink)
        .clipped()
    }
}

private struct CheckInStatusChip: View {
    let systemImage: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FrogTheme.forest)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let subtitle {
                    Text(subtitle)
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            if subtitle == nil {
                Circle()
                    .fill(FrogTheme.forest)
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .center)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct CheckInConfidencePill: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(FrogTheme.forest, in: Circle())

            Text(text)
                .font(.frogCaption.weight(.bold))
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(FrogTheme.mapWash.opacity(0.7), in: Capsule())
    }
}
