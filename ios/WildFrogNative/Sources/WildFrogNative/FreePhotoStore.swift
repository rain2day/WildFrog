import Foundation
import SwiftUI
import UIKit

struct FreePhotoStorePaths {
    let rootDirectory: URL

    var envelopeURL: URL {
        rootDirectory.appendingPathComponent("free-photo-map-v1.json")
    }

    var thumbnailsDirectory: URL {
        rootDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    static func live(fileManager: FileManager = .default) -> FreePhotoStorePaths {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FreePhotoStorePaths(
            rootDirectory: applicationSupport
                .appendingPathComponent("WildFrog", isDirectory: true)
                .appendingPathComponent("FreePhotoMap", isDirectory: true)
        )
    }
}

enum FreePhotoStoreError: Error {
    case unsupportedSchema
    case missingRecord
    case thumbnailWriteFailed
}

@MainActor
protocol FreePhotoRecordPersisting: AnyObject {
    func append(record: FreePhotoRecord, thumbnailData: Data) throws
}

@MainActor
protocol FreePhotoRecordDeleting: AnyObject {
    func removeRecord(id: UUID) throws
}

@MainActor
final class FreePhotoStore: ObservableObject, FreePhotoRecordPersisting, FreePhotoRecordDeleting {
    @Published private(set) var records: [FreePhotoRecord] = []
    @Published private(set) var lastCorruptEnvelopeURL: URL?

    let paths: FreePhotoStorePaths
    private let fileManager: FileManager

    private struct Envelope: Codable {
        let schemaVersion: Int
        let records: [FreePhotoRecord]
    }

    init(paths: FreePhotoStorePaths = .live(), fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        load()
    }

    func thumbnailURL(for record: FreePhotoRecord) -> URL {
        paths.thumbnailsDirectory.appendingPathComponent(record.thumbnailFilename)
    }

    func thumbnailURL(filename: String) -> URL {
        paths.thumbnailsDirectory.appendingPathComponent(filename)
    }

    func append(record: FreePhotoRecord, thumbnailData: Data) throws {
        try prepareDirectories()
        let thumbnailURL = thumbnailURL(for: record)
        do {
            try thumbnailData.write(to: thumbnailURL, options: .atomic)
        } catch {
            throw FreePhotoStoreError.thumbnailWriteFailed
        }

        var next = records.filter { $0.id != record.id }
        next.append(record)
        do {
            try persist(next)
            records = next.sorted { $0.createdAt > $1.createdAt }
        } catch {
            try? fileManager.removeItem(at: thumbnailURL)
            throw error
        }
    }

    func setManualLocation(recordID: UUID, coordinate: FreePhotoCoordinate) throws {
        guard coordinate.isValid,
              let index = records.firstIndex(where: { $0.id == recordID }) else {
            throw FreePhotoStoreError.missingRecord
        }
        var next = records
        next[index].coordinate = coordinate
        next[index].locationSource = .manual
        next[index].horizontalAccuracy = nil
        next[index].locationTimestamp = .now
        try persist(next)
        records = next.sorted { $0.createdAt > $1.createdAt }
    }

    func removeRecord(id: UUID) throws {
        guard let record = records.first(where: { $0.id == id }) else {
            throw FreePhotoStoreError.missingRecord
        }
        let next = records.filter { $0.id != id }
        try persist(next)
        records = next
        try? fileManager.removeItem(at: thumbnailURL(for: record))
    }

    #if DEBUG
    func seedQARecordsIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-qaFreePhotoMap"),
              records.isEmpty else { return }
        let now = Date()
        let seeds = [
            FreePhotoRecord(
                id: UUID(),
                createdAt: now,
                renderedAt: now,
                placeName: "白石角海旁",
                altitudeMetres: 8,
                altitudeSource: .gpsApproximate,
                cardStyle: .passport,
                coordinate: FreePhotoCoordinate(latitude: 22.424, longitude: 114.210),
                locationSource: .cameraGPS,
                horizontalAccuracy: 8,
                locationTimestamp: now,
                photosAssetIdentifier: nil,
                thumbnailFilename: "qa-1.jpg"
            ),
            FreePhotoRecord(
                id: UUID(),
                createdAt: now.addingTimeInterval(-60),
                renderedAt: now.addingTimeInterval(-60),
                placeName: "馬尿",
                altitudeMetres: 132,
                altitudeSource: .manual,
                cardStyle: .polaroid,
                coordinate: FreePhotoCoordinate(latitude: 22.395, longitude: 114.181),
                locationSource: .sourcePhotoMetadata,
                horizontalAccuracy: nil,
                locationTimestamp: nil,
                photosAssetIdentifier: nil,
                thumbnailFilename: "qa-2.jpg"
            ),
            FreePhotoRecord(
                id: UUID(),
                createdAt: now.addingTimeInterval(-120),
                renderedAt: now.addingTimeInterval(-120),
                placeName: "白石角小徑",
                altitudeMetres: 16,
                altitudeSource: .gpsApproximate,
                cardStyle: .passport,
                coordinate: FreePhotoCoordinate(latitude: 22.4243, longitude: 114.2102),
                locationSource: .cameraGPS,
                horizontalAccuracy: 12,
                locationTimestamp: now.addingTimeInterval(-120),
                photosAssetIdentifier: nil,
                thumbnailFilename: "qa-3.jpg"
            ),
            FreePhotoRecord(
                id: UUID(),
                createdAt: now.addingTimeInterval(-180),
                renderedAt: now.addingTimeInterval(-180),
                placeName: "等待補位置",
                altitudeMetres: nil,
                altitudeSource: .none,
                cardStyle: .passport,
                coordinate: nil,
                locationSource: .missing,
                horizontalAccuracy: nil,
                locationTimestamp: nil,
                photosAssetIdentifier: nil,
                thumbnailFilename: "qa-4.jpg"
            )
        ]
        try? prepareDirectories()
        let images = [
            UIImage(named: "MountainVioletHill"),
            UIImage(named: "MountainSunsetPeak"),
            UIImage(named: "MountainSaiWanShan"),
            UIImage(named: "MountainSaiWanShan")
        ]
        for (record, image) in zip(seeds, images) {
            if let data = image?.jpegData(compressionQuality: 0.78) {
                try? data.write(to: thumbnailURL(for: record), options: .atomic)
            }
        }
        records = seeds
    }
    #endif

    private func load() {
        do {
            try prepareDirectories()
            guard fileManager.fileExists(atPath: paths.envelopeURL.path) else {
                records = []
                return
            }
            let data = try Data(contentsOf: paths.envelopeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard envelope.schemaVersion == 1 else {
                throw FreePhotoStoreError.unsupportedSchema
            }
            records = envelope.records.sorted { $0.createdAt > $1.createdAt }
        } catch {
            preserveCorruptEnvelope()
            records = []
        }
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: paths.rootDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.thumbnailsDirectory, withIntermediateDirectories: true)
    }

    private func persist(_ records: [FreePhotoRecord]) throws {
        try prepareDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Envelope(schemaVersion: 1, records: records))
        let temporaryURL = paths.rootDirectory.appendingPathComponent(".free-photo-map-\(UUID().uuidString).tmp")
        try data.write(to: temporaryURL, options: .atomic)
        if fileManager.fileExists(atPath: paths.envelopeURL.path) {
            _ = try fileManager.replaceItemAt(paths.envelopeURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: paths.envelopeURL)
        }
    }

    private func preserveCorruptEnvelope() {
        guard fileManager.fileExists(atPath: paths.envelopeURL.path) else { return }
        let formatter = ISO8601DateFormatter()
        let safeTimestamp = formatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
        let target = paths.rootDirectory.appendingPathComponent("free-photo-map-v1.corrupt-\(safeTimestamp).json")
        do {
            try fileManager.moveItem(at: paths.envelopeURL, to: target)
            lastCorruptEnvelopeURL = target
        } catch {
            lastCorruptEnvelopeURL = paths.envelopeURL
        }
    }
}
