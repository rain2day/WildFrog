import SwiftUI

enum WildFrogLegalLinks {
    static let base = URL(string: "https://wildfrog.rainsday.com/")!
    static let privacy = URL(string: "https://wildfrog.rainsday.com/privacy/")!
    static let terms = URL(string: "https://wildfrog.rainsday.com/terms/")!
    static let support = URL(string: "https://wildfrog.rainsday.com/support/")!
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

            Text("登入或建立帳戶即代表你同意 WildFrog 的使用條款及私隱政策。")
                .font(.frogMicro)
                .foregroundStyle(FrogTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Link("使用條款", destination: WildFrogLegalLinks.terms)
                Link("私隱政策", destination: WildFrogLegalLinks.privacy)
            }
            .font(.frogMicro.weight(.bold))
            .foregroundStyle(FrogTheme.moss)
        }
    }
}
