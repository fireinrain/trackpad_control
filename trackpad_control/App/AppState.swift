import Foundation
import SwiftUI
import Combine

// TC_COMPAT(<14): @Observable macro requires macOS 14; ObservableObject/@Published
// (Combine) works on every supported version and drives the same view updates.
final class AppState: ObservableObject {
    static let shared = AppState()

    private var storeCancellable: AnyCancellable?

    private init() {
        // Re-publish gesture store changes so views observing AppState alone
        // still refresh when the underlying store mutates.
        storeCancellable = gestureStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    @Published var selectedTab: SettingsTab = .gestures
    @Published var recognitionSettings = RecognitionSettings()
    @Published var appearanceSettings = AppearanceSettings()
    let gestureStore = GestureStore.shared

    // Editor state
    @Published var editingGesture: GestureDefinition?
    @Published var isShowingEditor: Bool = false
    @Published var isCreatingNew: Bool = false

    // Recognition telemetrics (updated on each gesture completion)
    @Published var lastGestureFingerCount: Int = 0
    @Published var lastGesturePointCount: Int = 0
    @Published var lastMatchName: String = ""
    @Published var lastMatchScore: Double = 0
    @Published var lastMatchTurnCount: Int = 0
    @Published var lastGestureTimestamp: Date?
    @Published var lastAllScores: [(name: String, score: Double)] = []
    @Published var lastGestureStartX: Double = 0
    @Published var lastGestureStartY: Double = 0
    @Published var lastGestureEndX: Double = 0
    @Published var lastGestureEndY: Double = 0
    @Published var lastGesturePathLength: Double = 0

    // Live telemetrics (updated each frame during gesture)
    @Published var liveX: Double = 0
    @Published var liveY: Double = 0
    @Published var isGestureActive: Bool = false

    // Recording state (set by TrackpadRecorderView, read by TCM)
    @Published var isRecordingArmed: Bool = false
    @Published var recordingLivePaths: [[PathPoint]] = []
    @Published var recordingLiveFingerCount: Int = 0
    @Published var recordingUpdateCounter: Int = 0  // incremented on each live update
    @Published var recordingCompletionCounter: Int = 0  // incremented when recording completes
    @Published var recordedPaths: [[PathPoint]]?  // nil until gesture completes
    @Published var recordedFingerCount: Int = 0



    @Published var gestures: [GestureDefinition] {
        get { gestureStore.gestures }
    }

    func createNewGesture(inputType: InputType = .discrete) {
        let defaultFingers: Int
        switch inputType {
        case .discrete: defaultFingers = 1
        case .continuous: defaultFingers = 3
        case .pinch, .dial: defaultFingers = 2
        case .zoneTap: defaultFingers = 1
        }
        editingGesture = GestureDefinition(
            name: "",
            fingerCount: defaultFingers,
            inputType: inputType,
            triggerAction: .keyboardShortcut(KeyboardShortcutTrigger(key: ""))
        )
        isCreatingNew = true
        isShowingEditor = true
    }

    func editGesture(_ gesture: GestureDefinition) {
        editingGesture = gesture
        isCreatingNew = false
        isShowingEditor = true
    }

    func saveGesture(_ gesture: GestureDefinition) {
        gestureStore.saveOrAdd(gesture)
        isShowingEditor = false
        editingGesture = nil
    }

    func deleteGesture(_ gesture: GestureDefinition) {
        gestureStore.delete(gesture)
    }

    func toggleGesture(_ gesture: GestureDefinition) {
        gestureStore.toggleEnabled(gesture)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case gestures = "Inputs"
    case recognition = "Recognition"
    case appearance = "Appearance"
    case advanced = "Advanced"

    @Published var id: String { rawValue }

    @Published var icon: String {
        switch self {
        case .gestures: "rectangle.3.group"
        case .recognition: "brain.head.profile"
        case .appearance: "paintbrush"
        case .advanced: "gearshape.2"
        }
    }
}
