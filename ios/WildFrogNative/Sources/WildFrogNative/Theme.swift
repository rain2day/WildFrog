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
    static let frogDisplay: Font = .system(size: 34, weight: .black, design: .rounded)
    static let frogTitle: Font = .system(size: 22, weight: .bold, design: .rounded)
    static let frogRow: Font = .system(size: 17, weight: .semibold)
    static let frogBody: Font = .system(size: 15, weight: .regular)
    static let frogCaption: Font = .system(size: 13, weight: .medium)
    static let frogMicro: Font = .system(size: 11, weight: .semibold)
    /// Small section label ("eyebrow"). Pair with .tracking + muted colour.
    static let frogEyebrow: Font = .system(size: 12, weight: .bold)
}

enum FrogSpace {
    static let screenPadding: CGFloat = 18
    static let cardGap: CGFloat = 22
    static let cardPadding: CGFloat = 16
    static let rowMinHeight: CGFloat = 64
    /// Generous gap between distinct content sections on a page.
    static let sectionGap: CGFloat = 30
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

    /// Borderless floating surface — depth comes from a soft shadow, not a frame.
    func cardStyle(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }

    func paperCardStyle(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: FrogTheme.forest.opacity(0.07), radius: 20, x: 0, y: 12)
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
            .background(FrogTheme.ink.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Pill filter chip. Selected uses ink (not orange) — orange stays reserved
    /// for primary CTAs so the UI doesn't read as noisy.
    func chipStyle(isSelected: Bool) -> some View {
        self
            .font(.frogCaption.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? FrogTheme.ink : FrogTheme.ink.opacity(0.05))
            .foregroundStyle(isSelected ? Color.white : FrogTheme.muted)
            .clipShape(Capsule())
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
