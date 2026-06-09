import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// WildFrog — collectible per-mountain summit certificate. Unlike the old generic
// "you climbed N peaks" card, every peak's certificate is unique: its own stamp
// (1 of 330), the user's summit photo, the mountain's story blurb, and the 稱號
// unlocked by conquering it. Designed at 1080pt wide for crisp sharing.

struct MountainCertificateCard: View {
    let mountain: Mountain
    let photo: UIImage?
    let checkInCount: Int
    let date: Date
    /// Weather captured at check-in (populated once WeatherKit is wired); hidden when nil.
    var weather: WeatherSnapshot? = nil

    private let width: CGFloat = 1080

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 MM 月 dd 日"
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            heroPhoto
            details
        }
        .frame(width: width)
        .background(FrogTheme.passport)
        .overlay(
            Rectangle()
                .strokeBorder(FrogTheme.gold.opacity(0.55), lineWidth: 6)
        )
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 18) {
            WildFrogBrandMark(size: 64, cornerRadius: 16)
            VStack(alignment: .leading, spacing: 3) {
                (
                    Text("WILDFROG ").foregroundStyle(FrogTheme.ink)
                    + Text("· 登頂證書").foregroundStyle(FrogTheme.gold)
                )
                .font(.system(size: 30, weight: .heavy))
                .tracking(1.2)
                Text("PEAK CONQUEST CERTIFICATE")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(FrogTheme.muted)
            }
            Spacer(minLength: 0)
            Text(mountain.rankText)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(FrogTheme.orange, in: Capsule())
        }
        .padding(.horizontal, 56)
        .padding(.top, 48)
        .padding(.bottom, 28)
    }

    // MARK: hero photo + pressed stamp

    private var heroPhoto: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Image(mountain.imageName).resizable().scaledToFill()
                }
            }
            .frame(width: width - 112, height: 560)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(FrogTheme.gold, lineWidth: 5)
            )

            MountainStampSeal(mountain: mountain, size: 300, isUnlocked: true, rotation: .degrees(-8))
                .padding(20)
                .offset(x: 18, y: -18)
        }
        .padding(.horizontal, 56)
    }

    // MARK: details

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(mountain.nameZh)
                    .font(.system(size: 76, weight: .black))
                    .foregroundStyle(FrogTheme.ink)
                Text(mountain.nameEn)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FrogTheme.muted)
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.top, 30)

            // 稱號 — the honorific unlocked by conquering this peak.
            HStack(spacing: 12) {
                Image(systemName: "rosette")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(FrogTheme.gold)
                Text("稱號")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FrogTheme.muted)
                Text(mountain.unlockTitle)
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(FrogTheme.forest)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FrogTheme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 22)

            // Facts strip.
            HStack(spacing: 0) {
                fact("海拔", "\(mountain.height)m")
                factDivider
                fact("全港排名", mountain.rankText)
                factDivider
                fact("地區", mountain.region)
                factDivider
                fact("登頂", "第 \(max(checkInCount, 1)) 次")
            }
            .padding(.top, 30)

            if let weather {
                HStack(spacing: 12) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(FrogTheme.moss)
                    Text("當時天氣 · \(weather.conditionText) · \(weather.temperatureText)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(FrogTheme.ink)
                    Spacer(minLength: 0)
                }
                .padding(.top, 26)
            }

            // Story blurb.
            Text(mountain.blurb)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(FrogTheme.ink.opacity(0.86))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)

            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
                .padding(.top, 30)

            HStack {
                Text("頒發日期 · \(dateText)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(FrogTheme.muted)
                Spacer(minLength: 0)
                Text("愛自然 · 愛運動 · 愛香港")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(FrogTheme.forest)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 56)
        .padding(.top, 14)
        .padding(.bottom, 52)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(FrogTheme.muted)
            Text(value)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(FrogTheme.forest)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var factDivider: some View {
        Rectangle()
            .fill(FrogTheme.line)
            .frame(width: 1, height: 54)
            .padding(.horizontal, 14)
    }
}

// MARK: - Share sheet

/// Presents the collectible certificate for one conquered mountain: renders the
/// 1080pt card to a UIImage on appear and offers it via ShareLink.
struct MountainCertificateSheet: View {
    let mountain: Mountain
    let checkInCount: Int

    @EnvironmentObject private var checkInStore: CheckInStore
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?
    @State private var isRendering = false

    /// The user's most recent check-in for this peak (drives photo, date, weather).
    private var latestRecord: CheckInRecord? {
        checkInStore.records
            .filter { $0.mountainId == mountain.id }
            .sorted { $0.date > $1.date }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    certificatePreview
                        .padding(.horizontal, FrogSpace.screenPadding)
                        .padding(.top, 10)

                    shareButton
                        .padding(.horizontal, FrogSpace.screenPadding)
                }
                .padding(.bottom, 32)
            }
            .background(FrogTheme.warmPaper.ignoresSafeArea())
            .navigationTitle("登頂證書")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.forest)
                }
            }
        }
        .onAppear(perform: render)
    }

    @ViewBuilder
    private var certificatePreview: some View {
        if let rendered {
            Image(uiImage: rendered)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FrogTheme.passport)
                .frame(height: 460)
                .overlay(ProgressView().tint(FrogTheme.forest))
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let rendered {
            ShareLink(
                item: Image(uiImage: rendered),
                preview: SharePreview("WildFrog · \(mountain.nameZh) 登頂證書", image: Image(uiImage: rendered))
            ) {
                Label("分享證書", systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("生成中…").font(.headline.weight(.black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(FrogTheme.orange.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @MainActor
    private func render() {
        guard rendered == nil, !isRendering else { return }
        isRendering = true
        let record = latestRecord
        let photo = Self.loadPhoto(record?.photoFilename)
        let renderer = ImageRenderer(content:
            MountainCertificateCard(
                mountain: mountain,
                photo: photo,
                checkInCount: checkInCount,
                date: record?.date ?? Date(),
                weather: record?.weather
            )
            .environment(\.colorScheme, .light)
        )
        renderer.scale = 2.0
        rendered = renderer.uiImage
        isRendering = false
    }

    /// Loads a summit photo from the documents directory by filename.
    private static func loadPhoto(_ filename: String?) -> UIImage? {
        #if canImport(UIKit)
        guard let filename, !filename.isEmpty,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let img = UIImage(contentsOfFile: dir.appendingPathComponent(filename).path)
        else { return nil }
        return img
        #else
        return nil
        #endif
    }
}
