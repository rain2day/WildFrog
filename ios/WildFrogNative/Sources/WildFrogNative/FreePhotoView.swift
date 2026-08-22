import CoreLocation
import PhotosUI
import SwiftUI
import UIKit

struct FreePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var freePhotoStore: FreePhotoStore

    @State private var draft = FreePhotoDraft()
    @State private var capturedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoSelectionState = FreePhotoSelectionRequestState()
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var cardStyle: FreePhotoCardStyle = .passport
    @State private var captureRevision = 0
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var saveConfirmation = FreePhotoSaveConfirmation()
    @State private var saveRequest = FreePhotoSaveRequestState()
    @State private var renderedAt = Date()
    @State private var locationConsumerID = UUID()
    @State private var selectedLocation: FreePhotoLocationCandidate?
    @State private var showImportedLocationChoice = false
    @State private var pendingCameraRevision: Int?
    @State private var saveCoordinator = FreePhotoSaveCoordinator()
    @State private var recoveryRequest: FreePhotoSaveRequest?
    @State private var recoveryThumbnailData: Data?
    @State private var didAddToPrivateMap = false
    @State private var showsMetadataEditor = false
    @State private var cameraLoadTask: Task<Void, Never>?
    @State private var photoLoadError: String?

    private var frameContent: FreePhotoFrameContent {
        frameContent(renderedAt: renderedAt)
    }

    private func frameContent(renderedAt _: Date) -> FreePhotoFrameContent {
        FreePhotoFrameContent(
            placeName: draft.validatedName,
            altitudeMetres: draft.altitudeMetres,
            altitudeSource: draft.altitudeSource,
            date: draft.displayDate,
            coordinate: draft.showsCoordinates ? draft.displayCoordinate : nil,
            isDateEdited: draft.isDateEdited,
            isCoordinateEdited: draft.isCoordinateEdited
        )
    }

    private var exportFingerprint: FreePhotoExportFingerprint {
        exportFingerprint(renderedAt: renderedAt)
    }

    private func exportFingerprint(renderedAt: Date) -> FreePhotoExportFingerprint {
        FreePhotoExportFingerprint(
            captureRevision: captureRevision,
            placeName: draft.validatedName,
            altitudeMetres: draft.altitudeMetres,
            altitudeSource: draft.altitudeSource,
            cardStyle: cardStyle,
            renderedAt: renderedAt,
            frameDate: draft.frameDate,
            showsDate: draft.showsDate,
            latitudeText: draft.latitudeText,
            longitudeText: draft.longitudeText,
            showsCoordinates: draft.showsCoordinates
        )
    }

    private var presentation: FreePhotoEditorPresentation {
        FreePhotoEditorPresentation(hasPhoto: capturedImage != nil)
    }

    var body: some View {
        Group {
            switch presentation.mode {
            case .studio:
                if let capturedImage {
                    studioEditor(image: capturedImage)
                }
            case .capture:
                captureEditor
            }
        }
        .background(FreePhotoPalette.paleMist.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if presentation.usesStickySave {
                stickySaveAction
            }
        }
        .onAppear {
            draft.beginLocationPrefillSession(at: .now)
            #if DEBUG
            let isQARender = ProcessInfo.processInfo.arguments.contains("-qaFreePhoto")
            if isQARender {
                draft.placeName = AppText.value(zh: "大東山日落位", en: "Sunset Ridge")
                draft.setAltitudeText("438")
                draft.applyFrameMetadata(
                    date: .now,
                    coordinate: FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201)
                )
                draft.showsCoordinates = true
                capturedImage = UIImage(named: "MountainTaiTungShan")
                    ?? UIImage(named: "MountainVioletHill")
            }
            #else
            let isQARender = false
            #endif

            if !isQARender {
                locationManager.requestAuthorization()
                locationManager.startUpdating(for: locationConsumerID)
            }
        }
        .onDisappear {
            photoLoadTask?.cancel()
            photoLoadTask = nil
            cameraLoadTask?.cancel()
            cameraLoadTask = nil
            photoSelectionState.invalidateForDismissal()
            locationManager.stopUpdating(for: locationConsumerID)
        }
        .onChange(of: locationManager.currentLocation) { _, location in
            applyAltitudeSuggestion(locationManager.resolvedLocation ?? location)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            photoLoadTask?.cancel()
            let captureRequestRevision = captureRevision + 1
            let requestRevision = photoSelectionState.beginPhotosLoad()
            photoLoadTask = Task {
                let acceptedAt = Date()
                guard let data = try? await item.loadTransferable(type: Data.self),
                      !Task.isCancelled else { return }
                // Decoding runs off the main actor; only the state assignment
                // below hops back onto it.
                let image = await FreePhotoImagePreparer.prepare(data: data)
                guard !Task.isCancelled else { return }
                guard let image else {
                    if photoSelectionState.acceptPhotosResult(requestRevision) {
                        photoLoadError = Self.photoPreparationFailureMessage
                        photoLoadTask = nil
                    }
                    return
                }
                let metadata = await FreePhotoMetadataReader.metadata(
                    from: data,
                    photosIdentifier: item.itemIdentifier,
                    acceptedAt: acceptedAt
                )
                guard !Task.isCancelled,
                      photoSelectionState.acceptPhotosResult(requestRevision) else { return }
                photoLoadError = nil
                captureRevision = captureRequestRevision
                capturedImage = image
                selectedLocation = metadata.location
                draft.applyFrameMetadata(
                    date: metadata.creationDate,
                    coordinate: metadata.location?.coordinate
                )
                showImportedLocationChoice = selectedLocation == nil
                photoLoadTask = nil
                resetSaveConfirmation()
            }
        }
        .onChange(of: draft) { _, _ in
            resetSaveConfirmation()
        }
        .onChange(of: cardStyle) { _, _ in
            resetSaveConfirmation()
        }
        .onChange(of: selectedLocation) { _, _ in
            resetSaveConfirmation()
        }
        .fullScreenCover(isPresented: $showCamera) {
            // The binding would hand back the raw capture synchronously on the
            // main actor; preparation is routed through `finishCameraCapture`
            // instead so the decode happens off-main.
            CameraPicker(capturedImage: .constant(nil)) { image in
                finishCameraCapture(image: image, capturedAt: .now)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showsMetadataEditor) {
            FreePhotoMetadataEditorSheet(draft: $draft)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            AppText.value(zh: "呢張相片冇位置資料", en: "This photo has no location"),
            isPresented: $showImportedLocationChoice,
            titleVisibility: .visible
        ) {
            Button(AppText.value(zh: "使用目前位置", en: "Use Current Location")) {
                let candidate = FreePhotoLocationResolver.currentLocationCandidate(
                    locationManager.resolvedLocation ?? locationManager.currentLocation
                )
                selectedLocation = candidate
                draft.applyFrameMetadata(
                    date: draft.frameDate,
                    coordinate: candidate?.coordinate
                )
            }
            Button(AppText.value(zh: "稍後在地圖加位置", en: "Add Location Later")) {
                selectedLocation = nil
            }
            Button(AppText.value(zh: "取消", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(AppText.value(
                zh: "你可以明確使用而家 GPS，或者照樣儲存並稍後手動放到地圖。",
                en: "Use the current GPS explicitly, or save now and place it on the map later."
            ))
        }
    }

    private var captureEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FreePhotoEditorMetrics.sectionGap) {
                header
                photoSection
            }
            .padding(.horizontal, FreePhotoEditorMetrics.pageInset)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
    }

    private func studioEditor(image: UIImage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FreePhotoEditorMetrics.sectionGap) {
                studioHeader
                studioPreview(image: image)
                frameStylePicker
                FreePhotoMetadataSummaryCard(draft: $draft) {
                    showsMetadataEditor = true
                }
                locationStatus
                saveSupportingSection
            }
            .padding(.horizontal, FreePhotoEditorMetrics.pageInset)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var studioHeader: some View {
        HStack(spacing: 12) {
            backButton
            VStack(alignment: .leading, spacing: 2) {
                Text(AppText.value(zh: "自由拍照", en: "Free Photo"))
                    .font(.frogTitle)
                    .foregroundStyle(FreePhotoPalette.navy)
                Text(AppText.value(zh: "即時預覽相框", en: "Live frame preview"))
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(FreePhotoPalette.blue)
            }
            Spacer()
            Menu {
                if FreePhotoCaptureAvailability.sources(
                    cameraAvailable: UIImagePickerController.isSourceTypeAvailable(.camera)
                ).contains(.camera) {
                    Button {
                        beginCameraReplacement()
                    } label: {
                        Label(AppText.value(zh: "重新影相", en: "Take Another Photo"), systemImage: "camera.fill")
                    }
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(AppText.value(zh: "由相簿更換", en: "Replace from Photos"), systemImage: "photo.on.rectangle")
                }
            } label: {
                Label(AppText.value(zh: "更換", en: "Replace"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(FreePhotoPalette.blue)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(.white, in: Capsule())
            }
        }
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(FreePhotoPalette.navy)
                .frame(width: 42, height: 42)
                .background(FreePhotoPalette.mist, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.value(zh: "返回", en: "Back"))
    }

    private func studioPreview(image: UIImage) -> some View {
        let previewLayout = FreePhotoPreviewLayout(style: cardStyle)
        return GeometryReader { proxy in
            frameView(image: image)
                .scaleEffect(proxy.size.width / 1080, anchor: .topLeading)
                .allowsHitTesting(FreePhotoPreviewInteractionContract.cardAllowsHitTesting)
                .frame(
                    width: proxy.size.width,
                    height: previewLayout.height(forAvailableWidth: proxy.size.width),
                    alignment: .topLeading
                )
                .clipped()
        }
        .aspectRatio(previewLayout.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: FreePhotoEditorMetrics.previewRadius, style: .continuous))
        .shadow(color: FreePhotoPalette.navy.opacity(0.14), radius: 16, y: 8)
    }

    private var frameStylePicker: some View {
        Picker(AppText.value(zh: "相框款式", en: "Frame style"), selection: $cardStyle) {
            ForEach(FreePhotoCardStyle.allCases) { style in
                Text(style.label).tag(style)
            }
        }
        .pickerStyle(.segmented)
        .padding(4)
        .background(FreePhotoPalette.mist, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func beginCameraReplacement() {
        photoLoadTask?.cancel()
        photoLoadTask = nil
        photoSelectionState.invalidateForNewChoice()
        pendingCameraRevision = captureRevision + 1
        showCamera = true
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(FreePhotoPalette.navy)
                    .frame(width: 42, height: 42)
                    .background(FreePhotoPalette.mist, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppText.value(zh: "返回", en: "Back"))

            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.value(zh: "自由拍照", en: "Free Photo"))
                    .font(.frogDisplay)
                    .foregroundStyle(FreePhotoPalette.navy)
                Text(AppText.value(
                    zh: "任何地方都可以加上自訂地名；只會儲存相框相片，不會當作正式打卡。",
                    en: "Add your own place name anywhere. This saves a framed photo only, never an official check-in."
                ))
                .font(.frogCaption)
                .foregroundStyle(FreePhotoPalette.navy.opacity(0.62))
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppText.value(zh: "選擇相片", en: "Choose a photo"))
                .font(.frogTitle)
                .foregroundStyle(FreePhotoPalette.navy)

            if let photoLoadError {
                Label(photoLoadError, systemImage: "exclamationmark.triangle.fill")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 34, weight: .medium))
                    Text(AppText.value(zh: "影相或由相簿選擇", en: "Take a photo or choose from Photos"))
                        .font(.frogRow)
                }
                .foregroundStyle(FreePhotoPalette.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(FreePhotoPalette.mist, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 10) {
                if FreePhotoCaptureAvailability.sources(
                    cameraAvailable: UIImagePickerController.isSourceTypeAvailable(.camera)
                ).contains(.camera) {
                    Button {
                        photoLoadTask?.cancel()
                        photoLoadTask = nil
                        photoSelectionState.invalidateForNewChoice()
                        pendingCameraRevision = captureRevision + 1
                        showCamera = true
                    } label: {
                        Label(AppText.value(zh: "影相", en: "Camera"), systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FreePhotoSecondaryButtonStyle())
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(AppText.value(zh: "相簿", en: "Photos"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FreePhotoSecondaryButtonStyle())
            }

            locationStatus
        }
    }

    private var locationStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedLocation == nil ? "mappin.slash" : "location.fill")
                .foregroundStyle(selectedLocation == nil ? FreePhotoPalette.navy.opacity(0.55) : FreePhotoPalette.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedLocation?.source.localizedLabel ?? AppText.value(zh: "需要位置", en: "Needs Location"))
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(FreePhotoPalette.navy)
                Text(selectedLocation == nil
                     ? AppText.value(zh: "仍可儲存，之後在探索地圖補上。", en: "You can still save and add it later on Explore.")
                     : AppText.value(zh: "只會加入你的本機私人地圖。", en: "Used only for your on-device private map."))
                    .font(.frogMicro)
                    .foregroundStyle(FreePhotoPalette.navy.opacity(0.58))
            }
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var stickySaveAction: some View {
        let hasCurrentSaveConfirmation = saveConfirmation.isCurrent(for: exportFingerprint)
        return Button {
            saveFramedPhoto()
        } label: {
            HStack(spacing: 10) {
                if isSaving { ProgressView().tint(.white) }
                Image(systemName: hasCurrentSaveConfirmation ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                Text(hasCurrentSaveConfirmation
                     ? AppText.value(zh: "已儲存並加入私人地圖", en: "Saved and added to private map")
                     : AppText.value(zh: "儲存相框相片", en: "Save Framed Photo"))
            }
            .font(.frogRow.weight(.black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(FreePhotoPalette.navy, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!draft.canExport(hasPhoto: capturedImage != nil) || isSaving)
        .opacity(draft.canExport(hasPhoto: capturedImage != nil) ? 1 : 0.42)
        .padding(.horizontal, FreePhotoEditorMetrics.pageInset)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var saveSupportingSection: some View {
        VStack(spacing: 10) {
            if let photoLoadError {
                Text(photoLoadError)
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if let saveError {
                Text(saveError)
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if recoveryRequest != nil {
                Button(AppText.value(zh: "重試加入私人地圖", en: "Retry Adding to Private Map")) {
                    retryPrivateMapSave()
                }
                .buttonStyle(FreePhotoSecondaryButtonStyle())
                .disabled(isSaving)
            }

            Text(AppText.value(
                zh: "自由拍照不會增加打卡次數、印章、成就或排行榜分數。",
                en: "Free Photo never changes check-ins, stamps, achievements, or leaderboard scores."
            ))
            .font(.frogMicro)
            .foregroundStyle(FreePhotoPalette.navy.opacity(0.56))
            .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func frameView(image: UIImage) -> some View {
        switch cardStyle {
        case .polaroid:
            FreePhotoPolaroidCardView(content: frameContent, userPhoto: image)
        case .passport:
            FreePhotoPassportCardView(content: frameContent, userPhoto: image)
        }
    }

    private func applyAltitudeSuggestion(_ location: CLLocation?) {
        guard let location else { return }
        draft.applyLocationSuggestion(
            altitude: location.altitude,
            verticalAccuracy: location.verticalAccuracy,
            timestamp: location.timestamp
        )
    }

    private func finishCameraCapture(image: UIImage, capturedAt: Date) {
        guard let pendingCameraRevision else { return }
        captureRevision = pendingCameraRevision
        let candidate = FreePhotoLocationResolver.cameraCandidate(
            location: locationManager.resolvedLocation ?? locationManager.currentLocation,
            captureRevision: pendingCameraRevision,
            activeRevision: pendingCameraRevision,
            now: capturedAt
        )
        selectedLocation = candidate
        draft.applyFrameMetadata(date: capturedAt, coordinate: candidate?.coordinate)
        self.pendingCameraRevision = nil
        resetSaveConfirmation()

        cameraLoadTask?.cancel()
        cameraLoadTask = Task {
            let prepared = await FreePhotoImagePreparer.prepare(image)
            guard !Task.isCancelled else { return }
            capturedImage = prepared
            photoLoadError = prepared == nil ? Self.photoPreparationFailureMessage : nil
            cameraLoadTask = nil
        }
    }

    private static var photoPreparationFailureMessage: String {
        AppText.value(
            zh: "未能處理呢張相片，請再影一次或者揀第二張。",
            en: "Could not process that photo. Take it again or choose another one."
        )
    }

    @MainActor
    private func renderedImage(renderedAt: Date) -> UIImage? {
        guard let capturedImage else { return nil }
        return FreePhotoFrameRenderer.render(
            style: cardStyle,
            content: frameContent(renderedAt: renderedAt),
            userPhoto: capturedImage
        )
    }

    private func saveFramedPhoto() {
        let exportDate = Date()
        let savedFingerprint = exportFingerprint(renderedAt: exportDate)
        guard draft.canExport(hasPhoto: capturedImage != nil),
              let image = renderedImage(renderedAt: exportDate) else { return }

        let request = FreePhotoSaveRequest(
            id: UUID(),
            captureRevision: captureRevision,
            renderedAt: exportDate,
            placeName: draft.validatedName,
            altitudeMetres: draft.altitudeMetres,
            altitudeSource: draft.altitudeSource,
            cardStyle: cardStyle,
            frameDate: draft.frameDate,
            showsDate: draft.showsDate,
            displayCoordinate: draft.displayCoordinate,
            showsCoordinates: draft.showsCoordinates,
            location: selectedLocation
        )
        guard let thumbnailData = privateMapThumbnailData(from: image) else { return }

        renderedAt = exportDate
        isSaving = true
        didAddToPrivateMap = false
        recoveryRequest = nil
        recoveryThumbnailData = nil
        saveConfirmation.clear()
        saveError = nil
        saveRequest.begin(for: savedFingerprint)
        Task {
            let outcome = await saveCoordinator.save(
                request: request,
                renderedImage: image,
                thumbnailData: thumbnailData,
                photos: PhotoLibrarySaver(),
                store: freePhotoStore
            )
            isSaving = false
            switch outcome {
            case .completed:
                if saveRequest.completeSuccess(
                    for: savedFingerprint,
                    currentFingerprint: exportFingerprint
                ) {
                    didAddToPrivateMap = true
                    saveConfirmation.markSaved(for: savedFingerprint)
                }
            case let .photoSavedMapFailed(assetIdentifier):
                if saveRequest.completeFailure(
                    for: savedFingerprint,
                    currentFingerprint: exportFingerprint
                ) {
                    recoveryRequest = request
                    recoveryThumbnailData = thumbnailData
                    saveError = AppText.value(
                        zh: "相片已儲存，但未能加入私人地圖。Photos 編號：\(assetIdentifier)",
                        en: "Photo saved, but it was not added to the private map. Photos ID: \(assetIdentifier)"
                    )
                }
            case .failed:
                if saveRequest.completeFailure(
                    for: savedFingerprint,
                    currentFingerprint: exportFingerprint
                ) {
                    saveError = AppText.value(
                        zh: "未能儲存到相簿，請檢查相片權限後再試。",
                        en: "Could not save to Photos. Check photo access and try again."
                    )
                }
            case .ignored:
                break
            }
        }
    }

    private func retryPrivateMapSave() {
        guard let recoveryRequest, let recoveryThumbnailData else { return }
        isSaving = true
        saveError = nil
        let outcome = saveCoordinator.retry(
            request: recoveryRequest,
            thumbnailData: recoveryThumbnailData,
            store: freePhotoStore
        )
        isSaving = false
        switch outcome {
        case .completed:
            self.recoveryRequest = nil
            self.recoveryThumbnailData = nil
            didAddToPrivateMap = true
            saveConfirmation.markSaved(for: exportFingerprint)
        case .photoSavedMapFailed:
            saveError = AppText.value(
                zh: "仍未能加入私人地圖，請稍後再試。",
                en: "Still could not add it to the private map. Try again later."
            )
        case .failed, .ignored:
            break
        }
    }

    private func privateMapThumbnailData(from image: UIImage) -> Data? {
        let size = CGSize(width: 320, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(
                x: (size.width - scaledSize.width) / 2,
                y: (size.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            ))
        }
        return thumbnail.jpegData(compressionQuality: 0.8)
    }

    private func resetSaveConfirmation() {
        saveCoordinator.invalidate()
        recoveryRequest = nil
        recoveryThumbnailData = nil
        didAddToPrivateMap = false
        saveConfirmation.clear()
        saveError = nil
        renderedAt = Date()
    }
}

private struct FreePhotoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.frogRow.weight(.bold))
            .foregroundStyle(FreePhotoPalette.navy)
            .frame(height: 48)
            .background(FreePhotoPalette.mist.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
