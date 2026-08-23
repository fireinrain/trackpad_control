import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject private var appState = AppState.shared
    // TC_COMPAT(<14): ObservableObject migration — dedicated observer for the
    // nested settings object so the Toggle binding tracks changes.
    @ObservedObject private var rs = AppState.shared.recognitionSettings

    var body: some View {
        Toggle("Tracking", isOn: $rs.isTracking)
            .keyboardShortcut("t")

        Divider()

        Button("Settings…") {
            SettingsWindowController.shared.show()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Trackpad Control") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
