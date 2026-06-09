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

/// Which share-card layout the user keeps for this check-in.
private enum ShareCardStyle: String, CaseIterable, Identifiable {
    case polaroid
    case passport
    var id: String { rawValue }
    var label: String { self == .polaroid ? "拍立得" : "護照" }
}

struct CheckInCameraView: View {
    let mountain: Mountain

    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileAuthService.self) private var authService
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore
    @EnvironmentObject private var recorder: TrackRecorder

    // MARK: - Flow state
    @State private var mode: CheckInMode = .choosing
    @State private var trackCameraPosition: MapCameraPosition = .userLocation(
        fallback: .automatic
    )

    // MARK: - Photo state
    @State private var capturedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

    // MARK: - Save state
    @State private var isSavingWatermark = false
    @State private var didCompleteCheckIn = false
    @State private var saveMessage: String?
    @State private var showSignInAlert = false
    @State private var watermarkPreviewImage: UIImage?
    @State private var showEnlargedWatermark = false
    @State private var showSuccess = false
    @State private var cardStyle: ShareCardStyle = .polaroid

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
                return "\(Int(d))m"
            } else {
                let km = d / 1000
                if km > 99 {
                    return ">99km"
                }
                return String(format: "%.1fkm", km)
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
            ZStack {
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

                VStack(spacing: 12) {
                    checkInTopBar
                    statusStrip
                    if mode == .recording {
                        recordingBanner
                    }
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.top, proxy.safeAreaInsets.top + 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if mode != .choosing {
                    VStack(spacing: 14) {
                        photoActionRow
                        checkInBottomSheet
                    }
                    .padding(.horizontal, FrogSpace.screenPadding)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12) + 92)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if mode == .choosing {
                    modeChooserOverlay(bottomInset: proxy.safeAreaInsets.bottom, screenHeight: proxy.size.height)
                }

            }
            .ignoresSafeArea()
        }
        .hiddenNavigationBar()
        .background(FrogTheme.warmPaper)
        .onAppear {
            #if DEBUG
            let qaRender = ProcessInfo.processInfo.arguments.contains("-qaSuccess")
                || ProcessInfo.processInfo.arguments.contains("-qaWatermark")
                || ProcessInfo.processInfo.arguments.contains("-qaPassport")
            #else
            let qaRender = false
            #endif

            // QA card-render launches don't need location — skip the request so
            // the permission dialog never covers the preview screenshot.
            if !qaRender {
                locationManager.requestAuthorization()
                locationManager.startUpdating()
            }
            if recorder.isRecording {
                mode = .recording
            }
            #if DEBUG
            let qaArgs = ProcessInfo.processInfo.arguments
            if qaArgs.contains("-qaPassport") { cardStyle = .passport }
            if qaArgs.contains("-qaSuccess") {
                mode = .directCheckIn
                capturedImage = UIImage(named: mountain.imageName)
                showSuccess = true
            } else if qaArgs.contains("-qaWatermark") || qaArgs.contains("-qaPassport") {
                mode = .directCheckIn
                if let img = UIImage(named: mountain.imageName) {
                    watermarkPreviewImage = renderCard(cardStyle, userPhoto: img)
                }
                showEnlargedWatermark = true
            }
            #endif
        }
        .onDisappear {
            locationManager.stopUpdating()
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
        .onChange(of: capturedImage) { _, newImage in
            #if canImport(UIKit)
            guard let newImage else { watermarkPreviewImage = nil; return }
            watermarkPreviewImage = renderCard(cardStyle, userPhoto: newImage)
            #endif
        }
        .onChange(of: cardStyle) { _, newStyle in
            #if canImport(UIKit)
            guard let img = capturedImage else { return }
            watermarkPreviewImage = renderCard(newStyle, userPhoto: img)
            #endif
        }
        .fullScreenCover(isPresented: $showEnlargedWatermark) {
            watermarkEnlargedView
        }
        .fullScreenCover(isPresented: $showSuccess) {
            checkInSuccessScreen
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(size: CGSize) -> some View {
        if let img = capturedImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height + 180)
                .clipped()
                .ignoresSafeArea()
        } else {
            MountainPhoto(mountain: mountain, dimming: 0)
                .frame(width: size.width, height: size.height + 180)
                .ignoresSafeArea()
        }
    }

    // MARK: - Top bar

    private var checkInTopBar: some View {
        HStack(alignment: .top) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.16), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.26), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("關閉")

            Spacer()

            WildFrogWordmark(markSize: 34)
                .padding(.top, 1)
                .accessibilityLabel("WildFrog 山系足跡")

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    // MARK: - Status strip

    private var statusStrip: some View {
        HStack(spacing: 9) {
            CheckInStatusChip(systemImage: gpsChipImage, title: gpsChipTitle, subtitle: nil)
            CheckInStatusChip(systemImage: "mountain.2", title: "\(mountain.height)m", subtitle: "summit")
            CheckInStatusChip(systemImage: "sun.max", title: "Weather", subtitle: "Clear")
        }
    }

    // MARK: - Mode chooser (開始行程 vs 直接打卡)

    private func modeChooserOverlay(bottomInset: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() } // Tap backdrop to back out of the picker.

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 12) {
                        Capsule()
                            .fill(FrogTheme.line)
                            .frame(width: 44, height: 5)
                            .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(mountain.nameZh)
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(FrogTheme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text("點樣打卡呢座山？")
                                .font(.frogCaption.weight(.medium))
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
                                background: FrogTheme.surface,
                                foreground: FrogTheme.ink
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity)
                    .background(FrogTheme.warmPaper)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.28), radius: 24, y: -8)
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                // Comfortable bottom-sheet clearance — sits in the lower half,
                // not jammed against the home indicator. Scales with screen size.
                .padding(.bottom, max(bottomInset + 16, screenHeight * 0.16))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func modeOptionLabel(
        systemImage: String,
        title: String,
        subtitle: String,
        background: Color,
        foreground: Color
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(foreground)
                Text(subtitle)
                    .font(.frogCaption.weight(.medium))
                    .foregroundStyle(background == FrogTheme.orange ? foreground.opacity(0.82) : FrogTheme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: background != FrogTheme.orange ? 1 : 0)
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
                Spacer(minLength: 0)
                Button {
                    stopRecordingMode()
                } label: {
                    Label("STOP", systemImage: "stop.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(FrogTheme.ink, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(FrogTheme.warmPaper.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .font(.frogNum(22, weight: .heavy))
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.frogCaption.weight(.medium))
                .foregroundStyle(FrogTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func startRecordingMode() {
        mode = .recording
        recorder.start()
    }

    private func stopRecordingMode() {
        _ = recorder.stop()
        mode = .directCheckIn
    }

    // MARK: - Photo action row

    private var photoActionRow: some View {
        HStack(spacing: 11) {
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
                        .font(.system(size: 16, weight: .semibold))
                    Text("即場拍照")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
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
                        .font(.system(size: 16, weight: .semibold))
                    Text("上載相片")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                )
                .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Watermark preview

    private var watermarkPreview: some View {
        Button {
            if watermarkPreviewImage != nil { showEnlargedWatermark = true }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let wm = watermarkPreviewImage {
                    // The actual rendered watermark — what gets saved/shared.
                    Image(uiImage: wm)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else if let img = capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                        .overlay(
                            LinearGradient(colors: [.clear, .black.opacity(0.64)], startPoint: .center, endPoint: .bottom)
                        )
                        .overlay(alignment: .bottomLeading) { previewWatermarkBadge.padding(7) }
                } else {
                    MountainPhoto(mountain: mountain, dimming: 0.34)
                        .overlay(
                            Text("先影相或揀相")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                                .padding(6)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .multilineTextAlignment(.center)
                        )
                }

                if watermarkPreviewImage != nil {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(5)
                }
            }
            .frame(width: 116, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var previewWatermarkBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text("WILDFROG")
                    .font(.frogNum(7.5, weight: .bold))
                Text("\(mountain.nameZh) · \(mountain.height)m")
                    .font(.frogNum(7.5, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }

    // MARK: - Bottom sheet

    private var checkInBottomSheet: some View {
        VStack(alignment: .leading, spacing: 15) {
            Capsule()
                .fill(FrogTheme.line)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(mountain.nameZh)
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(mountain.nameEn)
                        .font(.frogNum(18, weight: .semibold))
                        .foregroundStyle(FrogTheme.moss)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 8) {
                        Label("\(mountain.height)m", systemImage: "mountain.2.fill")
                            .font(.frogNum(13, weight: .semibold))
                            .foregroundStyle(FrogTheme.forest)
                        CheckInConfidencePill(systemImage: "checkmark", text: "GPS 吻合")
                    }

                    Text("根據 GPS、海拔及方向核對")
                        .font(.frogCaption.weight(.medium))
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("水印預覽")
                        .font(.frogEyebrow)
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(FrogTheme.moss)
                    watermarkPreview
                }
                .frame(width: 116, alignment: .leading)
            }

            // Complete check-in button — gated by signed-in AND in-range AND has photo
            Button {
                if !authService.isSignedIn {
                    showSignInAlert = true
                } else {
                    performCheckIn()
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .heavy))
                        .frame(width: 42, height: 42)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2.5))
                    Text(isSavingWatermark ? "正在儲存..." : "完成打卡")
                        .font(.system(size: 22, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .primaryCTAStyle(cornerRadius: 20)
                .opacity(canCheckIn ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(isSavingWatermark || didCompleteCheckIn || (!canCheckIn && authService.isSignedIn))
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
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(canCheckIn ? FrogTheme.muted : FrogTheme.orange)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(FrogTheme.warmPaper.opacity(0.97))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                bottomLeadingRadius: 36,
                bottomTrailingRadius: 36,
                topTrailingRadius: 26,
                style: .continuous
            )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: -8)
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

    // MARK: - Enlarged watermark preview

    private var watermarkEnlargedView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let wm = watermarkPreviewImage {
                Image(uiImage: wm)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { showEnlargedWatermark = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.18), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("打卡時會儲存呢張水印相到你的相簿")
                    .font(.frogCaption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Success screen (design flow 04)

    private var checkInSuccessScreen: some View {
        ZStack(alignment: .top) {
            // Full-bleed photo + design gradient (.succ .ph / .grad).
            MountainPhoto(mountain: mountain, dimming: 0)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    FrogTheme.forest.opacity(0.62),
                    FrogTheme.forest.opacity(0.42),
                    Color.black.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Presented as a fullScreenCover → clean safe area, so the ScrollView
            // respects insets on its own. Content top-aligned, actions follow the
            // card (design .succ .inner order). Scrolls if it ever overflows.
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 2)
                            .frame(width: 92, height: 92)
                        Circle()
                            .strokeBorder(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 76, height: 76)
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 18)

                    Text("VALID CHECK-IN · 有效打卡")
                        .font(.frogEyebrow)
                        .tracking(1.8)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 26)

                    Text("\(mountain.nameZh) 已打卡")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    Text("已記錄到你的 300 峰護照，打卡相已儲存到相簿。")
                        .font(.frogCaption)
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 252)
                        .padding(.top, 8)

                    Picker("分享卡款式", selection: $cardStyle) {
                        ForEach(ShareCardStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                    .padding(.top, 24)

                    // record card (.succ .card)
                    VStack(spacing: 14) {
                        if let wm = watermarkPreviewImage {
                            Image(uiImage: wm)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 210)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .onTapGesture { showEnlargedWatermark = true }
                        }

                        HStack(spacing: 0) {
                            successStat(value: "\(checkInStore.count(for: mountain.id))", label: "此山打卡")
                            successStatDivider
                            successStat(value: mountain.rankText, label: "300峰排名", tint: FrogTheme.orange)
                            successStatDivider
                            successStat(value: "\(checkInStore.distinctMountainCount)", label: "已征服山峰")
                        }
                    }
                    .padding(16)
                    .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.top, 26)

                    // actions follow the card (.succ .actions padding-top:26)
                    VStack(spacing: 10) {
                        if let wm = watermarkPreviewImage {
                            ShareLink(
                                item: Image(uiImage: wm),
                                preview: SharePreview("WildFrog · \(mountain.nameZh)", image: Image(uiImage: wm))
                            ) {
                                Label("分享打卡相", systemImage: "square.and.arrow.up")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }

                        Button {
                            showSuccess = false
                            dismiss()
                        } label: {
                            Text("返回山峰")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 26)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private func successStat(value: String, label: String, tint: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.frogNum(22, weight: .semibold))
                .foregroundStyle(tint == .white ? FrogTheme.ink : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.frogMicro)
                .foregroundStyle(FrogTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var successStatDivider: some View {
        Rectangle()
            .fill(FrogTheme.line)
            .frame(width: 1, height: 28)
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
        guard let watermarkImage = renderCard(cardStyle, userPhoto: capturedImage) else {
            saveMessage = "未能生成打卡相，請再試一次。"
            return
        }

        guard !didCompleteCheckIn else { return }

        isSavingWatermark = true
        didCompleteCheckIn = true
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
            let newRecord = await MainActor.run { () -> CheckInRecord? in
                let record = checkInStore.addCheckIn(mountainId: mountain.id, photoFilename: filename, track: trackSummary)
                isSavingWatermark = false
                saveMessage = "打卡成功！"
                withAnimation(.easeInOut(duration: 0.3)) { showSuccess = true }
                return record
            }

            // 3. Best-effort Firestore write — failure does not block local success.
            // Pass the record's stable id + date so the cloud echo reconciles back
            // onto the local record (which holds the photo + track) on the next sync.
            if let newRecord {
                Task {
                    try? await FirestoreService().recordCheckIn(
                        id: newRecord.id,
                        userId: uid,
                        mountainId: mountain.id,
                        date: newRecord.date
                    )
                }
            }

            // 4. Save watermark image to photo library
            let status = await requestPhotoAddPermission()
            guard status == .authorized || status == .limited else {
                return
            }

            try? await saveToPhotoLibrary(watermarkImage)
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
        let renderer = ImageRenderer(
            content: CheckInWatermarkExportView(mountain: mountain, userPhoto: userPhoto, date: Date())
        )
        renderer.scale = 1
        return renderer.uiImage
    }

    @MainActor
    private func renderPassportImage(userPhoto: UIImage) -> UIImage? {
        let renderer = ImageRenderer(
            content: CheckInPassportCardView(mountain: mountain, userPhoto: userPhoto, date: Date())
        )
        renderer.scale = 1
        return renderer.uiImage
    }

    @MainActor
    private func renderCard(_ style: ShareCardStyle, userPhoto: UIImage) -> UIImage? {
        switch style {
        case .polaroid: return renderWatermarkImage(userPhoto: userPhoto)
        case .passport: return renderPassportImage(userPhoto: userPhoto)
        }
    }

    // `nonisolated`: SwiftUI View methods are implicitly @MainActor, which would
    // make these completion-handler closures @MainActor-isolated. Photos invokes
    // them on a background queue, tripping the Swift concurrency isolation check
    // (EXC_BREAKPOINT). Keeping them nonisolated lets the callbacks run anywhere.
    nonisolated private func requestPhotoAddPermission() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    nonisolated private func saveToPhotoLibrary(_ image: UIImage) async throws {
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

/// Shareable check-in card — a polaroid: the photo centre-cropped inside a warm
/// white frame, with a caption band (peak name + date chips, a subtle WildFrog
/// mark + elevation, and a rank badge). No text overlaid on the photo itself.
private struct CheckInWatermarkExportView: View {
    let mountain: Mountain
    let userPhoto: UIImage
    let date: Date

    private let width: CGFloat = 1080
    private let pad: CGFloat = 72

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    var body: some View {
        let photoSide = width - pad * 2

        VStack(spacing: 0) {
            // The check-in photo — always centre-cropped square so portrait or
            // landscape sources both sit cleanly inside the frame.
            Image(uiImage: userPhoto)
                .resizable()
                .scaledToFill()
                .frame(width: photoSide, height: photoSide)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, pad)
                .padding(.horizontal, pad)

            // Caption band
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    captionChip(mountain.nameZh, size: 50, weight: .black)
                    captionChip(dateText, size: 44, weight: .heavy)
                    Spacer(minLength: 0)
                }

                HStack(alignment: .center, spacing: 0) {
                    WildFrogBrandMark(size: 44, cornerRadius: 12)
                    Text("  WildFrog · 海拔 \(mountain.height)m")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(FrogTheme.muted)

                    Spacer()

                    Text("\(mountain.rankText) · 300峰")
                        .font(.system(size: 27, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(FrogTheme.forest, in: Capsule())
                }
            }
            .padding(.horizontal, pad)
            .padding(.top, 32)
            .padding(.bottom, 56)
        }
        .frame(width: width)
        .background(FrogTheme.surface)
    }

    private func captionChip(_ text: String, size: CGFloat, weight: Font.Weight) -> some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(FrogTheme.ink)
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
    }
}

/// Style 2 — passport / ticket-stub share card: photo on top, a perforated tear
/// line, then a cream stub with WILDFROG · PEAK PASSPORT, the big peak name, a
/// stat row, and the mountain stamp seal placed like a passport entry stamp.
private struct CheckInPassportCardView: View {
    let mountain: Mountain
    let userPhoto: UIImage
    let date: Date

    private let width: CGFloat = 1080

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private let photoH: CGFloat = 720
    private let stubH: CGFloat = 408
    private let perfR: CGFloat = 14

    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo fills the top and extends behind the stub's torn edge so the
            // real holes reveal it.
            VStack(spacing: 0) {
                Image(uiImage: userPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: photoH)
                    .clipped()
                Spacer(minLength: 0)
            }

            // Ticket stub with a genuinely torn (scalloped) top edge.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    WildFrogBrandMark(size: 42, cornerRadius: 11)
                    (
                        Text("WILDFROG ").foregroundStyle(FrogTheme.ink)
                        + Text("· PEAK PASSPORT").foregroundStyle(FrogTheme.gold)
                    )
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(1.5)
                    Spacer(minLength: 0)
                }

                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(mountain.nameZh)
                        .font(.system(size: 78, weight: .black))
                        .foregroundStyle(FrogTheme.ink)
                    Text(mountain.nameEn)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(FrogTheme.muted)
                    Spacer(minLength: 0)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 20)

                Rectangle()
                    .fill(FrogTheme.line)
                    .frame(height: 1)
                    .padding(.top, 26)

                HStack(spacing: 0) {
                    passportStat("海拔", "\(mountain.height)m")
                    passportStatDivider
                    passportStat("全港排名", mountain.rankText)
                    passportStatDivider
                    passportStat("地區", mountain.region)
                }
                .padding(.top, 22)

                Spacer(minLength: 12)

                Text("打卡日期 · \(dateText)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(FrogTheme.faint)
            }
            .padding(.horizontal, 64)
            .padding(.top, 38 + perfR)
            .padding(.bottom, 44)
            .frame(width: width, height: stubH, alignment: .topLeading)
            .background(PerforatedTopShape(radius: perfR, spacing: 38).fill(FrogTheme.passport))
            // Our own designed mountain stamp (1 of 330), pressed onto the photo.
            .overlay(alignment: .topTrailing) {
                MountainStampSeal(mountain: mountain, size: 360, isUnlocked: true, rotation: .degrees(-8))
                    .padding(.trailing, 26)
                    .offset(y: -180)
            }
        }
        .frame(width: width, height: photoH + stubH - perfR * 2)
        .background(FrogTheme.passport)
    }

    private func passportStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FrogTheme.muted)
            Text(value)
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(FrogTheme.forest)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var passportStatDivider: some View {
        Rectangle()
            .fill(FrogTheme.line)
            .frame(width: 1, height: 52)
            .padding(.horizontal, 16)
    }
}

/// A rectangle whose TOP edge is torn into semicircle notches — real cutouts, so
/// whatever sits behind shows through the holes.
private struct PerforatedTopShape: Shape {
    var radius: CGFloat
    var spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        var x = rect.minX + spacing / 2
        while x <= rect.maxX {
            path.addLine(to: CGPoint(x: x - radius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: x, y: rect.minY),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: true
            )
            x += spacing
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FrogTheme.forest)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.frogNum(14, weight: .semibold))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let subtitle {
                    Text(subtitle)
                        .font(.frogMicro.weight(.medium))
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            if subtitle == nil {
                Circle()
                    .fill(FrogTheme.leaf)
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .background(FrogTheme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
}

private struct CheckInConfidencePill: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(FrogTheme.moss)

            Text(text)
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(FrogTheme.moss)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(FrogTheme.mossSoft, in: Capsule())
    }
}
