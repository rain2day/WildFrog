import Foundation

struct FreePhotoCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    var isValid: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

enum FreePhotoLocationSource: String, Codable, Equatable {
    case cameraGPS
    case sourcePhotoMetadata
    case currentLocationChoice
    case manual
    case missing

    var localizedLabel: String {
        switch self {
        case .cameraGPS:
            AppText.value(zh: "拍攝時 GPS", en: "Camera GPS")
        case .sourcePhotoMetadata:
            AppText.value(zh: "原相片位置", en: "Photo Location")
        case .currentLocationChoice:
            AppText.value(zh: "目前位置", en: "Current Location")
        case .manual:
            AppText.value(zh: "手動設定", en: "Manual Location")
        case .missing:
            AppText.value(zh: "需要位置", en: "Needs Location")
        }
    }
}

struct FreePhotoRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let renderedAt: Date
    let placeName: String
    let altitudeMetres: Int?
    let altitudeSource: FreePhotoAltitudeSource
    let cardStyle: FreePhotoCardStyle
    var coordinate: FreePhotoCoordinate?
    var locationSource: FreePhotoLocationSource
    var horizontalAccuracy: Double?
    var locationTimestamp: Date?
    let photosAssetIdentifier: String?
    let thumbnailFilename: String

    var hasValidCoordinate: Bool {
        coordinate?.isValid == true && locationSource != .missing
    }
}

struct FreePhotoMapProjection {
    let located: [FreePhotoRecord]
    let needsLocation: [FreePhotoRecord]

    init(records: [FreePhotoRecord]) {
        let newestFirst = records.sorted { $0.createdAt > $1.createdAt }
        located = newestFirst.filter(\.hasValidCoordinate)
        needsLocation = newestFirst.filter { !$0.hasValidCoordinate }
    }
}

enum HomeMapLayer: String, CaseIterable, Identifiable {
    case peaks
    case freePhotos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .peaks: AppText.value(zh: "山峰", en: "Peaks")
        case .freePhotos: AppText.value(zh: "我的自由拍", en: "My Free Photos")
        }
    }
}

struct HomeMapLayerState: Equatable {
    private(set) var layer: HomeMapLayer = .peaks

    mutating func select(_ layer: HomeMapLayer) {
        self.layer = layer
    }

    var showsPeakMarkers: Bool { layer == .peaks }
    var showsFreePhotoMarkers: Bool { layer == .freePhotos }
}

struct FreePhotoMapClusterProjection: Equatable {
    let records: [FreePhotoRecord]

    init(records: [FreePhotoRecord]) {
        self.records = records.sorted { $0.createdAt > $1.createdAt }
    }

    var representative: FreePhotoRecord? { records.first }
}
