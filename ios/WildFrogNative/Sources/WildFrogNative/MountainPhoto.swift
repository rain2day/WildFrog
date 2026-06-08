import SwiftUI

struct MountainPhoto: View {
    let mountain: Mountain
    var dimming: Double = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [FrogTheme.ink, FrogTheme.moss.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if !mountain.imageName.isEmpty {
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
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
        .accessibilityHidden(true)
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
