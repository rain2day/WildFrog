import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MountainPhoto: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    let mountain: Mountain
    var dimming: Double = 0
    var showsSourceBadge = false
    var sourceBadgeTopPadding: CGFloat = 58

    var body: some View {
        GeometryReader { proxy in
            let userPhoto = illustrativeReplacementPhoto()

            ZStack {
                LinearGradient(
                    colors: [FrogTheme.ink, FrogTheme.moss.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let userPhoto {
                    Image(uiImage: userPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else if !mountain.imageName.isEmpty {
                    Image(mountain.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    WildFrogMark()
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: proxy.size.width * 0.4, height: proxy.size.width * 0.4)
                }

                Color.black.opacity(dimming)

                if showsSourceBadge {
                    imageSourceBadge(hasUserPhoto: userPhoto != nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, sourceBadgeTopPadding)
                        .padding(.trailing, 12)
                        .padding(.leading, 12)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func imageSourceBadge(hasUserPhoto: Bool) -> some View {
        if mountain.usesIllustrativeImage {
            Text(hasUserPhoto ? "你的實拍" : "示意圖 · 打卡相會取代")
                .font(.caption2.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.48), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
        }
    }

    private func illustrativeReplacementPhoto() -> UIImage? {
        #if canImport(UIKit)
        guard mountain.usesIllustrativeImage,
              let filename = checkInStore.latestPhotoFilename(for: mountain.id),
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }

        return UIImage(contentsOfFile: dir.appendingPathComponent(filename).path)
        #else
        return nil
        #endif
    }
}

struct MountainThumbnail: View {
    let mountain: Mountain
    var size: CGFloat = 54

    var body: some View {
        MountainPhoto(mountain: mountain, dimming: 0.12)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            )
    }
}
