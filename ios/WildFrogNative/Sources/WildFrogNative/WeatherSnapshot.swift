import Foundation

/// A lightweight snapshot of the weather at a summit check-in, captured via
/// WeatherKit and shown on the collectible certificate. Codable so it persists
/// on CheckInRecord; optional everywhere (older records simply have none).
struct WeatherSnapshot: Codable, Equatable {
    /// SF Symbol name for the condition, e.g. "sun.max.fill", "cloud.rain.fill".
    let symbolName: String
    /// Localized condition label, e.g. "晴", "多雲", "有雨".
    let conditionText: String
    /// Air temperature in Celsius at check-in time.
    let temperatureC: Double

    var temperatureText: String { "\(Int(temperatureC.rounded()))°C" }
}
