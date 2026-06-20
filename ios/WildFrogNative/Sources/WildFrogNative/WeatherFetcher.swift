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

    /// Historical weather for a past check-in (date + coordinate), used to backfill
    /// records that predate live capture. Picks the hour closest to `date`.
    static func historicalSnapshot(for coordinate: CLLocationCoordinate2D, at date: Date) async -> WeatherSnapshot? {
        #if canImport(WeatherKit)
        guard #available(iOS 16.0, *) else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let hourly = try await WeatherService.shared.weather(
                for: location,
                including: .hourly(startDate: date.addingTimeInterval(-3600),
                                   endDate: date.addingTimeInterval(3600))
            )
            guard let closest = hourly.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }) else { return nil }
            return WeatherSnapshot(
                symbolName: closest.symbolName,
                conditionText: Self.localizedCondition(closest.condition),
                temperatureC: closest.temperature.converted(to: .celsius).value
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
        case .clear, .mostlyClear, .hot: return AppText.value(zh: "晴", en: "Clear")
        case .partlyCloudy: return AppText.value(zh: "部分多雲", en: "Partly Cloudy")
        case .cloudy, .mostlyCloudy: return AppText.value(zh: "多雲", en: "Cloudy")
        case .foggy: return AppText.value(zh: "有霧", en: "Foggy")
        case .haze: return AppText.value(zh: "煙霞", en: "Hazy")
        case .windy, .breezy: return AppText.value(zh: "有風", en: "Windy")
        case .drizzle: return AppText.value(zh: "毛毛雨", en: "Drizzle")
        case .rain: return AppText.value(zh: "有雨", en: "Rain")
        case .heavyRain: return AppText.value(zh: "大雨", en: "Heavy Rain")
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms: return AppText.value(zh: "雷暴", en: "Thunderstorms")
        case .snow, .flurries, .heavySnow, .sleet: return AppText.value(zh: "有雪", en: "Snow")
        default: return AppText.value(zh: "多雲", en: "Cloudy")
        }
    }
    #endif
}
