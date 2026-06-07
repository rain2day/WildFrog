import SwiftUI

enum FrogTheme {
    static let orange = Color(red: 252 / 255, green: 76 / 255, blue: 2 / 255)
    static let orangeSoft = Color(red: 1, green: 236 / 255, blue: 224 / 255)
    static let moss = Color(red: 26 / 255, green: 159 / 255, blue: 99 / 255)
    static let forest = Color(red: 7 / 255, green: 35 / 255, blue: 26 / 255)
    static let leaf = Color(red: 148 / 255, green: 197 / 255, blue: 91 / 255)
    static let ink = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
    static let muted = Color(red: 96 / 255, green: 100 / 255, blue: 108 / 255)
    static let paper = Color(red: 247 / 255, green: 247 / 255, blue: 244 / 255)
    static let warmPaper = Color(red: 250 / 255, green: 247 / 255, blue: 239 / 255)
    static let passport = Color(red: 252 / 255, green: 247 / 255, blue: 229 / 255)
    static let mapWash = Color(red: 234 / 255, green: 242 / 255, blue: 226 / 255)
    static let line = Color.black.opacity(0.1)
    static let gold = Color(red: 212 / 255, green: 175 / 255, blue: 55 / 255)
    static let slate = Color(red: 91 / 255, green: 100 / 255, blue: 112 / 255)
}

extension Font {
    static let frogDisplay: Font = .system(size: 28, weight: .black, design: .rounded)
    static let frogTitle: Font = .system(size: 18, weight: .bold, design: .rounded)
    static let frogRow: Font = .system(size: 16, weight: .semibold)
    static let frogBody: Font = .system(size: 14, weight: .regular)
    static let frogCaption: Font = .system(size: 12, weight: .medium)
    static let frogMicro: Font = .system(size: 11, weight: .medium)
}

enum FrogSpace {
    static let screenPadding: CGFloat = 16
    static let cardGap: CGFloat = 18
    static let cardPadding: CGFloat = 14
    static let rowMinHeight: CGFloat = 62
}

struct WildFrogBrandMark: View {
    var size: CGFloat = 34
    var cornerRadius: CGFloat = 9

    var body: some View {
        Image("WildFrogBrandMark")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityLabel("WildFrog")
    }
}

extension View {
    func appPageBackground(_ color: Color = FrogTheme.warmPaper) -> some View {
        self.background(color.ignoresSafeArea())
    }

    func cardStyle() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    func paperCardStyle(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(Color.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
            .shadow(color: FrogTheme.forest.opacity(0.08), radius: 12, x: 0, y: 5)
    }

    func darkCardStyle() -> some View {
        self
            .background(FrogTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 8)
    }

    func primaryCTAStyle(cornerRadius: CGFloat = 14) -> some View {
        self
            .foregroundStyle(.white)
            .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: FrogTheme.orange.opacity(0.22), radius: 9, y: 4)
    }

    func controlStyle() -> some View {
        self
            .background(FrogTheme.moss.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
    }

    func chipStyle(isSelected: Bool) -> some View {
        self
            .font(.frogCaption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? FrogTheme.orange : Color.white.opacity(0.86))
            .foregroundStyle(isSelected ? Color.white : FrogTheme.ink)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? FrogTheme.orange : FrogTheme.line, lineWidth: 1))
    }

    @ViewBuilder
    func nativeInlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func hiddenNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
