import Foundation
import ImageIO
import SwiftUI
import Testing
import UIKit
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
            ? CGRect(x: 694, y: 540, width: 360, height: 360)
            : CGRect(x: 706, y: 876, width: 280, height: 280)
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
