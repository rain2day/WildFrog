import Foundation
import Testing

@Test func freePhotoScreenDoesNotReferenceOfficialMutationTypes() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = projectRoot.appendingPathComponent("Sources/WildFrogNative/FreePhotoView.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)

    for forbidden in [
        "CheckInStore",
        "FirestoreService",
        "TrackRecorder",
        "addCheckIn",
        "recordCheckIn",
        "MountainStampSeal"
    ] {
        #expect(!source.contains(forbidden))
    }
    #expect(source.contains(
        ".allowsHitTesting(FreePhotoPreviewInteractionContract.cardAllowsHitTesting)"
    ))
}

@Test func permissionDescriptionsCoverOfficialAndFreePhotoPurposes() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(contentsOf: projectRoot.appendingPathComponent("Sources/WildFrogNative/Info.plist"))
    let plist = try #require(
        PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )

    for key in [
        "NSCameraUsageDescription",
        "NSLocationWhenInUseUsageDescription",
        "NSPhotoLibraryAddUsageDescription",
        "NSPhotoLibraryUsageDescription"
    ] {
        let description = try #require(plist[key] as? String)
        #expect(description.contains("Free Photo"))
    }
    #expect((plist["NSPhotoLibraryUsageDescription"] as? String)?.contains("avatar") == true)
    #expect((plist["NSPhotoLibraryAddUsageDescription"] as? String)?.contains("save") == true)
}
