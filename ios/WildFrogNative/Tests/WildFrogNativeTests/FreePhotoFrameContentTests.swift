import Foundation
import ImageIO
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import WildFrogNative

@Test func freePhotoStampIsTransparentRasterAndNeverVector() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let imageset = projectRoot
        .appendingPathComponent("Sources/WildFrogNative/Assets.xcassets/FreePhotoStampSeal.imageset")
    let png = imageset.appendingPathComponent("free-photo-stamp-seal.png")

    #expect(FileManager.default.fileExists(atPath: png.path))
    #expect(try FileManager.default.contentsOfDirectory(atPath: imageset.path)
        .allSatisfy { !$0.lowercased().hasSuffix(".svg") })

    let source = try #require(CGImageSourceCreateWithURL(png as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 1_024)
    #expect(image.height == 1_024)
    #expect(![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo))
}

@Test func freeFrameContentContainsOnlyApprovedMetadata() {
    let content = FreePhotoFrameContent(
        placeName: "城門水塘",
        altitudeMetres: 214,
        altitudeSource: .gpsApproximate,
        date: Date(timeIntervalSince1970: 0)
    )

    #expect(content.placeName == "城門水塘")
    #expect(content.altitudeLabel?.contains("214m") == true)
    #expect(content.altitudeLabel?.contains("GPS") == true)
    #expect(content.modeLabel.contains("FREE MOMENT"))
    #expect(content.rankLabel == nil)
    #expect(content.verificationLabel == nil)
    #expect(content.stampAssetName == nil)
}

@Test func emptyAltitudeOmitsTheAltitudeLine() {
    let content = FreePhotoFrameContent(
        placeName: "西貢海旁",
        altitudeMetres: nil,
        altitudeSource: .none,
        date: .now
    )

    #expect(content.altitudeLabel == nil)
    #expect(FreePhotoCardStyle.passport.label == AppText.value(zh: "護照", en: "Passport"))
}

@Test func frameContentCanHideDateAndCoordinatesIndependently() {
    let hidden = FreePhotoFrameContent(
        placeName: "西貢海旁",
        altitudeMetres: nil,
        altitudeSource: .none,
        date: nil,
        coordinate: nil
    )
    let coordinatesOnly = FreePhotoFrameContent(
        placeName: "西貢海旁",
        altitudeMetres: nil,
        altitudeSource: .none,
        date: nil,
        coordinate: FreePhotoCoordinate(latitude: -22.4084, longitude: -114.1201)
    )

    #expect(hidden.dateLabel == nil)
    #expect(hidden.coordinateLabel == nil)
    #expect(coordinatesOnly.dateLabel == nil)
    #expect(coordinatesOnly.coordinateLabel == "22.40840° S · 114.12010° W")
}

@MainActor
@Test func cameraImagePreparationCapsExportPixelDimensions() async throws {
    let sourceSize = CGSize(width: 2_400, height: 1_800)
    let source = UIGraphicsImageRenderer(size: sourceSize).image { context in
        UIColor.systemGreen.setFill()
        context.fill(CGRect(origin: .zero, size: sourceSize))
    }

    let prepared = try #require(await FreePhotoImagePreparer.prepare(source))
    let preparedPixels = CGSize(
        width: prepared.size.width * prepared.scale,
        height: prepared.size.height * prepared.scale
    )

    #expect(max(preparedPixels.width, preparedPixels.height) <= FreePhotoImagePreparer.maximumPixelDimension)
    #expect(prepared.imageOrientation == .up)

    let content = FreePhotoFrameContent(
        placeName: "High Resolution Camera",
        altitudeMetres: 438,
        altitudeSource: .gpsApproximate,
        date: .now,
        coordinate: FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201)
    )
    for style in FreePhotoCardStyle.allCases {
        let rendered = try #require(FreePhotoFrameRenderer.render(
            style: style,
            content: content,
            userPhoto: prepared
        ))
        #expect(rendered.size == FreePhotoFrameRenderContract(style: style).canvasSize)
    }
}

@MainActor
@Test func importedImageDataIsDownsampledBeforeExportRendering() async throws {
    let sourceSize = CGSize(width: 2_400, height: 1_800)
    let source = UIGraphicsImageRenderer(size: sourceSize).image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(origin: .zero, size: sourceSize))
    }
    let data = try #require(source.jpegData(compressionQuality: 0.9))

    let prepared = try #require(await FreePhotoImagePreparer.prepare(data: data))
    let preparedPixels = CGSize(
        width: prepared.size.width * prepared.scale,
        height: prepared.size.height * prepared.scale
    )

    #expect(max(preparedPixels.width, preparedPixels.height) <= FreePhotoImagePreparer.maximumPixelDimension)
    #expect(prepared.imageOrientation == .up)
}

@MainActor
@Test func editableFrameMetadataRendersInsideAStampSafeContractRegion() throws {
    let photo = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1080)).image { context in
        UIColor(red: 86 / 255, green: 139 / 255, blue: 168 / 255, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1080, height: 1080))
    }
    let full = FreePhotoFrameContent(
        placeName: "城門水塘",
        altitudeMetres: 214,
        altitudeSource: .manual,
        date: Date(timeIntervalSince1970: 0),
        coordinate: FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201)
    )
    let withoutDateOrCoordinates = FreePhotoFrameContent(
        placeName: full.placeName,
        altitudeMetres: full.altitudeMetres,
        altitudeSource: full.altitudeSource,
        date: nil,
        coordinate: nil
    )

    for style in FreePhotoCardStyle.allCases {
        let contract = FreePhotoFrameRenderContract(style: style)
        #expect(CGRect(origin: .zero, size: contract.canvasSize).contains(contract.metadataBounds))
        #expect(!contract.metadataBounds.intersects(contract.stampBounds))

        let rendered = try #require(FreePhotoFrameRenderer.render(
            style: style,
            content: full,
            userPhoto: photo,
            includeStamp: false
        ))
        let hidden = try #require(FreePhotoFrameRenderer.render(
            style: style,
            content: withoutDateOrCoordinates,
            userPhoto: photo,
            includeStamp: false
        ))
        let changedPixelBounds = try #require(rendered.changedPixelBounds(comparedTo: hidden))
        #expect(contract.metadataBounds.contains(changedPixelBounds))
    }
}

@MainActor
@Test func bothRenderersContainMaximumNameAndUseTheApprovedCoolPalette() throws {
    let maximumName = String(repeating: "W", count: FreePhotoFrameRenderContract.maximumPlaceNameCharacters)
    let content = FreePhotoFrameContent(
        placeName: maximumName,
        altitudeMetres: 9_000,
        altitudeSource: .manual,
        date: Date(timeIntervalSince1970: 0)
    )
    let photo = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1080)).image { context in
        UIColor(red: 86 / 255, green: 139 / 255, blue: 168 / 255, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1080, height: 1080))
    }

    for style in FreePhotoCardStyle.allCases {
        let contract = FreePhotoFrameRenderContract(style: style)
        let expectedStampBounds: CGRect = style == .passport
            ? CGRect(x: 736, y: 748, width: 220, height: 220)
            : CGRect(x: 724, y: 910, width: 236, height: 236)
        #expect(contract.nameBounds.minX >= 0)
        #expect(contract.nameBounds.minY >= 0)
        #expect(contract.nameBounds.maxX <= contract.canvasSize.width)
        #expect(contract.nameBounds.maxY <= contract.canvasSize.height)
        #expect(contract.stampBounds == expectedStampBounds)
        #expect(CGRect(origin: .zero, size: contract.canvasSize).contains(contract.stampBounds))
        #expect(!contract.nameBounds.intersects(contract.stampBounds))
        #expect(contract.approvedPalette == FreePhotoPalette.approvedRGB)

        let rendered = try #require(FreePhotoFrameRenderer.render(
            style: style,
            content: content,
            userPhoto: photo
        ))
        #expect(rendered.size == contract.canvasSize)

        let corner = try #require(rendered.rgbaPixel(x: Int(contract.canvasSize.width) - 2, y: Int(contract.canvasSize.height) - 2))
        #expect(contract.approvedPalette.contains { expected in
            abs(Int(expected.red) - Int(corner.red)) <= 2
                && abs(Int(expected.green) - Int(corner.green)) <= 2
                && abs(Int(expected.blue) - Int(corner.blue)) <= 2
        })

        let emptyNameContent = FreePhotoFrameContent(
            placeName: "",
            altitudeMetres: content.altitudeMetres,
            altitudeSource: content.altitudeSource,
            date: content.date
        )
        let emptyNameRender = try #require(FreePhotoFrameRenderer.render(
            style: style,
            content: emptyNameContent,
            userPhoto: photo
        ))
        let changedPixelBounds = try #require(rendered.changedPixelBounds(comparedTo: emptyNameRender))
        #expect(contract.nameBounds.contains(changedPixelBounds))

        let withoutStamp = try #require(FreePhotoFrameRenderer.render(
            style: style,
            content: content,
            userPhoto: photo,
            includeStamp: false
        ))
        let stampPixelBounds = try #require(rendered.changedPixelBounds(comparedTo: withoutStamp))
        #expect(contract.stampBounds.contains(stampPixelBounds))
    }
}

@MainActor
@Test func bothFramesKeepCopyAndSealInsideEightPercentSafeRegion() {
    for style in FreePhotoCardStyle.allCases {
        let contract = FreePhotoFrameRenderContract(style: style)
        let minimumInset = contract.canvasSize.width * 0.08
        #expect(contract.safeBounds.minX >= minimumInset)
        #expect(contract.safeBounds.maxX <= contract.canvasSize.width - minimumInset)
        #expect(contract.safeBounds.contains(contract.nameBounds))
        #expect(contract.safeBounds.contains(contract.metadataBounds))
        #expect(contract.safeBounds.contains(contract.stampBounds))
        #expect(!contract.nameBounds.intersects(contract.stampBounds))
        #expect(!contract.metadataBounds.intersects(contract.stampBounds))
    }
}

@MainActor
@Test func portraitCameraCaptureIsNotSquashedIntoLandscape() async throws {
    // A camera capture is a landscape buffer plus an orientation flag; the
    // displayed image is portrait.
    let buffer = UIGraphicsImageRenderer(size: CGSize(width: 2_400, height: 1_800)).image { context in
        UIColor.systemOrange.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2_400, height: 1_800))
        UIColor.systemIndigo.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2_400, height: 400))
    }
    let landscapeCG = try #require(buffer.cgImage)
    let portrait = UIImage(cgImage: landscapeCG, scale: 1, orientation: .right)
    #expect(portrait.size.width < portrait.size.height)

    let prepared = try #require(await FreePhotoImagePreparer.prepare(portrait))
    let preparedPixels = CGSize(
        width: prepared.size.width * prepared.scale,
        height: prepared.size.height * prepared.scale
    )

    #expect(preparedPixels.width < preparedPixels.height)
    let expectedAspect = portrait.size.width / portrait.size.height
    #expect(abs(preparedPixels.width - preparedPixels.height * expectedAspect) <= 1)
    #expect(max(preparedPixels.width, preparedPixels.height) <= FreePhotoImagePreparer.maximumPixelDimension)
    #expect(prepared.imageOrientation == .up)
}

@MainActor
@Test func fortyCharacterCJKNameKeepsClearOfTheNameBoundsEdges() throws {
    let name = String(repeating: "大東山日落位西貢海旁", count: 4)
    #expect(name.count == FreePhotoFrameRenderContract.maximumPlaceNameCharacters)

    let photo = UIGraphicsImageRenderer(size: CGSize(width: 1_080, height: 1_080)).image { context in
        UIColor(red: 86 / 255, green: 139 / 255, blue: 168 / 255, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1_080, height: 1_080))
    }
    let metadata = (altitude: 438, date: Date(timeIntervalSince1970: 0))

    for style in FreePhotoCardStyle.allCases {
        let contract = FreePhotoFrameRenderContract(style: style)
        let named = try #require(FreePhotoFrameRenderer.render(
            style: style,
            content: FreePhotoFrameContent(
                placeName: name,
                altitudeMetres: metadata.altitude,
                altitudeSource: .manual,
                date: metadata.date
            ),
            userPhoto: photo,
            includeStamp: false
        ))
        let unnamed = try #require(FreePhotoFrameRenderer.render(
            style: style,
            content: FreePhotoFrameContent(
                placeName: "",
                altitudeMetres: metadata.altitude,
                altitudeSource: .manual,
                date: metadata.date
            ),
            userPhoto: photo,
            includeStamp: false
        ))
        let ink = try #require(named.changedPixelBounds(comparedTo: unnamed))

        #expect(contract.nameBounds.contains(ink))
        #expect(ink.minX - contract.nameBounds.minX >= 4)
        #expect(contract.nameBounds.maxX - ink.maxX >= 4)
        #expect(contract.nameBounds.maxY - ink.maxY >= 4)
    }
}

@Test func exifWallClockDateBeatsACrossTimeZoneAssetInstant() throws {
    // Shot at 2026-08-20 00:30 JST. The Photos asset instant alone would stamp
    // the previous day once formatted in the app's Hong Kong convention.
    let assetInstant = try #require(
        ISO8601DateFormatter().date(from: "2026-08-19T15:30:00Z")
    )
    let data = try jpegData(exifDateTimeOriginal: "2026:08:20 00:30:00")

    let metadata = FreePhotoMetadataReader.metadata(from: data, acceptedAt: assetInstant)
    #expect(stampedDate(metadata.creationDate) == "2026.08.20")
    #expect(stampedDate(assetInstant) == "2026.08.19")
    #expect(FreePhotoMetadataReader.embeddedCreationDate(from: data) == metadata.creationDate)

    // An explicit OffsetTimeOriginal is honoured instead of the fallback zone.
    let withOffset = try jpegData(
        exifDateTimeOriginal: "2026:08:20 00:30:00",
        offsetTimeOriginal: "+09:00"
    )
    let offsetMetadata = FreePhotoMetadataReader.metadata(from: withOffset, acceptedAt: assetInstant)
    #expect(offsetMetadata.creationDate == assetInstant)

    // No EXIF timestamp at all falls back to the accepted-at instant.
    let bare = try jpegData(exifDateTimeOriginal: nil)
    #expect(FreePhotoMetadataReader.embeddedCreationDate(from: bare) == nil)
    #expect(FreePhotoMetadataReader.metadata(from: bare, acceptedAt: assetInstant).creationDate == assetInstant)
}

@Test func manualAltitudeStaysHonestAboutBeingApproximate() {
    let manual = FreePhotoFrameContent(
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .manual,
        date: nil
    )
    #expect(manual.altitudeLabel?.contains(AppText.value(zh: "約", en: "approx.")) == true)
    #expect((manual.altitudeLabel?.count ?? 100) <= 20)
}

private func stampedDate(_ date: Date) -> String? {
    FreePhotoFrameContent(
        placeName: "",
        altitudeMetres: nil,
        altitudeSource: .none,
        date: date
    ).dateLabel
}

private func jpegData(
    exifDateTimeOriginal: String?,
    offsetTimeOriginal: String? = nil
) throws -> Data {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
    }
    let cgImage = try #require(image.cgImage)
    let output = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(
        output,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ))
    var exif: [CFString: Any] = [:]
    if let exifDateTimeOriginal {
        exif[kCGImagePropertyExifDateTimeOriginal] = exifDateTimeOriginal
    }
    if let offsetTimeOriginal {
        exif[kCGImagePropertyExifOffsetTimeOriginal] = offsetTimeOriginal
    }
    CGImageDestinationAddImage(
        destination,
        cgImage,
        [kCGImagePropertyExifDictionary: exif] as CFDictionary
    )
    #expect(CGImageDestinationFinalize(destination))
    return output as Data
}

private extension UIImage {
    func changedPixelBounds(comparedTo other: UIImage) -> CGRect? {
        guard let lhs = cgImage,
              let rhs = other.cgImage,
              lhs.width == rhs.width,
              lhs.height == rhs.height,
              lhs.bytesPerRow == rhs.bytesPerRow,
              let lhsData = lhs.dataProvider?.data,
              let rhsData = rhs.dataProvider?.data,
              let lhsBytes = CFDataGetBytePtr(lhsData),
              let rhsBytes = CFDataGetBytePtr(rhsData) else { return nil }

        var minX = lhs.width
        var minY = lhs.height
        var maxX = -1
        var maxY = -1
        for y in 0..<lhs.height {
            for x in 0..<lhs.width {
                let offset = y * lhs.bytesPerRow + x * 4
                guard lhsBytes[offset] != rhsBytes[offset]
                        || lhsBytes[offset + 1] != rhsBytes[offset + 1]
                        || lhsBytes[offset + 2] != rhsBytes[offset + 2]
                        || lhsBytes[offset + 3] != rhsBytes[offset + 3] else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }

    func rgbaPixel(x: Int, y: Int) -> FreePhotoRGB? {
        guard let cgImage,
              x >= 0,
              y >= 0,
              x < cgImage.width,
              y < cgImage.height,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let offset = y * cgImage.bytesPerRow + x * 4
        return FreePhotoRGB(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2])
    }
}
