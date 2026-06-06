import SwiftUI

enum FrogTheme {
    static let orange = Color(red: 252 / 255, green: 76 / 255, blue: 2 / 255)
    static let orangeSoft = Color(red: 1, green: 236 / 255, blue: 224 / 255)
    static let moss = Color(red: 26 / 255, green: 159 / 255, blue: 99 / 255)
    static let ink = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
    static let muted = Color(red: 96 / 255, green: 100 / 255, blue: 108 / 255)
    static let paper = Color(red: 247 / 255, green: 247 / 255, blue: 244 / 255)
    static let line = Color.black.opacity(0.1)
}

extension View {
    func cardStyle() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
    }

    @ViewBuilder
    func nativeInlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
