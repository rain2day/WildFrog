import PhotosUI
import SwiftUI
#if canImport(UIKit)
import Photos
import UIKit
#endif

struct CheckInCameraView: View {
    let mountain: Mountain

    @State private var proofMode = ProofMode.camera
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSavingWatermark = false
    @State private var saveMessage: String?

    private enum ProofMode: String, CaseIterable, Identifiable {
        case camera = "即場拍照"
        case upload = "上載相片"

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                gpsPanel
                cameraPreview
                proofControls
                safetyPanel
            }
            .padding(18)
            .padding(.bottom, 110)
        }
        .navigationTitle("GPS 打卡")
        .nativeInlineTitle()
        .background(FrogTheme.paper)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mountain.displayName)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
            Text("\(mountain.region) · \(mountain.height)m · \(mountain.rankText)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FrogTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var gpsPanel: some View {
        HStack(spacing: 10) {
            GPSChip(value: "良好", label: "GPS 狀態", systemImage: "location.fill")
            GPSChip(value: "38m", label: "距離檢查點", systemImage: "scope")
            GPSChip(value: "60m", label: "有效半徑", systemImage: "dot.scope")
        }
    }

    private var cameraPreview: some View {
        ZStack(alignment: .topLeading) {
            MountainPhoto(mountain: mountain, dimming: 0.42)
                .frame(maxWidth: .infinity)

            LinearGradient(
                colors: [.black.opacity(0.58), .black.opacity(0.1), .black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("WildFrog", systemImage: "mountain.2.fill")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text("\(mountain.nameZh) · \(mountain.height)m")
                        .font(.headline.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.28))
                        .clipShape(Capsule())
                }

                Spacer()

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MOUNTAINEER / HONG KONG")
                            .font(.caption.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                        Text("挑戰紀錄 · \(max(1, mountain.checkIns + 1))/100 mt.")
                            .font(.headline.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.26))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer()
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 44, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(18)

            VStack {
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 5, height: 82)
                }
                Spacer()
                HStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 5, height: 82)
                    Spacer()
                }
            }
            .padding(18)
        }
        .frame(height: 430)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var proofControls: some View {
        VStack(spacing: 12) {
            Picker("相片證明方式", selection: $proofMode) {
                ForEach(ProofMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if proofMode == .upload {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("選擇相片並加水印", systemImage: "photo.badge.plus")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(FrogTheme.orange)
            } else {
                Button {} label: {
                    Label("即場拍照並加水印", systemImage: "camera.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(FrogTheme.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {} label: {
                Label("立即完成有效打卡", systemImage: "checkmark.seal.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FrogTheme.line, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button {
                saveWatermarkImage()
            } label: {
                Label(isSavingWatermark ? "正在儲存..." : "下載水印圖", systemImage: "square.and.arrow.down.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FrogTheme.orangeSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FrogTheme.orange.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSavingWatermark)

            if let saveMessage {
                Text(saveMessage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FrogTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var safetyPanel: some View {
        Label("離開有效半徑時，此步驟會保持鎖定。危險地形上不要邊行邊用手機。", systemImage: "lock.shield")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FrogTheme.muted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
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

private struct GPSChip: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(FrogTheme.orange)
            Text(value)
                .font(.headline.weight(.black))
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(FrogTheme.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle()
    }
}
