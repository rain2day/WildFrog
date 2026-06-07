import Foundation

/// Exports a `Track` to a GPX 1.1 file in the temporary directory.
enum GPXExporter {
    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    /// Builds the GPX 1.1 XML string for the given track.
    static func gpxString(for track: Track) -> String {
        let isoFormatter = makeISOFormatter()
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="WildFrog" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escape(track.name))</name>
            <time>\(isoFormatter.string(from: track.startDate))</time>
          </metadata>
          <trk>
            <name>\(escape(track.name))</name>
            <trkseg>

        """

        for point in track.points {
            let lat = String(format: "%.7f", point.latitude)
            let lon = String(format: "%.7f", point.longitude)
            xml += "      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">\n"
            if let elevation = point.elevation {
                xml += "        <ele>\(String(format: "%.1f", elevation))</ele>\n"
            }
            xml += "        <time>\(isoFormatter.string(from: point.timestamp))</time>\n"
            xml += "      </trkpt>\n"
        }

        xml += """
            </trkseg>
          </trk>
        </gpx>
        """
        return xml
    }

    /// Writes the GPX file to a temporary URL and returns it for sharing.
    static func exportToTemporaryFile(_ track: Track) throws -> URL {
        let safeName = track.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
        let fileName = (safeName.isEmpty ? "wildfrog-track" : safeName) + ".gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try gpxString(for: track).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
