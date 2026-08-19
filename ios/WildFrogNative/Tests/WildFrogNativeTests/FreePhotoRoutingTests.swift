import Foundation
import Testing
@testable import WildFrogNative

@Test func chooserBackdropSwipeAndCancelAllDismissWithoutMutation() {
    var state = CheckInTypeChooserState(previousTab: .records)
    state.present()
    state.dismissWithoutSelection()
    #expect(!state.isPresented)
    #expect(state.previousTab == .records)
    #expect(state.consumePendingChoice() == nil)

    state.present()
    state.select(.freePhoto)
    #expect(!state.isPresented)
    #expect(state.previousTab == .records)
    #expect(state.consumePendingChoice() == .freePhoto)
    #expect(state.consumePendingChoice() == nil)
}

@Test func checkInButtonPresentsRankedOrFreePhotoChooser() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceRoot = projectRoot.appendingPathComponent("Sources/WildFrogNative")
    let root = try String(contentsOf: sourceRoot.appendingPathComponent("WildFrogRootView.swift"), encoding: .utf8)
    let picker = try String(contentsOf: sourceRoot.appendingPathComponent("CheckInMapPickerView.swift"), encoding: .utf8)
    let chooser = try String(contentsOf: sourceRoot.appendingPathComponent("CheckInTypeChooserView.swift"), encoding: .utf8)
    let choiceHandler = try #require(
        root.components(separatedBy: "private func handleCheckInTypeChoice").dropFirst().first
            .flatMap { $0.components(separatedBy: "private func openActiveRecording").first }
    )

    #expect(root.contains("checkInTypeChooserState"))
    #expect(root.contains("showFreePhoto"))
    #expect(root.contains("CheckInTypeChooserView"))
    #expect(root.contains("handleCheckInTypeChoice"))
    #expect(root.contains("onDismiss:"))
    #expect(root.contains("fullScreenCover(isPresented: $showFreePhoto)"))
    #expect(root.contains("FreePhotoView()"))
    #expect(root.contains("case .ranked"))
    #expect(root.contains("case .freePhoto"))
    #expect(choiceHandler.contains("checkInTypeChooserState.select(choice)"))
    #expect(!choiceHandler.contains("checkInPath.append(NativeRoute.freePhoto)"))
    #expect(chooser.contains("enum CheckInTypeChoice"))
    #expect(chooser.contains("Ranked Check-In"))
    #expect(chooser.contains("Free Photo"))
    #expect(!picker.contains("NavigationLink(value: NativeRoute.freePhoto)"))
}
