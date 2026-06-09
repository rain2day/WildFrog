import CoreLocation
import Foundation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Best-effort current-weather lookup via WeatherKit, mapped to a WeatherSnapshot
/// for the summit certificate. Returns nil on ANY failure (missing entitlement,
/// offline, simulator quirks) so a check-in is never blocked — the certificate
/// simply omits the weather line when none was captured.
enum WeatherFetcher {
    static func snapshot(for coordinate: CLLocationCoordinate2D) async -> WeatherSnapshot? {
        #if canImport(WeatherKit)
        guard #available(iOS 16.0, *) else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            return WeatherSnapshot(
                symbolName: current.symbolName,
                conditionText: Self.localizedCondition(current.condition),
                temperatureC: current.temperature.converted(to: .celsius).value
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(WeatherKit)
    @available(iOS 16.0, *)
    private static func localizedCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear, .hot: return "晴"
        case .partlyCloudy: return "部分多雲"
        case .cloudy, .mostlyCloudy: return "多雲"
        case .foggy: return "有霧"
        case .haze: return "煙霞"
        case .windy, .breezy: return "有風"
        case .drizzle: return "毛毛雨"
        case .rain: return "有雨"
        case .heavyRain: return "大雨"
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms: return "雷暴"
        case .snow, .flurries, .heavySnow, .sleet: return "有雪"
        default: return "多雲"
        }
    }
    #endif
}
