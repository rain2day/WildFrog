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
                    modeChooserOverlay(bottomInset: proxy.safeAreaInsets.bottom)
                }

                if showSuccess {
                    checkInSuccessView(topInset: proxy.safeAreaInsets.top, bottomInset: proxy.safeAreaInsets.bottom)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .ignoresSafeArea()
        }
        .hiddenNavigationBar()
        .background(FrogTheme.warmPaper)
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.startUpdating()
            if recorder.isRecording {
                mode = .recording
            }
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
            watermarkPreviewImage = renderWatermarkImage(userPhoto: newImage)
            #endif
        }
        .fullScreenCover(isPresented: $showEnlargedWatermark) {
            watermarkEnlargedView
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

    private func modeChooserOverlay(bottomInset: CGFloat) -> some View {
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
                .padding(.bottom, max(bottomInset, 12) + 16)
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

    private func checkInSuccessView(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        ZStack {
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

                VStack(spacing: 0) {
                    Spacer().frame(height: topInset + 22)

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

                    Text("VALID CHECK-IN · 有效打卡")
                        .font(.frogEyebrow)
                        .tracking(1.8)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 24)

                    Text("\(mountain.nameZh) 已打卡")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.top, 10)

                    Text("已記錄到你的 300 峰護照，水印相已儲存到相簿。")
                        .font(.frogCaption)
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 252)
                        .padding(.top, 8)

                    VStack(spacing: 14) {
                        if let wm = watermarkPreviewImage {
                            Image(uiImage: wm)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
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

                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        if let wm = watermarkPreviewImage {
                            ShareLink(
                                item: Image(uiImage: wm),
                                preview: SharePreview("WildFrog · \(mountain.nameZh)", image: Image(uiImage: wm))
                            ) {
                                Label("分享水印相", systemImage: "square.and.arrow.up")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }

                        Button { dismiss() } label: {
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
                    .padding(.bottom, max(bottomInset, 12) + 18)
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
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
        guard let watermarkImage = renderWatermarkImage(userPhoto: capturedImage) else {
            saveMessage = "未能生成水印圖，請再試一次。"
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
            await MainActor.run {
                checkInStore.addCheckIn(mountainId: mountain.id, photoFilename: filename, track: trackSummary)
                isSavingWatermark = false
                saveMessage = "打卡成功！"
                withAnimation(.easeInOut(duration: 0.3)) { showSuccess = true }
            }

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
        let currentCount = checkInStore.distinctMountainCount
        let renderer = ImageRenderer(
            content: CheckInWatermarkExportView(mountain: mountain, userPhoto: userPhoto, checkInCount: currentCount)
                .frame(width: 1080, height: 1080)
        )
        renderer.scale = 1
        return renderer.uiImage
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

            // Light top + bottom darkening for corner legibility only — no wash.
            LinearGradient(
                colors: [.black.opacity(0.5), .clear, .clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                // Top — logo (left) + peak name · height (right)
                HStack(alignment: .top) {
                    HStack(spacing: 18) {
                        WildFrogBrandMark(size: 86, cornerRadius: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WildFrog")
                                .font(.system(size: 58, weight: .black))
                            Text("MOUNTAIN RANGERS")
                                .font(.system(size: 22, weight: .heavy))
                                .tracking(3)
                        }
                    }

                    Spacer(minLength: 24)

                    Text("\(mountain.nameZh) · \(mountain.height)m")
                        .font(.system(size: 38, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.trailing)
                }

                Spacer()

                // Bottom — MOUNTAINEER badge (left) + challenge record (right)
                HStack(alignment: .bottom) {
                    Text("MOUNTAINEER")
                        .font(.system(size: 26, weight: .black))
                        .tracking(3)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.white, lineWidth: 2)
                        )

                    Spacer()

                    Text("挑戰紀錄 · \(max(1, checkInCount))/300 mt.")
                        .font(.system(size: 34, weight: .black))
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 10)
            .padding(56)

            // Corner registration ticks (top-right, bottom-left).
            VStack {
                HStack {
                    Spacer()
                    Rectangle().fill(Color.white).frame(width: 10, height: 130)
                }
                Spacer()
                HStack {
                    Rectangle().fill(Color.white).frame(width: 10, height: 130)
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
