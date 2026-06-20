import SwiftUI

enum WildFrogLegalLinks {
    static let base = URL(string: "https://wildfrog.rainsday.com/")!
    static let privacy = URL(string: "https://wildfrog.rainsday.com/privacy/")!
    static let terms = URL(string: "https://wildfrog.rainsday.com/terms/")!
    static let support = URL(string: "https://wildfrog.rainsday.com/support/")!
    static let appleWeatherAttribution = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
}

struct WildFrogLegalConsentFooter: View {
    var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(AppText.value(zh: "登入或建立帳戶即代表你同意 WildFrog 的使用條款及私隱政策。", en: "By signing in or creating an account, you agree to WildFrog's Terms of Use and Privacy Policy."))
                .font(.frogMicro)
                .foregroundStyle(FrogTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Link(AppText.value(zh: "使用條款", en: "Terms of Use"), destination: WildFrogLegalLinks.terms)
                Link(AppText.value(zh: "私隱政策", en: "Privacy Policy"), destination: WildFrogLegalLinks.privacy)
            }
            .font(.frogMicro.weight(.bold))
            .foregroundStyle(FrogTheme.moss)
        }
    }
}

struct AppleWeatherAttributionLink: View {
    var foreground: Color = FrogTheme.moss
    var font: Font = .frogMicro.weight(.bold)

    var body: some View {
        Link(destination: WildFrogLegalLinks.appleWeatherAttribution) {
            HStack(spacing: 5) {
                Text(" Weather")
                Text("·")
                    .foregroundStyle(foreground.opacity(0.65))
                Text(AppText.value(zh: "資料來源", en: "Data Sources"))
            }
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
        .accessibilityLabel(AppText.value(zh: "Apple Weather 資料來源", en: "Apple Weather data sources"))
    }
}
