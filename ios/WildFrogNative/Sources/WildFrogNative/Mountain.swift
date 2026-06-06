import CoreLocation
import Foundation

struct Mountain: Identifiable, Equatable {
    let id: String
    let nameZh: String
    let nameEn: String
    let region: String
    let height: Int
    let topRank: Int?
    let checkIns: Int
    let totalCheckIns: Int
    let imageName: String
    let coordinate: CLLocationCoordinate2D

    var displayName: String {
        nameEn.isEmpty ? nameZh : "\(nameZh) \(nameEn)"
    }

    var rankText: String {
        topRank.map { "#\($0)" } ?? "未排名"
    }

    static func == (lhs: Mountain, rhs: Mountain) -> Bool {
        lhs.id == rhs.id
    }
}

enum MountainCatalog {
    static let catalogCount = 329

    static let mountains: [Mountain] = [
        Mountain(
            id: "tai-mo-shan",
            nameZh: "大帽山",
            nameEn: "Tai Mo Shan",
            region: "新界",
            height: 957,
            topRank: 1,
            checkIns: 12,
            totalCheckIns: 1245,
            imageName: "MountainTaiMoShan",
            coordinate: CLLocationCoordinate2D(latitude: 22.411, longitude: 114.123)
        ),
        Mountain(
            id: "lantau-peak",
            nameZh: "鳳凰山",
            nameEn: "Lantau Peak",
            region: "大嶼山",
            height: 934,
            topRank: 2,
            checkIns: 7,
            totalCheckIns: 987,
            imageName: "MountainLantauPeak",
            coordinate: CLLocationCoordinate2D(latitude: 22.249, longitude: 113.921)
        ),
        Mountain(
            id: "sunset-peak",
            nameZh: "大東山",
            nameEn: "Sunset Peak",
            region: "大嶼山",
            height: 869,
            topRank: 3,
            checkIns: 6,
            totalCheckIns: 612,
            imageName: "MountainSunsetPeak",
            coordinate: CLLocationCoordinate2D(latitude: 22.263, longitude: 113.950)
        ),
        Mountain(
            id: "sei-fong-shan",
            nameZh: "四方山",
            nameEn: "",
            region: "新界",
            height: 785,
            topRank: 4,
            checkIns: 0,
            totalCheckIns: 0,
            imageName: "MountainTaiMoShan",
            coordinate: CLLocationCoordinate2D(latitude: 22.412, longitude: 114.119)
        ),
        Mountain(
            id: "ma-on-shan",
            nameZh: "馬鞍山",
            nameEn: "Ma On Shan",
            region: "新界",
            height: 702,
            topRank: 11,
            checkIns: 2,
            totalCheckIns: 406,
            imageName: "MountainTaiMoShan",
            coordinate: CLLocationCoordinate2D(latitude: 22.408, longitude: 114.245)
        ),
        Mountain(
            id: "lion-rock",
            nameZh: "獅子山",
            nameEn: "Lion Rock",
            region: "九龍",
            height: 495,
            topRank: 48,
            checkIns: 8,
            totalCheckIns: 2341,
            imageName: "MountainLionRock",
            coordinate: CLLocationCoordinate2D(latitude: 22.352, longitude: 114.187)
        ),
        Mountain(
            id: "victoria-peak",
            nameZh: "扯旗山",
            nameEn: "Victoria Peak",
            region: "港島",
            height: 552,
            topRank: 27,
            checkIns: 0,
            totalCheckIns: 0,
            imageName: "MountainLionRock",
            coordinate: CLLocationCoordinate2D(latitude: 22.275, longitude: 114.145)
        ),
        Mountain(
            id: "sharp-peak",
            nameZh: "蚺蛇尖",
            nameEn: "Sharp Peak",
            region: "新界",
            height: 468,
            topRank: 63,
            checkIns: 1,
            totalCheckIns: 192,
            imageName: "MountainTaiMoShan",
            coordinate: CLLocationCoordinate2D(latitude: 22.429, longitude: 114.370)
        ),
        Mountain(
            id: "violet-hill",
            nameZh: "紫羅蘭山",
            nameEn: "Violet Hill",
            region: "港島",
            height: 433,
            topRank: 76,
            checkIns: 0,
            totalCheckIns: 0,
            imageName: "MountainLionRock",
            coordinate: CLLocationCoordinate2D(latitude: 22.252, longitude: 114.198)
        ),
        Mountain(
            id: "high-junk-peak",
            nameZh: "釣魚翁",
            nameEn: "High Junk Peak",
            region: "新界",
            height: 344,
            topRank: 113,
            checkIns: 0,
            totalCheckIns: 0,
            imageName: "MountainLionRock",
            coordinate: CLLocationCoordinate2D(latitude: 22.300, longitude: 114.287)
        ),
    ]

    static func mountain(id: String) -> Mountain {
        mountains.first { $0.id == id } ?? mountains[0]
    }

    static var featured: [Mountain] {
        Array(mountains.prefix(4))
    }
}
