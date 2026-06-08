import SwiftUI

/// "Field Survey" palette — paper + pine + restrained trail orange.
/// Mirrors wildfrog.css :root. Names are kept stable so existing call sites
/// just inherit the warmer, lower-chroma values:
///   orange == --trail (RESERVED for primary CTA only)
///   moss   == --pine  (primary green: active state, secondary CTA)
enum FrogTheme {
    // trail orange — reserved for the single primary CTA / key accent
    static let orange = Color(red: 197 / 255, green: 83 / 255, blue: 42 / 255)   // #C5532A
    static let orangeSoft = Color(red: 241 / 255, green: 226 / 255, blue: 214 / 255) // #F1E2D6

    // greens — calm, low-chroma foliage
    static let moss = Color(red: 46 / 255, green: 99 / 255, blue: 71 / 255)      // #2E6347 pine
    static let mossSoft = Color(red: 227 / 255, green: 235 / 255, blue: 226 / 255) // #E3EBE2
    static let forest = Color(red: 18 / 255, green: 42 / 255, blue: 30 / 255)    // #122A1E
    static let leaf = Color(red: 107 / 255, green: 154 / 255, blue: 87 / 255)    // #6B9A57

    // ink — warm near-black, not cold slate
    static let ink = Color(red: 27 / 255, green: 32 / 255, blue: 24 / 255)       // #1B2018
    static let muted = Color(red: 95 / 255, green: 99 / 255, blue: 86 / 255)     // #5F6356
    static let faint = Color(red: 147 / 255, green: 150 / 255, blue: 138 / 255)  // #93968A

    // surfaces — field-log paper
    static let paper = Color(red: 241 / 255, green: 238 / 255, blue: 229 / 255)  // #F1EEE5
    static let warmPaper = Color(red: 246 / 255, green: 242 / 255, blue: 232 / 255) // #F6F2E8
    static let surface = Color(red: 252 / 255, green: 250 / 255, blue: 244 / 255) // #FCFAF4 raised panel
    static let surface2 = Color(red: 247 / 255, green: 243 / 255, blue: 234 / 255) // #F7F3EA
    static let passport = Color(red: 246 / 255, green: 242 / 255, blue: 232 / 255) // #F6F2E8
    static let mapWash = Color(red: 233 / 255, green: 236 / 255, blue: 221 / 255) // #E9ECDD

    static let line = Color(red: 27 / 255, green: 32 / 255, blue: 24 / 255).opacity(0.13)
    static let lineSoft = Color(red: 27 / 255, green: 32 / 255, blue: 24 / 255).opacity(0.08)
    static let gold = Color(red: 171 / 255, green: 132 / 255, blue: 60 / 255)    // #AB843C
    static let slate = Color(red: 95 / 255, green: 99 / 255, blue: 86 / 255)
    static let warmShadow = Color(red: 27 / 255, green: 32 / 255, blue: 24 / 255)
}

extension Font {
    // Field Survey type: no SF Rounded. Latin/CJK on SF Pro (→ PingFang for
    // Chinese); numerals get .frogNum for a tighter "field instrument" read.
    static let frogDisplay: Font = .system(size: 32, weight: .heavy)
    static let frogTitle: Font = .system(size: 20, weight: .bold)
    static let frogRow: Font = .system(size: 16, weight: .semibold)
    static let frogBody: Font = .system(size: 15, weight: .regular)
    static let frogCaption: Font = .system(size: 13, weight: .medium)
    static let frogMicro: Font = .system(size: 11, weight: .semibold)
    /// Small section label ("eyebrow"). Pair with .tracking + uppercase + muted.
    static let frogEyebrow: Font = .system(size: 11, weight: .bold)

    /// Numeral display — large stat figures. SF Pro (Space Grotesk swap = Pass 3).
    static func frogNum(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }
}

enum FrogSpace {
    static let screenPadding: CGFloat = 18
    static let cardGap: CGFloat = 22
    static let cardPadding: CGFloat = 16
    static let rowMinHeight: CGFloat = 64
    /// Generous gap between distinct content sections on a page.
    static let sectionGap: CGFloat = 30
}

/// Vector mountain mark from the Field Survey design
/// (svg `M3 19 9.5 6l3.5 7 2.2-4L21 19z`). Solid, tintable, resolution-
/// independent — replaces the raster brand asset.
struct WildFrogMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.minX + (rect.width - 24 * s) / 2
        let oy = rect.minY + (rect.height - 24 * s) / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var path = Path()
        path.move(to: pt(3, 19))
        path.addLine(to: pt(9.5, 6))
        path.addLine(to: pt(13, 13))
        path.addLine(to: pt(15.2, 9))
        path.addLine(to: pt(21, 19))
        path.closeSubpath()
        return path
    }
}

/// Brand chip — a solid rounded square holding the mountain mark. The simple,
/// solid-colour logo from the design.
struct WildFrogBrandMark: View {
    var size: CGFloat = 34
    var cornerRadius: CGFloat = 9
    var fill: Color = FrogTheme.forest
    var markColor: Color = .white

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(
                WildFrogMark()
                    .stroke(markColor, style: StrokeStyle(lineWidth: max(1.5, size * 0.072), lineCap: .round, lineJoin: .round))
                    .padding(size * 0.27)
            )
            .accessibilityLabel("WildFrog")
    }
}

/// Wordmark lockup — brand chip + "WildFrog". Defaults tuned for on-photo
/// (translucent chip, white text) like the design hero.
struct WildFrogWordmark: View {
    var markSize: CGFloat = 30
    var textColor: Color = .white
    var onPhoto: Bool = true

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: markSize * 0.3, style: .continuous)
                .fill(onPhoto ? Color.white.opacity(0.14) : FrogTheme.forest)
                .frame(width: markSize, height: markSize)
                .overlay(
                    RoundedRectangle(cornerRadius: markSize * 0.3, style: .continuous)
                        .stroke(onPhoto ? Color.white.opacity(0.28) : Color.clear, lineWidth: 1)
                )
                .overlay(
                    WildFrogMark()
                        .stroke(.white, style: StrokeStyle(lineWidth: max(1.5, markSize * 0.072), lineCap: .round, lineJoin: .round))
                        .padding(markSize * 0.27)
                )

            Text("WildFrog")
                .font(.system(size: markSize * 0.62, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(textColor)
        }
        .accessibilityElement()
        .accessibilityLabel("WildFrog")
    }
}

struct MountainStampSeal: View {
    let mountain: Mountain
    var size: CGFloat = 86
    var isUnlocked: Bool = true
    var rotation: Angle = .degrees(-7)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(mountain.stampImageName)
                .resizable()
                .scaledToFit()
                .saturation(isUnlocked ? 1 : 0.15)
                .opacity(isUnlocked ? 0.96 : 0.54)
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)

            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.13, weight: .black))
                    .foregroundStyle(FrogTheme.forest)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .background(FrogTheme.passport.opacity(0.96), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                    .offset(x: -2, y: 2)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(rotation)
        .accessibilityLabel(isUnlocked ? "\(mountain.nameZh) 山印" : "\(mountain.nameZh) 未解鎖山印")
    }
}

extension View {
    func appPageBackground(_ color: Color = FrogTheme.warmPaper) -> some View {
        self.background(color.ignoresSafeArea())
    }

    /// Field Survey panel — a hairline on warm surface, NOT a floating white card.
    /// One restrained elevation (wildfrog.css --shadow-soft); no contour noise.
    func cardStyle(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(FrogTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
            .shadow(color: FrogTheme.warmShadow.opacity(0.06), radius: 17, x: 0, y: 12)
    }

    func paperCardStyle(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(FrogTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )
            .shadow(color: FrogTheme.warmShadow.opacity(0.05), radius: 18, x: 0, y: 12)
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

struct FrogContourLines: View {
    let color: Color
    var lineWidth: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height

                for index in 0..<8 {
                    let y = height * CGFloat(index) / 7
                    path.move(to: CGPoint(x: -24, y: y + CGFloat(index % 2) * 5))
                    path.addCurve(
                        to: CGPoint(x: width + 24, y: y + 3),
                        control1: CGPoint(x: width * 0.28, y: y - 22),
                        control2: CGPoint(x: width * 0.66, y: y + 28)
                    )
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .allowsHitTesting(false)
    }
}
