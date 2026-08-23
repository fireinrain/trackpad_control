import AppKit
import Combine

/// TC_COMPAT(<13): macOS 12 fallback entry replacing `MenuBarExtra` (macOS 13+).
/// Mirrors the `.menuBarExtraStyle(.menu)` presentation with a native
/// NSStatusItem + NSMenu so behavior and visuals stay consistent across
/// all supported systems.
///
/// On macOS 13+ this file is inert — nothing here is ever installed.
@MainActor
final class LegacyMenuBarController: NSObject {
    static let shared = LegacyMenuBarController()

    private var cancellable: AnyCancellable?
    private var statusItem: NSStatusItem?
    private weak var trackingItem: NSMenuItem?

    private override init() {
        super.init()
    }

    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: iconName(), accessibilityDescription: "Trackpad Control")
        }
        item.menu = makeMenu()
        statusItem = item

        observeTrackingState()
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Tracking", action: #selector(toggleTracking(_:)), keyEquivalent: "t")
        toggle.target = self
        trackingItem = toggle

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self

        let quit = NSMenuItem(title: "Quit Trackpad Control", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self

        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quit)

        refreshState()
        return menu
    }

    private func iconName() -> String {
        AppState.shared.recognitionSettings.isTracking
            ? "hand.point.up.braille.fill"
            : "hand.point.up.braille"
    }

    private func refreshState() {
        trackingItem?.state = AppState.shared.recognitionSettings.isTracking ? .on : .off
        statusItem?.button?.image = NSImage(systemSymbolName: iconName(), accessibilityDescription: "Trackpad Control")
    }

    /// TC_COMPAT(<14): ObservableObject migration — Combine subscription
    /// replaces the Observation-framework tracking loop (which requires macOS 14).
    private func observeTrackingState() {
        cancellable = AppState.shared.recognitionSettings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshState() }
    }

    // MARK: - Actions

    @objc private func toggleTracking(_ sender: NSMenuItem) {
        AppState.shared.recognitionSettings.isTracking.toggle()
        refreshState()
    }

    @objc private func showSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
}
