import Foundation

/// Persists recorded tracks to `Documents/tracks.json`.
@MainActor
final class TrackStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = documents.appendingPathComponent("tracks.json")
        }
        load()
    }

    // MARK: - Mutations

    func add(_ track: Track) {
        tracks.insert(track, at: 0)
        save()
    }

    func delete(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
        save()
    }

    func rename(_ track: Track, to name: String) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tracks[index].name = trimmed
        save()
    }

    func setMountain(_ mountainId: String?, for track: Track) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        tracks[index].mountainId = mountainId
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Track].self, from: data) else {
            tracks = []
            return
        }
        tracks = decoded.sorted { $0.startDate > $1.startDate }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
