import ImageIO
import SwiftUI
import UIKit

enum FreePhotoCardStyle: String, Codable, CaseIterable, Identifiable {
    case polaroid
    case passport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .polaroid: AppText.value(zh: "拍立得", en: "Polaroid")
        case .passport: AppText.value(zh: "護照", en: "Passport")
        }
    }
}

struct FreePhotoFrameContent: Equatable {
    /// Frames stamp a wall-clock date, so the formatter is pinned to the app's
    /// Hong Kong convention instead of drifting with the device time zone.
    static let displayTimeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current

    static var editedLabel: String { AppText.value(zh: "手動", en: "edited") }

    let placeName: String
    let altitudeMetres: Int?
    let altitudeSource: FreePhotoAltitudeSource
    let date: Date?
    let coordinate: FreePhotoCoordinate?
    let isDateEdited: Bool
    let isCoordinateEdited: Bool

    init(
        placeName: String,
        altitudeMetres: Int?,
        altitudeSource: FreePhotoAltitudeSource,
        date: Date?,
        coordinate: FreePhotoCoordinate? = nil,
        isDateEdited: Bool = false,
        isCoordinateEdited: Bool = false
    ) {
        self.placeName = placeName
        self.altitudeMetres = altitudeMetres
        self.altitudeSource = altitudeSource
        self.date = date
        self.coordinate = coordinate
        self.isDateEdited = isDateEdited
        self.isCoordinateEdited = isCoordinateEdited
    }

    var modeLabel: String {
        AppText.value(zh: "FREE MOMENT · 自由足跡", en: "FREE MOMENT")
    }

    var altitudeLabel: String? {
        altitudeMetres.map { altitude in
            altitudeSource == .gpsApproximate
                ? AppText.value(zh: "GPS · 約 \(altitude)m", en: "GPS · approx. \(altitude)m")
                : AppText.value(zh: "海拔 · 約 \(altitude)m", en: "Alt. · approx. \(altitude)m")
        }
    }

    var rankLabel: String? { nil }
    var verificationLabel: String? { nil }
    var stampAssetName: String? { nil }

    var dateLabel: String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = Self.displayTimeZone
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    var coordinateLabel: String? {
        guard let coordinate, coordinate.isValid else { return nil }
        let latitudeDirection = coordinate.latitude < 0 ? "S" : "N"
        let longitudeDirection = coordinate.longitude < 0 ? "W" : "E"
        return String(
            format: "%.5f° %@ · %.5f° %@",
            locale: Locale(identifier: "en_US_POSIX"),
            abs(coordinate.latitude),
            latitudeDirection,
            abs(coordinate.longitude),
            longitudeDirection
        )
    }
}

enum FreePhotoPalette {
    static let mist = Color(red: 226 / 255, green: 238 / 255, blue: 245 / 255)
    static let paleMist = Color(red: 244 / 255, green: 249 / 255, blue: 252 / 255)
    static let navy = Color(red: 22 / 255, green: 48 / 255, blue: 68 / 255)
    static let blue = Color(red: 86 / 255, green: 139 / 255, blue: 168 / 255)
    static let white = Color.white

    static let approvedRGB: Set<FreePhotoRGB> = [
        FreePhotoRGB(red: 226, green: 238, blue: 245),
        FreePhotoRGB(red: 244, green: 249, blue: 252),
        FreePhotoRGB(red: 22, green: 48, blue: 68),
        FreePhotoRGB(red: 86, green: 139, blue: 168),
        FreePhotoRGB(red: 255, green: 255, blue: 255)
    ]
}

struct FreePhotoRGB: Hashable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

struct FreePhotoFrameRenderContract: Equatable {
    static let maximumPlaceNameCharacters = 40
    static let safeInset: CGFloat = 88

    let style: FreePhotoCardStyle

    var canvasSize: CGSize {
        switch style {
        case .polaroid: CGSize(width: 1080, height: 1400)
        case .passport: CGSize(width: 1080, height: 1110)
        }
    }

    var nameBounds: CGRect {
        switch style {
        case .polaroid:
            CGRect(x: 88, y: 1050, width: 600, height: 130)
        case .passport:
            CGRect(x: 88, y: 787, width: 570, height: 130)
        }
    }

    var stampBounds: CGRect {
        switch style {
        case .polaroid:
            CGRect(x: 724, y: 910, width: 236, height: 236)
        case .passport:
            CGRect(x: 736, y: 748, width: 220, height: 220)
        }
    }

    var metadataBounds: CGRect {
        switch style {
        case .polaroid:
            CGRect(x: 88, y: 1_190, width: 600, height: 88)
        case .passport:
            CGRect(x: 88, y: 935, width: 570, height: 80)
        }
    }

    var safeBounds: CGRect {
        CGRect(
            x: Self.safeInset,
            y: Self.safeInset,
            width: canvasSize.width - Self.safeInset * 2,
            height: canvasSize.height - Self.safeInset * 2
        )
    }

    var approvedPalette: Set<FreePhotoRGB> { FreePhotoPalette.approvedRGB }

    /// Inset applied inside `nameBounds` so glyph ink never touches the reserved box.
    var nameInset: CGFloat { 10 }

    /// Smallest shrink allowed before the place name clips. Sized so 40 CJK
    /// characters wrap to two lines inside `nameBounds` minus `nameInset`.
    var nameMinimumScaleFactor: CGFloat {
        switch style {
        case .polaroid: 0.42
        case .passport: 0.36
        }
    }
}

struct FreePhotoPreviewLayout: Equatable {
    let style: FreePhotoCardStyle

    private var canvasSize: CGSize {
        FreePhotoFrameRenderContract(style: style).canvasSize
    }

    var aspectRatio: CGFloat {
        canvasSize.width / canvasSize.height
    }

    func height(forAvailableWidth width: CGFloat) -> CGFloat {
        guard width > 0, canvasSize.width > 0 else { return 0 }
        return width * canvasSize.height / canvasSize.width
    }
}

enum FreePhotoImagePreparer {
    static let maximumPixelDimension: CGFloat = 2_048

    /// Full-resolution decode + redraw is CPU and memory heavy, so both entry
    /// points are nonisolated and hop onto a detached task. Callers await the
    /// result and assign it back on the main actor.
    nonisolated static func prepare(data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            downsample(data: data)
        }.value
    }

    nonisolated static func prepare(_ image: UIImage) async -> UIImage? {
        // `image.size` is the orientation-applied logical size; multiplying by
        // `scale` gives the displayed pixel box. Using `cgImage.width/height`
        // here would describe the pre-orientation buffer and squash portrait
        // camera captures into landscape.
        let orientedPixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        guard orientedPixelSize.width > 0, orientedPixelSize.height > 0 else { return nil }

        return await Task.detached(priority: .userInitiated) {
            // Round-trip through JPEG so the bounded ImageIO thumbnail decode
            // does the resampling instead of a full-size `draw(in:)` bitmap.
            if let data = image.jpegData(compressionQuality: 0.95),
               let downsampled = downsample(data: data) {
                return downsampled
            }
            return redraw(image, orientedPixelSize: orientedPixelSize)
        }.value
    }

    nonisolated static func downsample(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                  source,
                  0,
                  [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: Int(maximumPixelDimension),
                      kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary
              ) else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    nonisolated private static func redraw(
        _ image: UIImage,
        orientedPixelSize: CGSize
    ) -> UIImage? {
        let longestSide = max(orientedPixelSize.width, orientedPixelSize.height)
        guard longestSide > 0 else { return nil }
        let scale = min(1, maximumPixelDimension / longestSide)
        let targetSize = CGSize(
            width: max(1, (orientedPixelSize.width * scale).rounded()),
            height: max(1, (orientedPixelSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

@MainActor
enum FreePhotoFrameRenderer {
    static func render(
        style: FreePhotoCardStyle,
        content: FreePhotoFrameContent,
        userPhoto: UIImage,
        includeStamp: Bool = true
    ) -> UIImage? {
        let renderer: ImageRenderer<AnyView>
        switch style {
        case .polaroid:
            renderer = ImageRenderer(content: AnyView(
                FreePhotoPolaroidCardView(
                    content: content,
                    userPhoto: userPhoto,
                    showsStamp: includeStamp
                )
            ))
        case .passport:
            renderer = ImageRenderer(content: AnyView(
                FreePhotoPassportCardView(
                    content: content,
                    userPhoto: userPhoto,
                    showsStamp: includeStamp
                )
            ))
        }
        renderer.scale = 1
        return renderer.uiImage
    }
}

struct FreePhotoEditedTag: View {
    var body: some View {
        Text(FreePhotoFrameContent.editedLabel)
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(FreePhotoPalette.blue)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(FreePhotoPalette.blue, lineWidth: 1.5)
            )
    }
}

struct FreePhotoStampSeal: View {
    let size: CGFloat

    var body: some View {
        Image("FreePhotoStampSeal")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(0.92)
            .rotationEffect(.degrees(-8))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct FreePhotoPolaroidCardView: View {
    let content: FreePhotoFrameContent
    let userPhoto: UIImage
    var showsStamp = true

    private let contract = FreePhotoFrameRenderContract(style: .polaroid)
    private var width: CGFloat { contract.canvasSize.width }
    private let photoPadding: CGFloat = 64
    private let copyPadding: CGFloat = FreePhotoFrameRenderContract.safeInset

    var body: some View {
        let photoSide = width - photoPadding * 2

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Image(uiImage: userPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoSide, height: photoSide)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        freeMomentBadge
                            .padding(30)
                    }
                    .padding(.top, photoPadding)

                VStack(alignment: .leading, spacing: 0) {
                    Text(content.placeName)
                        .font(.system(size: 68, weight: .black))
                        .foregroundStyle(FreePhotoPalette.navy)
                        .lineLimit(2)
                        .minimumScaleFactor(contract.nameMinimumScaleFactor)
                        .allowsTightening(true)
                        .frame(
                            width: contract.nameBounds.width - contract.nameInset * 2,
                            height: contract.nameBounds.height - contract.nameInset * 2,
                            alignment: .topLeading
                        )
                        .padding(contract.nameInset)
                        .frame(
                            width: contract.nameBounds.width,
                            height: contract.nameBounds.height,
                            alignment: .topLeading
                        )
                        .clipped()

                    Spacer()
                        .frame(height: 10)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 18) {
                            if let dateLabel = content.dateLabel {
                                HStack(spacing: 6) {
                                    Label(dateLabel, systemImage: "calendar")
                                    if content.isDateEdited { editedTag }
                                }
                            }
                            if let altitudeLabel = content.altitudeLabel {
                                Label(altitudeLabel, systemImage: "mountain.2")
                            }
                            Spacer(minLength: 0)
                        }

                        if let coordinateLabel = content.coordinateLabel {
                            HStack(spacing: 6) {
                                Label(coordinateLabel, systemImage: "location")
                                if content.isCoordinateEdited { editedTag }
                            }
                        }
                    }
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(FreePhotoPalette.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(
                        width: contract.metadataBounds.width,
                        height: contract.metadataBounds.height,
                        alignment: .topLeading
                    )
                    .clipped()

                    Spacer()
                        .frame(height: 8)

                    brandFooter
                }
                .frame(width: width - copyPadding * 2, alignment: .leading)
                .padding(.horizontal, copyPadding)
                .padding(.top, 34)
                .padding(.bottom, 88)
            }
            .frame(
                width: contract.canvasSize.width,
                height: contract.canvasSize.height,
                alignment: .top
            )

            if showsStamp {
                FreePhotoStampSeal(size: contract.stampBounds.width)
                    .position(x: contract.stampBounds.midX, y: contract.stampBounds.midY)
            }
        }
        .frame(width: width, height: contract.canvasSize.height, alignment: .top)
        .background(FreePhotoPalette.paleMist)
        .clipped()
    }

    private var brandFooter: some View {
        Text("WILDFROG · FREE PHOTO")
            .font(.system(size: 20, weight: .heavy))
            .tracking(1.8)
            .foregroundStyle(FreePhotoPalette.blue)
            .frame(width: contract.nameBounds.width, height: 26, alignment: .leading)
    }

    private var editedTag: some View {
        FreePhotoEditedTag()
    }

    private var freeMomentBadge: some View {
        Text(content.modeLabel)
            .font(.system(size: 24, weight: .black))
            .tracking(1.5)
            .foregroundStyle(FreePhotoPalette.navy)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(FreePhotoPalette.white.opacity(0.9), in: Capsule())
            .overlay(Capsule().stroke(FreePhotoPalette.blue.opacity(0.45), lineWidth: 2))
    }
}

struct FreePhotoPassportCardView: View {
    let content: FreePhotoFrameContent
    let userPhoto: UIImage
    var showsStamp = true

    private let contract = FreePhotoFrameRenderContract(style: .passport)
    private var width: CGFloat { contract.canvasSize.width }
    private let photoHeight: CGFloat = 720
    private let stubHeight: CGFloat = 390

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Image(uiImage: userPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: photoHeight)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Text(content.modeLabel)
                            .font(.system(size: 23, weight: .black))
                            .tracking(1.4)
                            .foregroundStyle(FreePhotoPalette.navy)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(FreePhotoPalette.white.opacity(0.9), in: Capsule())
                            .padding(FreePhotoFrameRenderContract.safeInset)
                    }

                VStack(alignment: .leading, spacing: 0) {
                    // The photo-overlay capsule is the single Free Photo identity
                    // mark on this style; a second stub header competed with the
                    // place name, so it was removed.
                    Text(content.placeName)
                        .font(.system(size: 74, weight: .black))
                        .foregroundStyle(FreePhotoPalette.navy)
                        .lineLimit(2)
                        .minimumScaleFactor(contract.nameMinimumScaleFactor)
                        .allowsTightening(true)
                        .frame(
                            width: contract.nameBounds.width - contract.nameInset * 2,
                            height: contract.nameBounds.height - contract.nameInset * 2,
                            alignment: .topLeading
                        )
                        .padding(contract.nameInset)
                        .frame(
                            width: contract.nameBounds.width,
                            height: contract.nameBounds.height,
                            alignment: .topLeading
                        )
                        .clipped()

                    Spacer().frame(height: 8)

                    Rectangle()
                        .fill(FreePhotoPalette.blue.opacity(0.28))
                        .frame(width: contract.nameBounds.width, height: 2)

                    Spacer().frame(height: 8)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 14) {
                            if let dateLabel = content.dateLabel {
                                HStack(spacing: 6) {
                                    Label(dateLabel, systemImage: "calendar")
                                    if content.isDateEdited { FreePhotoEditedTag() }
                                }
                            }
                            if let altitudeLabel = content.altitudeLabel {
                                Label(altitudeLabel, systemImage: "mountain.2")
                            }
                        }
                        if let coordinateLabel = content.coordinateLabel {
                            HStack(spacing: 6) {
                                Label(coordinateLabel, systemImage: "location")
                                if content.isCoordinateEdited { FreePhotoEditedTag() }
                            }
                        }
                    }
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(FreePhotoPalette.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(
                        width: contract.metadataBounds.width,
                        height: contract.metadataBounds.height,
                        alignment: .topLeading
                    )
                    .clipped()
                }
                .padding(.horizontal, FreePhotoFrameRenderContract.safeInset)
                .padding(.top, 67)
                .frame(width: width, height: stubHeight, alignment: .topLeading)
                .background(FreePhotoPalette.mist)
            }
            .frame(
                width: contract.canvasSize.width,
                height: contract.canvasSize.height,
                alignment: .top
            )

            if showsStamp {
                FreePhotoStampSeal(size: contract.stampBounds.width)
                    .position(x: contract.stampBounds.midX, y: contract.stampBounds.midY)
            }
        }
        .frame(width: contract.canvasSize.width, height: contract.canvasSize.height)
        .background(FreePhotoPalette.mist)
    }
}
