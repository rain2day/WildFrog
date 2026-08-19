import SwiftUI
import UIKit

enum FreePhotoCardStyle: String, CaseIterable, Identifiable {
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
    let placeName: String
    let altitudeMetres: Int?
    let altitudeSource: FreePhotoAltitudeSource
    let date: Date

    var modeLabel: String {
        AppText.value(zh: "FREE MOMENT · 自由足跡", en: "FREE MOMENT")
    }

    var altitudeLabel: String? {
        altitudeMetres.map { altitude in
            altitudeSource == .gpsApproximate
                ? AppText.value(zh: "GPS 海拔 · 約 \(altitude)m", en: "GPS altitude · approx. \(altitude)m")
                : AppText.value(zh: "海拔 · 約 \(altitude)m", en: "Altitude · approx. \(altitude)m")
        }
    }

    var rankLabel: String? { nil }
    var verificationLabel: String? { nil }
    var stampAssetName: String? { nil }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
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
            CGRect(x: 64, y: 1050, width: 620, height: 170)
        case .passport:
            CGRect(x: 64, y: 811, width: 610, height: 176)
        }
    }

    var stampBounds: CGRect {
        switch style {
        case .polaroid:
            CGRect(x: 706, y: 876, width: 280, height: 280)
        case .passport:
            CGRect(x: 694, y: 540, width: 360, height: 360)
        }
    }

    var approvedPalette: Set<FreePhotoRGB> { FreePhotoPalette.approvedRGB }
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
    private let padding: CGFloat = 64

    var body: some View {
        let photoSide = width - padding * 2

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
                    .padding(.top, padding)

                VStack(alignment: .leading, spacing: 20) {
                    Text(content.placeName)
                        .font(.system(size: 68, weight: .black))
                        .foregroundStyle(FreePhotoPalette.navy)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .frame(
                            width: contract.nameBounds.width,
                            height: contract.nameBounds.height,
                            alignment: .topLeading
                        )
                        .clipped()

                    HStack(alignment: .center, spacing: 18) {
                        Label(content.dateLabel, systemImage: "calendar")
                        if let altitudeLabel = content.altitudeLabel {
                            Label(altitudeLabel, systemImage: "mountain.2")
                        }
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FreePhotoPalette.blue)

                    HStack(spacing: 12) {
                        Image(systemName: "camera.aperture")
                        Text("WILDFROG · FREE PHOTO")
                            .tracking(2)
                    }
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(FreePhotoPalette.navy.opacity(0.68))
                }
                .padding(.horizontal, padding)
                .padding(.top, 34)
                .padding(.bottom, 56)
            }

            if showsStamp {
                FreePhotoStampSeal(size: contract.stampBounds.width)
                    .position(x: contract.stampBounds.midX, y: contract.stampBounds.midY)
            }
        }
        .frame(width: width, height: contract.canvasSize.height, alignment: .top)
        .background(FreePhotoPalette.paleMist)
        .clipped()
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
                            .padding(34)
                    }

                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Label("WILDFROG · FREE PHOTO", systemImage: "camera.aperture")
                            .font(.system(size: 23, weight: .heavy))
                            .tracking(1.6)
                            .foregroundStyle(FreePhotoPalette.blue)
                        Spacer()
                        Text(content.dateLabel)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(FreePhotoPalette.navy.opacity(0.62))
                    }

                    Text(content.placeName)
                        .font(.system(size: 74, weight: .black))
                        .foregroundStyle(FreePhotoPalette.navy)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .frame(
                            width: contract.nameBounds.width,
                            height: contract.nameBounds.height,
                            alignment: .topLeading
                        )
                        .clipped()

                    Rectangle()
                        .fill(FreePhotoPalette.blue.opacity(0.28))
                        .frame(height: 2)

                    if let altitudeLabel = content.altitudeLabel {
                        HStack {
                            Text(altitudeLabel)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(FreePhotoPalette.blue)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 40)
                .frame(width: width, height: stubHeight, alignment: .topLeading)
                .background(FreePhotoPalette.mist)
            }

            if showsStamp {
                FreePhotoStampSeal(size: contract.stampBounds.width)
                    .position(x: contract.stampBounds.midX, y: contract.stampBounds.midY)
            }
        }
        .frame(width: contract.canvasSize.width, height: contract.canvasSize.height)
        .background(FreePhotoPalette.mist)
    }
}
