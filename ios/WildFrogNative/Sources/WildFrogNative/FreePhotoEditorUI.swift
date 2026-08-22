import SwiftUI

enum FreePhotoEditorMetrics {
    static let pageInset: CGFloat = 20
    static let sectionGap: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let relatedGap: CGFloat = 12
    static let tightGap: CGFloat = 6
    static let minimumControlHeight: CGFloat = 48
    static let cardRadius: CGFloat = 20
    static let previewRadius: CGFloat = 24
}

enum FreePhotoMetadataVisibility: Equatable {
    case shown
    case hidden
    case notSet

    var label: String {
        switch self {
        case .shown: AppText.value(zh: "顯示", en: "Shown")
        case .hidden: AppText.value(zh: "隱藏", en: "Hidden")
        case .notSet: AppText.value(zh: "未設定", en: "Not set")
        }
    }
}

struct FreePhotoMetadataSummaryItem: Equatable {
    let title: String
    let value: String
    let visibility: FreePhotoMetadataVisibility
}

struct FreePhotoMetadataSummary: Equatable {
    let altitude: FreePhotoMetadataSummaryItem
    let date: FreePhotoMetadataSummaryItem
    let coordinates: FreePhotoMetadataSummaryItem

    init(draft: FreePhotoDraft) {
        let content = FreePhotoFrameContent(
            placeName: draft.validatedName,
            altitudeMetres: draft.altitudeMetres,
            altitudeSource: draft.altitudeSource,
            date: draft.frameDate,
            coordinate: draft.displayCoordinate,
            isDateEdited: draft.isDateEdited,
            isCoordinateEdited: draft.isCoordinateEdited
        )
        altitude = FreePhotoMetadataSummaryItem(
            title: AppText.value(zh: "海拔", en: "Alt."),
            value: draft.altitudeMetres.map { altitude in
                draft.altitudeSource == .gpsApproximate ? "\(altitude)m · GPS" : "\(altitude)m"
            } ?? AppText.value(zh: "未設定", en: "Not set"),
            visibility: draft.altitudeMetres == nil ? .notSet : .shown
        )
        date = FreePhotoMetadataSummaryItem(
            title: AppText.value(zh: "日期", en: "Date"),
            value: content.dateLabel ?? AppText.value(zh: "未設定", en: "Not set"),
            visibility: draft.showsDate ? .shown : .hidden
        )
        coordinates = FreePhotoMetadataSummaryItem(
            title: AppText.value(zh: "座標", en: "Coord."),
            value: draft.coordinateLabel ?? AppText.value(zh: "未設定", en: "Not set"),
            visibility: draft.displayCoordinate == nil
                ? .notSet
                : (draft.showsCoordinates ? .shown : .hidden)
        )
    }
}

struct FreePhotoEditorPresentation: Equatable {
    enum Mode: Equatable {
        case capture
        case studio
    }

    let mode: Mode
    let usesStickySave: Bool
    let showsExpandedMetadataOnCanvas: Bool

    init(hasPhoto: Bool) {
        mode = hasPhoto ? .studio : .capture
        usesStickySave = hasPhoto
        showsExpandedMetadataOnCanvas = false
    }
}

struct FreePhotoMetadataSummaryCard: View {
    @Binding var draft: FreePhotoDraft
    let onEdit: () -> Void

    private var summary: FreePhotoMetadataSummary {
        FreePhotoMetadataSummary(draft: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FreePhotoEditorMetrics.relatedGap) {
            HStack {
                Text(AppText.value(zh: "相框資料", en: "Frame details"))
                    .font(.frogRow.weight(.black))
                    .foregroundStyle(FreePhotoPalette.navy)
                Spacer()
                Button(action: onEdit) {
                    Label(AppText.value(zh: "編輯", en: "Edit"), systemImage: "slider.horizontal.3")
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FreePhotoPalette.blue)
                }
                .accessibilityHint(AppText.value(
                    zh: "編輯海拔、日期及顯示座標",
                    en: "Edit altitude, date, and display coordinates"
                ))
            }

            TextField(
                AppText.value(zh: "山名／地名", en: "Mountain or place name"),
                text: $draft.placeName
            )
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 14)
            .frame(minHeight: FreePhotoEditorMetrics.minimumControlHeight)
            .background(FreePhotoPalette.paleMist, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            HStack(spacing: 8) {
                summaryCell(item: summary.date, systemImage: "calendar")
                summaryCell(item: summary.altitude, systemImage: "mountain.2")
                summaryCell(item: summary.coordinates, systemImage: "location")
            }

            HStack {
                if let error = draft.validationError {
                    Label(error.message, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                } else {
                    Text(AppText.value(zh: "相框名稱最多 40 個字", en: "Frame name: up to 40 characters"))
                        .foregroundStyle(FreePhotoPalette.navy.opacity(0.5))
                }
                Spacer()
                Text("\(draft.validatedName.count)/40")
                    .foregroundStyle(draft.validatedName.count > 40 ? Color.red : FreePhotoPalette.navy.opacity(0.5))
            }
            .font(.frogMicro)
        }
        .padding(FreePhotoEditorMetrics.cardPadding)
        .background(.white, in: RoundedRectangle(cornerRadius: FreePhotoEditorMetrics.cardRadius, style: .continuous))
        .shadow(color: FreePhotoPalette.navy.opacity(0.07), radius: 14, y: 6)
    }

    private func summaryCell(item: FreePhotoMetadataSummaryItem, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Label(item.title, systemImage: systemImage)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if item.visibility != .notSet {
                    Image(systemName: item.visibility == .shown ? "eye.fill" : "eye.slash")
                        .foregroundStyle(FreePhotoPalette.blue.opacity(item.visibility == .shown ? 1 : 0.5))
                }
            }
            Text(item.value)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(FreePhotoPalette.navy)
        }
        .font(.frogMicro.weight(.bold))
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(FreePhotoPalette.mist.opacity(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.value), \(item.visibility.label)")
    }
}

struct FreePhotoMetadataEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: FreePhotoDraft

    private var altitudeText: Binding<String> {
        Binding(get: { draft.altitudeText }, set: { draft.setAltitudeText($0) })
    }

    private var latitudeText: Binding<String> {
        Binding(get: { draft.latitudeText }, set: { draft.setLatitudeText($0) })
    }

    private var longitudeText: Binding<String> {
        Binding(get: { draft.longitudeText }, set: { draft.setLongitudeText($0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FreePhotoEditorMetrics.sectionGap) {
                    metadataGroup(
                        title: AppText.value(zh: "海拔", en: "Altitude"),
                        systemImage: "mountain.2"
                    ) {
                        HStack {
                            TextField(AppText.value(zh: "米（可選）", en: "Metres (optional)"), text: altitudeText)
                                .keyboardType(.numbersAndPunctuation)
                            if draft.altitudeSource == .gpsApproximate {
                                Label(AppText.value(zh: "GPS 約數", en: "GPS approx."), systemImage: "location.fill")
                                    .font(.frogMicro.weight(.bold))
                                    .foregroundStyle(FreePhotoPalette.blue)
                            }
                        }
                        .fieldSurface()
                    }

                    metadataGroup(
                        title: AppText.value(zh: "日期", en: "Date"),
                        systemImage: "calendar"
                    ) {
                        Toggle(AppText.value(zh: "在相框顯示", en: "Show on frame"), isOn: $draft.showsDate)
                            .tint(FreePhotoPalette.blue)
                        if draft.showsDate {
                            DatePicker(
                                "",
                                selection: $draft.frameDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    metadataGroup(
                        title: AppText.value(zh: "顯示座標", en: "Display coordinates"),
                        systemImage: "location"
                    ) {
                        Toggle(AppText.value(zh: "在相框顯示", en: "Show on frame"), isOn: $draft.showsCoordinates)
                            .tint(FreePhotoPalette.blue)
                        Text(AppText.value(
                            zh: "會喺相片上印約 1 米精度嘅位置",
                            en: "Prints your location at ~1 m precision on the photo"
                        ))
                        .font(.frogMicro)
                        .foregroundStyle(FreePhotoPalette.navy.opacity(0.58))
                        if draft.showsCoordinates {
                            HStack(spacing: 10) {
                                coordinateField(title: AppText.value(zh: "緯度", en: "Latitude"), text: latitudeText)
                                coordinateField(title: AppText.value(zh: "經度", en: "Longitude"), text: longitudeText)
                            }
                        }
                        Text(AppText.value(
                            zh: "只會改相框顯示，唔會移動私人地圖上嘅位置。",
                            en: "This changes the frame only and never moves the pin on your private map."
                        ))
                        .font(.frogMicro)
                        .foregroundStyle(FreePhotoPalette.navy.opacity(0.58))
                    }

                    if let error = draft.validationError {
                        Label(error.message, systemImage: "exclamationmark.circle.fill")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, FreePhotoEditorMetrics.pageInset)
                .padding(.vertical, FreePhotoEditorMetrics.sectionGap)
            }
            .background(FreePhotoPalette.paleMist)
            .navigationTitle(AppText.value(zh: "編輯相框資料", en: "Edit Frame Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.value(zh: "完成", en: "Done")) { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func metadataGroup<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FreePhotoEditorMetrics.relatedGap) {
            Label(title, systemImage: systemImage)
                .font(.frogRow.weight(.black))
                .foregroundStyle(FreePhotoPalette.navy)
            content()
        }
        .padding(FreePhotoEditorMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: FreePhotoEditorMetrics.cardRadius, style: .continuous))
    }

    private func coordinateField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: FreePhotoEditorMetrics.tightGap) {
            Text(title)
                .font(.frogMicro.weight(.bold))
                .foregroundStyle(FreePhotoPalette.navy.opacity(0.68))
            TextField(title, text: text)
                .keyboardType(.numbersAndPunctuation)
                .fieldSurface()
        }
    }
}

private extension View {
    func fieldSurface() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(minHeight: FreePhotoEditorMetrics.minimumControlHeight)
            .background(FreePhotoPalette.paleMist, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

extension FreePhotoValidationError {
    var message: String {
        switch self {
        case .missingPlaceName:
            AppText.value(zh: "請輸入山名或地名。", en: "Enter a mountain or place name.")
        case .placeNameTooLong:
            AppText.value(zh: "名稱最多 40 個字。", en: "The name can contain up to 40 characters.")
        case .missingCoordinates:
            AppText.value(zh: "請輸入緯度及經度。", en: "Enter both latitude and longitude.")
        case .invalidCoordinates:
            AppText.value(zh: "座標必須使用有效數字。", en: "Coordinates must be valid numbers.")
        case .coordinatesOutOfRange:
            AppText.value(zh: "緯度需介乎 -90 至 90；經度需介乎 -180 至 180。", en: "Latitude must be -90 to 90 and longitude -180 to 180.")
        case .invalidAltitude:
            AppText.value(zh: "海拔請輸入整數。", en: "Altitude must be a whole number.")
        case .altitudeOutOfRange:
            AppText.value(zh: "海拔需介乎 -500 至 9,000 米。", en: "Altitude must be between -500 and 9,000 metres.")
        }
    }
}
