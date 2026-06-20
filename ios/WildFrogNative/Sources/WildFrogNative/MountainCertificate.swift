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
        f.dateFormat = AppText.value(zh: "yyyy 年 MM 月 dd 日", en: "MMM d, yyyy")
        f.locale = Locale(identifier: AppText.value(zh: "zh_Hant_HK", en: "en_US"))
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            heroPhoto
            details
        }
        .frame(width: width)
        .background(certificateBackground)
        .overlay(certificateFrame)
    }

    /// Warm passport paper with a faint top-edge tint so the header feels
    /// "letterhead" rather than a flat fill.
    private var certificateBackground: some View {
        LinearGradient(
            colors: [FrogTheme.gold.opacity(0.05), FrogTheme.passport],
            startPoint: .top,
            endPoint: .init(x: 0.5, y: 0.22)
        )
        .background(FrogTheme.passport)
    }

    /// Engraved double rule — a confident gold border with a hairline inset,
    /// the signature of an official document rather than a single thin stroke.
    private var certificateFrame: some View {
        ZStack {
            Rectangle()
                .strokeBorder(FrogTheme.gold.opacity(0.85), lineWidth: 7)
            Rectangle()
                .strokeBorder(FrogTheme.gold.opacity(0.30), lineWidth: 2)
                .padding(13)
        }
    }

    // MARK: header

    private var header: some View {
        VStack(spacing: 22) {
            HStack(spacing: 20) {
                WildFrogBrandMark(size: 104, cornerRadius: 26)
                VStack(alignment: .leading, spacing: 5) {
                    (
                        Text("WILDFROG").foregroundStyle(FrogTheme.forest)
                        + Text(AppText.value(zh: " 登頂證書", en: " CERTIFICATE")).foregroundStyle(FrogTheme.gold)
                    )
                    .font(.system(size: 44, weight: .heavy))
                    .tracking(0.5)
                    Text("PEAK CONQUEST CERTIFICATE")
                        .font(.system(size: 23, weight: .bold))
                        .tracking(4.0)
                        .foregroundStyle(FrogTheme.gold.opacity(0.85))
                }
                Spacer(minLength: 0)
                rankMedal
            }

            // Gold seal rule closing the letterhead off from the photo.
            FrogTheme.gold.opacity(0.35)
                .frame(height: 2)
        }
        .padding(.horizontal, 60)
        .padding(.top, 56)
        .padding(.bottom, 30)
    }

    /// Rank as an earned medal — the one place trail-orange is spent, so #1
    /// reads hot against the calm paper.
    private var rankMedal: some View {
        VStack(spacing: 1) {
            Text(AppText.value(zh: "全港排名", en: "HK RANK"))
                .font(.system(size: 17, weight: .heavy))
                .tracking(2.0)
                .foregroundStyle(.white.opacity(0.85))
            Text(mountain.localizedRankText)
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
        .background(FrogTheme.orange, in: Capsule())
        .shadow(color: FrogTheme.orange.opacity(0.28), radius: 12, y: 5)
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
            .frame(width: width - 120, height: 560)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            // Mounted-print frame: gold edge + a fine inner highlight + soft drop.
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(FrogTheme.gold.opacity(0.9), lineWidth: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.5)
                    .padding(5)
            )
            .shadow(color: FrogTheme.warmShadow.opacity(0.18), radius: 22, y: 10)

            MountainStampSeal(mountain: mountain, size: 300, isUnlocked: true, rotation: .degrees(-8))
                .padding(20)
                .offset(x: 18, y: -18)
        }
        .padding(.horizontal, 60)
    }

    // MARK: details

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow — small gold label that frames the name as the certified subject.
            Text(AppText.value(zh: "此證頒予征服", en: "CERTIFIED SUMMIT OF"))
                .font(.system(size: 25, weight: .bold))
                .tracking(3.0)
                .foregroundStyle(FrogTheme.gold)
                .padding(.top, 34)

            // Monumental peak name — the single deepest-ink voice on the card.
            HStack(alignment: .lastTextBaseline, spacing: 18) {
                Text(mountain.localizedPrimaryName)
                    .font(.system(size: 96, weight: .black))
                    .tracking(-1)
                    .foregroundStyle(FrogTheme.forest)
                if !mountain.localizedSecondaryName.isEmpty {
                    Text(mountain.localizedSecondaryName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(FrogTheme.muted)
                        .padding(.bottom, 8)
                }
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .padding(.top, 10)

            // 稱號 — honorific seal line. Moss (live/earned) on the title, gold rosette,
            // bracketed by gold rules so it reads as a conferred rank, not a tinted chip.
            titleSeal
                .padding(.top, 30)

            // Facts ledger — ruled like an official record. Labels in gold (document
            // voice), values in moss (the live data the climber earned).
            HStack(spacing: 0) {
                fact(AppText.value(zh: "海拔", en: "ELEVATION"), "\(mountain.height)", unit: "m")
                factDivider
                fact(AppText.value(zh: "全港排名", en: "HK RANK"), mountain.localizedRankText, unit: "")
                factDivider
                fact(AppText.value(zh: "地區", en: "REGION"), mountain.localizedRegion, unit: "")
                factDivider
                fact(AppText.value(zh: "登頂", en: "SUMMITS"), "\(max(checkInCount, 1))", unit: AppText.value(zh: "次", en: ""))
            }
            .padding(.vertical, 30)
            .overlay(alignment: .top) { FrogTheme.gold.opacity(0.30).frame(height: 2) }
            .overlay(alignment: .bottom) { FrogTheme.gold.opacity(0.30).frame(height: 2) }
            .padding(.top, 38)

            if let weather {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 14) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(FrogTheme.moss)
                            .symbolRenderingMode(.hierarchical)
                        Text(AppText.value(zh: "登頂當時 · \(weather.conditionText) · \(weather.temperatureText)", en: "At summit · \(weather.conditionText) · \(weather.temperatureText)"))
                            .font(.system(size: 35, weight: .semibold))
                            .foregroundStyle(FrogTheme.muted)
                        Spacer(minLength: 0)
                    }

                    Text(" Weather · Data Sources")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(FrogTheme.gold)
                }
                .padding(.top, 30)
            }

            // Story blurb — warm ink body, the narrative voice.
            Text(mountain.localizedBlurb)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(FrogTheme.ink.opacity(0.84))
                .lineSpacing(15)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, weather == nil ? 34 : 26)

            // Official footer — date (muted) and motto (forest) on a hairline.
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppText.value(zh: "頒發日期", en: "ISSUED"))
                        .font(.system(size: 22, weight: .heavy))
                        .tracking(2.0)
                        .foregroundStyle(FrogTheme.gold)
                    Text(dateText)
                        .font(.system(size: 33, weight: .bold))
                        .foregroundStyle(FrogTheme.ink)
                }
                Spacer(minLength: 0)
                Text(AppText.value(zh: "愛自然 · 愛運動 · 愛香港", en: "LOVE NATURE · LOVE MOVEMENT · LOVE HK"))
                    .font(.system(size: 31, weight: .heavy))
                    .foregroundStyle(FrogTheme.forest)
            }
            .padding(.top, 40)
            .overlay(alignment: .top) {
                FrogTheme.line.frame(height: 1).offset(y: -20)
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 8)
        .padding(.bottom, 58)
    }

    /// 稱號 honorific, presented as a conferred seal: gold rosette + label, the
    /// title itself in moss, flanked by gold rules instead of a tinted box.
    private var titleSeal: some View {
        HStack(spacing: 16) {
            Image(systemName: "rosette")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(FrogTheme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppText.value(zh: "稱號", en: "TITLE"))
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(3.0)
                    .foregroundStyle(FrogTheme.gold)
                Text(mountain.localizedUnlockTitle)
                    .font(.system(size: 60, weight: .black))
                    .foregroundStyle(FrogTheme.moss)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
    }

    /// One ledger column. Label = gold (document voice), value = moss (earned data),
    /// optional unit set smaller so the figure stays the hero.
    private func fact(_ label: String, _ value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 26, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(FrogTheme.gold)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(FrogTheme.moss)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(FrogTheme.moss.opacity(0.7))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var factDivider: some View {
        FrogTheme.gold.opacity(0.22)
            .frame(width: 1.5, height: 96)
            .padding(.horizontal, 12)
    }
}

// MARK: - Share sheet

/// Presents the collectible certificate for one conquered mountain: renders the
/// 1080pt card to a UIImage on appear and offers it via ShareLink.
struct MountainCertificateSheet: View {
    let mountain: Mountain
    let checkInCount: Int
    /// When set, the certificate is for this exact check-in; otherwise the most
    /// recent one for the peak (used by the Profile shortcut).
    var recordId: UUID? = nil

    @EnvironmentObject private var checkInStore: CheckInStore
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?
    @State private var isRendering = false

    /// The check-in this certificate represents (drives photo, date, weather).
    private var targetRecord: CheckInRecord? {
        if let recordId {
            return checkInStore.records.first { $0.id == recordId }
        }
        return checkInStore.records
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

                    AppleWeatherAttributionLink()
                        .padding(.horizontal, FrogSpace.screenPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    shareButton
                        .padding(.horizontal, FrogSpace.screenPadding)
                }
                .padding(.bottom, 32)
            }
            .background(FrogTheme.warmPaper.ignoresSafeArea())
            .localizedNavigationTitle { AppText.value(zh: "登頂證書", en: "Summit Certificate") }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.value(zh: "完成", en: "Done")) { dismiss() }
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.forest)
                }
            }
        }
        .task { await prepare() }
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
                preview: SharePreview(AppText.value(zh: "WildFrog · \(mountain.nameZh) 登頂證書", en: "WildFrog · \(mountain.localizedName) Summit Certificate"), image: Image(uiImage: rendered))
            ) {
                Label(AppText.value(zh: "分享證書", en: "Share Certificate"), systemImage: "square.and.arrow.up")
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
                Text(AppText.value(zh: "生成中…", en: "Generating...")).font(.headline.weight(.black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(FrogTheme.orange.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    /// Backfills weather for an older record that never captured it, then renders.
    @MainActor
    private func prepare() async {
        guard rendered == nil, !isRendering else { return }
        isRendering = true
        if let record = targetRecord, record.weather == nil {
            let coordinate = MountainCatalog.mountain(id: mountain.id).coordinate
            if let snapshot = await WeatherFetcher.historicalSnapshot(for: coordinate, at: record.date) {
                checkInStore.attachWeather(snapshot, to: record.id)
            }
        }
        renderImage()
        isRendering = false
    }

    @MainActor
    private func renderImage() {
        let record = targetRecord
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
