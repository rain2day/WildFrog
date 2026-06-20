import Foundation

enum AppLanguageMode: String, CaseIterable, Identifiable {
    case system
    case traditionalChinese = "zh-Hant"
    case english = "en"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .system:
            return AppText.value(zh: "系統", en: "System")
        case .traditionalChinese:
            return "中文"
        case .english:
            return "English"
        }
    }

    var title: String {
        switch self {
        case .system:
            return AppText.value(zh: "跟隨系統", en: "System")
        case .traditionalChinese:
            return AppText.value(zh: "繁體中文", en: "Traditional Chinese")
        case .english:
            return "English"
        }
    }
}

enum AppText {
    static let languagePreferenceKey = "wildfrog.language.mode"

    static var selectedLanguageMode: AppLanguageMode {
        let stored = UserDefaults.standard.string(forKey: languagePreferenceKey) ?? AppLanguageMode.system.rawValue
        return AppLanguageMode(rawValue: stored) ?? .system
    }

    static var isEnglish: Bool {
        switch selectedLanguageMode {
        case .english:
            return true
        case .traditionalChinese:
            return false
        case .system:
            break
        }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-qaEnglish") {
            return true
        }
        #endif

        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferred.hasPrefix("en") {
            return true
        }

        return Locale.current.language.languageCode?.identifier.lowercased() == "en"
    }

    static func value(zh: String, en: String) -> String {
        isEnglish ? en : zh
    }

    static var locale: Locale {
        Locale(identifier: isEnglish ? "en_US" : "zh_Hant_HK")
    }

    static func region(_ region: String) -> String {
        guard isEnglish else { return region }

        switch region {
        case "全部":
            return "All"
        case "新界":
            return "New Territories"
        case "大嶼山":
            return "Lantau"
        case "港島":
            return "Hong Kong Island"
        case "九龍":
            return "Kowloon"
        case "香港":
            return "Hong Kong"
        default:
            return region
        }
    }

    static func checkIns(_ count: Int) -> String {
        value(zh: "\(count) 次", en: "\(count) check-ins")
    }

    static func peaks(_ count: Int) -> String {
        value(zh: "\(count) 座", en: "\(count) peaks")
    }

    static func times(_ count: Int) -> String {
        value(zh: "\(count) 次", en: count == 1 ? "1 time" : "\(count) times")
    }

    static func monthLabel(year: Int, month: Int) -> String {
        guard isEnglish else { return "\(year)年\(month)月" }

        var components = DateComponents()
        components.year = year
        components.month = month
        let date = Calendar(identifier: .gregorian).date(from: components) ?? Date()
        return date.formatted(.dateTime.year().month(.wide).locale(locale))
    }

    static func monthOnly(_ month: Int) -> String {
        guard isEnglish else { return "\(month)月" }

        var components = DateComponents()
        components.month = month
        let date = Calendar(identifier: .gregorian).date(from: components) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).locale(locale))
    }

    static var shortWeekdays: [String] {
        isEnglish ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] : ["日", "一", "二", "三", "四", "五", "六"]
    }

    static func seedRegion(_ value: String) -> String {
        guard isEnglish else { return value }

        switch value {
        case "沙田": return "Sha Tin"
        case "港島東": return "Hong Kong East"
        case "大埔": return "Tai Po"
        case "西貢": return "Sai Kung"
        case "荃灣": return "Tsuen Wan"
        case "將軍澳": return "Tseung Kwan O"
        case "屯元天": return "Tuen Yuen Tin"
        case "離島": return "Islands"
        default: return region(value)
        }
    }

    static func hikerStyle(_ value: String) -> String {
        guard isEnglish else { return value }

        switch value {
        case "週末慢行": return "Weekend Rambler"
        case "收工散步": return "After-work Hiker"
        case "相機先行": return "Camera-first"
        case "日出線": return "Sunrise Route"
        case "越野跑": return "Trail Runner"
        case "海邊山徑": return "Coastal Trails"
        case "朋友約行": return "Friends' Hike"
        case "清晨上山": return "Early Start"
        case "短線常客": return "Short-route Regular"
        case "雨後打卡": return "After-rain Check-ins"
        case "親子慢走": return "Family Hikes"
        case "夜景路線": return "Night-view Routes"
        default: return value
        }
    }

    static func honorific(for mountain: Mountain) -> String {
        guard isEnglish else { return mountain.unlockTitle }
        return "Summiteer"
    }

    static func blurb(for mountain: Mountain) -> String {
        guard isEnglish else { return mountain.blurb }
        let name = mountain.nameEn.isEmpty ? mountain.nameZh : mountain.nameEn
        let rank = MountainCatalog.heightRank(for: mountain.id).map { "#\($0)" } ?? "an unranked peak"
        return "\(name) is \(rank) in the WildFrog peak passport, standing \(mountain.height)m above \(region(mountain.region)). Complete the summit check-in to save it to your personal Hong Kong mountain record."
    }
}
