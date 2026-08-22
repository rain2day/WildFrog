import Foundation
import Testing
@testable import WildFrogNative

@Test func builtInActivitiesHaveStableDistinctIdentifiers() {
    let activities = TripActivityType.builtIns

    #expect(activities.count == 6)
    #expect(Set(activities.map(\.id)).count == activities.count)
    #expect(activities.allSatisfy { $0.isBuiltIn })
    #expect(activities.allSatisfy { !$0.isArchived })
}

@Test func gearKitSnapshotIsIndependentAndTotalsKnownWeight() {
    let camera = GearItem(
        name: "相機",
        category: "攝影",
        brand: "Fujifilm",
        unitWeightGrams: 355
    )
    let kit = GearKit(
        name: "昆蟲攝影",
        activityTypeIDs: [TripActivityType.insectPhotography.id],
        lines: [
            GearKitLine(gearItemID: camera.id, quantity: 2, priority: .required)
        ]
    )

    let entries = kit.snapshot(using: [camera])
    let weight = TripTotals.gearWeight(entries)

    #expect(entries.first?.name == "相機")
    #expect(entries.first?.brand == "Fujifilm")
    #expect(entries.first?.priority == .required)
    #expect(!entries[0].isPacked)
    #expect(weight.knownGrams == 710)
    #expect(weight.unknownLineCount == 0)
}

@Test func gearWeightReportsUnknownLinesInsteadOfTreatingThemAsZero() {
    let item = GearItem(name: "急救包", category: "安全")
    let kit = GearKit(
        name: "行山",
        lines: [GearKitLine(gearItemID: item.id, quantity: 1, priority: .required)]
    )

    let weight = TripTotals.gearWeight(kit.snapshot(using: [item]))

    #expect(weight.knownGrams == 0)
    #expect(weight.unknownLineCount == 1)
}

@Test func fuelTotalsNormalizeWaterAndCalories() {
    let water = TripConsumableEntry(
        kind: .water,
        name: "水",
        unit: .litres,
        plannedQuantity: 2,
        consumedQuantity: 1.25,
        consumedCalories: 0
    )
    let sportsDrink = TripConsumableEntry(
        kind: .otherDrink,
        name: "運動飲品",
        unit: .millilitres,
        plannedQuantity: 500,
        consumedQuantity: 300,
        consumedCalories: 72
    )
    let gel = TripConsumableEntry(
        kind: .food,
        name: "能量啫喱",
        unit: .items,
        plannedQuantity: 3,
        consumedQuantity: 2,
        consumedCalories: 180
    )

    #expect(TripTotals.waterMillilitres([water, sportsDrink, gel]) == 1_250)
    #expect(TripTotals.fluidMillilitres([water, sportsDrink, gel]) == 1_550)
    #expect(TripTotals.intakeCalories([water, sportsDrink, gel]) == 252)
}

@Test func tripOwnsSnapshotsAndSupportsNoCheckIns() {
    let activity = TripActivityType.insectPhotography
    let trip = StandaloneTrip(
        name: "城門昆蟲攝影",
        activity: TripActivitySnapshot(activity),
        scheduledAt: Date(timeIntervalSince1970: 1_777_777_777)
    )

    #expect(trip.status == .planned)
    #expect(trip.activity.nameZH == "昆蟲攝影")
    #expect(trip.officialCheckInIDs.isEmpty)
    #expect(trip.track == nil)
}
