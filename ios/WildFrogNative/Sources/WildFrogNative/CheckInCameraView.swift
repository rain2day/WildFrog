import CoreLocation
import MapKit
import PhotosUI
import SwiftUI
#if canImport(UIKit)
import Photos
import UIKit
#endif

/// Whether this check-in is also recording the hike that led to the summit.
private enum CheckInMode {
    /// Initial fork: the user has not yet chosen 開始行程 vs 直接打卡.
    case choosing
    /// Fast path — photo + GPS gating only, no track.
    case directCheckIn
    /// Live recording — `TrackRecorder` runs, and the finished track is bound to the check-in.
    case recording
}

struct CheckInCameraView: View {
    let mountain: Mountain

    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileAuthService.self) private var authService
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore

    // MARK: - Flow state
    @State private var mode: CheckInMode = .choosing
    @StateObject private var recorder = TrackRecorder()
    @State private var trackCameraPosition: MapCameraPosition = .userLocation(
        fallback: .automatic
    )

    // MARK: - Photo state
    @State private var capturedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

    // MARK: - Save state
    @State private var isSavingWatermark = false
    @State private var saveMessage: String?
    @State private var showSignInAlert = false

    // MARK: - GPS gating helpers

    /// Current distance to the mountain summit in metres (nil = no fix yet).
    private var distanceMetres: Double? {
        locationManager.distance(to: mountain.coordinate)
    }

    /// True when the user is authorised AND within 500 m of the summit.
    private var isInRange: Bool {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways,
              let d = distanceMetres else { return false }
        return d <= 500
    }

    /// True when all conditions for completing a check-in are met.
    private var canCheckIn: Bool {
        isInRange && capturedImage != nil && authService.isSignedIn
    }

    private var gpsChipTitle: String {
        switch locationManager.authorizationStatus {
        case .notDetermined, .restricted, .denied:
            return "需要定位權限"
        case .authorizedWhenInUse, .authorizedAlways:
            guard let d = distanceMetres else { return "定位中…" }
            if d <= 500 {
                return "喺打卡範圍（\(Int(d))m）"
            } else {
                let km = d / 1000
                return String(format: "距離 %.1fkm，行近啲", km)
            }
        @unknown default:
            return "定位中…"
        }
    }

    private var gpsChipImage: String {
        switch locationManager.authorizationStatus {
        case .notDetermined, .restricted, .denied:
            return "location.slash.fill"
        case .authorizedWhenInUse, .authorizedAlways:
            guard let d = distanceMetres else { return "location.circle" }
            return d <= 500 ? "mappin.circle.fill" : "location.circle.fill"
        @unknown default:
            return "location.circle"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // Background: captured photo or mountain asset
                backgroundLayer(size: proxy.size)

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
                    if mode == .recording {
                        recordingBanner
                    }
                    Spacer()
                    photoActionRow
                        .padding(.horizontal, FrogSpace.screenPadding)
                    checkInBottomSheet
                        .padding(.bottom, 98)
                }
                .padding(.horizontal, FrogSpace.screenPadding)

                if mode == .choosing {
                    modeChooserOverlay(topInset: proxy.safeAreaInsets.top)
                }
            }
        }
        .hiddenNavigationBar()
        .background(FrogTheme.warmPaper)
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.startUpdating()
        }
        .onDisappear {
            locationManager.stopUpdating()
            if recorder.isRecording {
                recorder.stop()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            #if canImport(UIKit)
            CameraPicker(capturedImage: $capturedImage)
                .ignoresSafeArea()
            #endif
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        capturedImage = uiImage
                    }
                }
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(size: CGSize) -> some View {
        if let img = capturedImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .ignoresSafeArea()
        } else {
            MountainPhoto(mountain: mountain, dimming: 0)
                .frame(width: size.width, height: size.height)
                .ignoresSafeArea()
        }
    }

    // MARK: - Top bar

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

    // MARK: - Status strip

    private var statusStrip: some View {
        HStack(spacing: 10) {
            CheckInStatusChip(systemImage: gpsChipImage, title: gpsChipTitle, subtitle: nil)
            CheckInStatusChip(systemImage: "mountain.2", title: "\(mountain.height)m", subtitle: "summit")
            CheckInStatusChip(systemImage: "sun.max", title: "Weather", subtitle: "Clear")
        }
    }

    // MARK: - Mode chooser (開始行程 vs 直接打卡)

    private func modeChooserOverlay(topInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() } // Tap backdrop to back out of the picker.

            VStack(alignment: .leading, spacing: 16) {
                Capsule()
                    .fill(FrogTheme.line)
                    .frame(width: 46, height: 5)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    Text(mountain.nameZh)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.ink)
                    Text("點樣打卡呢座山？")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                }

                Button {
                    startRecordingMode()
                } label: {
                    modeOptionLabel(
                        systemImage: "figure.hiking",
                        title: "開始行程（記軌跡）",
                        subtitle: "沿途記錄路線、距離、時間、爬升，到山頂打卡綁埋",
                        background: FrogTheme.orange,
                        foreground: .white
                    )
                }
                .buttonStyle(.plain)

                Button {
                    mode = .directCheckIn
                } label: {
                    modeOptionLabel(
                        systemImage: "bolt.fill",
                        title: "直接打卡",
                        subtitle: "已喺山頂／唔記全程，直接影相打卡",
                        background: Color.white,
                        foreground: FrogTheme.ink
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .background(FrogTheme.warmPaper)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 20, y: -6)
        }
    }

    private func modeOptionLabel(
        systemImage: String,
        title: String,
        subtitle: String,
        background: Color,
        foreground: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(foreground)
                Text(subtitle)
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(foreground.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: background == Color.white ? 1 : 0)
        )
    }

    // MARK: - Recording banner (live Map + stats while hiking to summit)

    private var recordingBanner: some View {
        VStack(spacing: 12) {
            Map(position: $trackCameraPosition) {
                UserAnnotation()
                Marker(mountain.nameZh, systemImage: "mappin.circle.fill", coordinate: mountain.coordinate)
                    .tint(FrogTheme.orange)
                if recorder.points.count > 1 {
                    MapPolyline(coordinates: recorder.points.map(\.coordinate))
                        .stroke(FrogTheme.orange, lineWidth: 5)
                }
            }
            .mapControlVisibility(.hidden)
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 0) {
                recordingStat(value: TrackFormat.distance(recorder.distanceMeters), label: "距離")
                recordingDivider
                recordingStat(value: TrackFormat.duration(recorder.elapsedSeconds), label: "時間")
                recordingDivider
                recordingStat(value: "\(Int(recorder.ascentMeters))m", label: "爬升")
            }

            HStack(spacing: 7) {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(FrogTheme.orange)
                Text("行程記錄中 · 行到\(mountain.nameZh)山頂影相即綁埋")
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
    }

    private var recordingDivider: some View {
        Rectangle()
            .fill(FrogTheme.line)
            .frame(width: 1, height: 32)
    }

    private func recordingStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(FrogTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func startRecordingMode() {
        mode = .recording
        recorder.start()
    }

    // MARK: - Photo action row

    private var photoActionRow: some View {
        HStack(spacing: 12) {
            // 即場拍照
            Button {
                #if canImport(UIKit)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                }
                #endif
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("即場拍照")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            #if canImport(UIKit)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            .opacity(UIImagePickerController.isSourceTypeAvailable(.camera) ? 1 : 0.45)
            #endif
            .accessibilityHint(
                {
                    #if canImport(UIKit)
                    UIImagePickerController.isSourceTypeAvailable(.camera)
                        ? "開啟相機拍攝打卡相"
                        : "相機喺實機先用到"
                    #else
                    "相機喺實機先用到"
                    #endif
                }()
            )

            // 上載相片
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("上載相片")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
                .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Watermark preview

    private var watermarkPreview: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                MountainPhoto(mountain: mountain, dimming: 0.34)
                    .overlay(
                        Text("先影相或揀相")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .multilineTextAlignment(.center)
                    )
            }
            // Watermark overlay
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

    // MARK: - Bottom sheet

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

            // Complete check-in button — gated by signed-in AND in-range AND has photo
            Button {
                if !authService.isSignedIn {
                    showSignInAlert = true
                } else {
                    performCheckIn()
                }
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
                .opacity(canCheckIn ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(isSavingWatermark || (!canCheckIn && authService.isSignedIn))
            .alert("請先登入", isPresented: $showSignInAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("打卡前請先登入（我的）")
            }

            // Status hint
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text(saveMessage ?? hintText)
            }
            .font(.frogCaption.weight(.semibold))
            .foregroundStyle(canCheckIn ? FrogTheme.muted : FrogTheme.orange)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(FrogTheme.warmPaper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: -4)
    }

    private var hintText: String {
        if !authService.isSignedIn {
            return "打卡前請先登入（我的）"
        } else if capturedImage == nil {
            return "請先影相或揀相"
        } else if !isInRange {
            return gpsChipTitle
        }
        return "打卡後將生成水印圖並儲存到相簿"
    }

    // MARK: - Perform check-in (write store + Firestore + save watermark)

    @MainActor
    private func performCheckIn() {
        #if canImport(UIKit)
        guard let capturedImage else {
            saveMessage = "請先影相或揀相。"
            return
        }
        guard let uid = authService.session?.uid else {
            saveMessage = "請先登入再打卡。"
            return
        }
        guard let watermarkImage = renderWatermarkImage(userPhoto: capturedImage) else {
            saveMessage = "未能生成水印圖，請再試一次。"
            return
        }

        isSavingWatermark = true
        saveMessage = nil

        // Finalise the recorded hike (if any) before persisting so the track
        // is bound to this check-in. Captured on the main actor up-front.
        let trackSummary: TrackSummary? = recorder.isRecording
            ? recorder.stop().map(TrackSummary.init(track:))
            : nil

        Task {
            // 1. Save original photo to Documents and get filename
            let filename = await savePhotoToDocuments(capturedImage)

            // 2. Write to local CheckInStore (account-bound), binding the track
            checkInStore.addCheckIn(mountainId: mountain.id, photoFilename: filename, track: trackSummary)

            // 3. Best-effort Firestore write — failure does not block local success
            Task {
                try? await FirestoreService().recordCheckIn(
                    userId: uid,
                    mountainId: mountain.id,
                    date: Date()
                )
            }

            // 4. Save watermark image to photo library
            let status = await requestPhotoAddPermission()
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isSavingWatermark = false
                    saveMessage = "未獲相簿儲存權限。"
                }
                return
            }

            do {
                try await saveToPhotoLibrary(watermarkImage)
                await MainActor.run {
                    isSavingWatermark = false
                    saveMessage = "打卡成功！水印圖已儲存到相簿。"
                }
            } catch {
                await MainActor.run {
                    isSavingWatermark = false
                    saveMessage = "打卡已記錄，但儲存相簿失敗：\(error.localizedDescription)"
                }
            }
        }
        #else
        saveMessage = "此平台暫不支援儲存到相簿。"
        #endif
    }

    /// Saves the original (unwatermarked) photo to the app's Documents directory and returns the filename.
    private func savePhotoToDocuments(_ image: UIImage) async -> String? {
        #if canImport(UIKit)
        return await Task.detached(priority: .utility) {
            let filename = UUID().uuidString + ".jpg"
            guard let data = image.jpegData(compressionQuality: 0.85),
                  let url = FileManager.default
                      .urls(for: .documentDirectory, in: .userDomainMask)
                      .first?
                      .appendingPathComponent(filename) else {
                return nil
            }
            try? data.write(to: url)
            return filename
        }.value
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    @MainActor
    private func renderWatermarkImage(userPhoto: UIImage) -> UIImage? {
        let currentCount = checkInStore.count(for: mountain.id)
        let renderer = ImageRenderer(
            content: CheckInWatermarkExportView(mountain: mountain, userPhoto: userPhoto, checkInCount: currentCount)
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

// MARK: - Watermark export view (uses real user photo)

private struct CheckInWatermarkExportView: View {
    let mountain: Mountain
    let userPhoto: UIImage
    let checkInCount: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            // User's actual photo as the background
            Image(uiImage: userPhoto)
                .resizable()
                .scaledToFill()
                .clipped()

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
                        Text("挑戰紀錄 · \(max(1, checkInCount + 1))/100 mt.")
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

// MARK: - Supporting views

#if canImport(UIKit)
private enum WatermarkSaveError: LocalizedError {
    case unknown

    var errorDescription: String? {
        "未能寫入相簿。"
    }
}
#endif

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
