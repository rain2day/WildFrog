import SwiftUI

// MARK: - CertificateShareSheet

struct CertificateShareSheet: View {
    let mountainCount: Int
    let onDismiss: () -> Void

    @State private var renderedImage: UIImage?
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("登頂紀念證書")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.forest)
                        .padding(.top, 8)

                    CertificateCard(mountainCount: mountainCount)
                        .padding(.horizontal, FrogSpace.screenPadding)

                    if let image = renderedImage {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(
                                "WildFrog Peak Explorer Certificate",
                                image: Image(uiImage: image)
                            )
                        ) {
                            Label("分享證書", systemImage: "square.and.arrow.up")
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, FrogSpace.screenPadding)
                    } else {
                        Button {
                            renderCertificate()
                        } label: {
                            HStack(spacing: 8) {
                                if isRendering {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                Text(isRendering ? "生成中…" : "生成並分享")
                                    .font(.headline.weight(.black))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isRendering)
                        .padding(.horizontal, FrogSpace.screenPadding)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(FrogTheme.warmPaper.ignoresSafeArea())
            .navigationTitle("證書分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { onDismiss() }
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.forest)
                }
            }
        }
        .onAppear {
            renderCertificate()
        }
    }

    @MainActor
    private func renderCertificate() {
        isRendering = true
        let renderer = ImageRenderer(content:
            CertificateCard(mountainCount: mountainCount)
                .frame(width: 360)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
        }
        isRendering = false
    }
}

// MARK: - CertificateCard (renderable standalone)

struct CertificateCard: View {
    let mountainCount: Int

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 MM 月 dd 日"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                WildFrogBrandMark(size: 48, cornerRadius: 11)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WildFrog")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.forest)
                    Text("Peak Explorer Certificate")
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.orange)
                }
                Spacer()
            }

            Divider()

            VStack(spacing: 8) {
                Text("登頂紀念證書")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(FrogTheme.muted)
                    .textCase(.uppercase)

                Text("香港山峰探索者")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(FrogTheme.forest)
                    .multilineTextAlignment(.center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已完成山峰")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                    Text("\(max(mountainCount, 1)) 座")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("頒發日期")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                    Text(dateString)
                        .font(.frogCaption.weight(.black))
                        .foregroundStyle(FrogTheme.ink)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(FrogTheme.orange)
                Text("愛自然 · 愛運動 · 愛香港")
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(FrogTheme.forest)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color(red: 252 / 255, green: 247 / 255, blue: 229 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FrogTheme.orange.opacity(0.28), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 12, y: 5)
    }
}
