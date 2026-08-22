import Testing
@testable import WildFrogNative

@Test func requiredItemsSortFirstAndWarningDoesNotBlock() {
    let entries = [
        TripGearEntry(name: "相機", category: "攝影", priority: .required),
        TripGearEntry(name: "後備電池", category: "攝影", priority: .optional, isPacked: true)
    ]
    let projection = PackingProjection(entries: entries)

    #expect(projection.sections.map(\.priority) == [.required, .optional])
    #expect(projection.packedCount == 1)
    #expect(projection.missingRequiredCount == 1)
    #expect(projection.shouldWarnBeforeStart)
}
