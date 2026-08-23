import SwiftUI

// MARK: - macOS 12–15 Compatibility Shims (TC_COMPAT)
//
// Every back-compat deviation from the macOS 26 baseline is tagged `TC_COMPAT(...)`
// so it stays greppable:
//   TC_COMPAT(<13)      — runtime availability branch below Ventura
//                         (menu bar entry, settings sidebar)
//   TC_COMPAT(<14)      — modern API replaced because it requires Sonoma
//                         (two-parameter onChange closure, no-argument activate(),
//                          toolbar(removing: .sidebarToggle), ContentUnavailableView)
//   TC_COMPAT(macOS 12) — SF Symbol renamed (newer name absent from the
//                         Monterey symbol dataset; replacement resolves on ALL versions)
//
// If the minimum supported version is ever raised past these thresholds,
// delete the tagged code and restore direct call sites.

extension View {
    /// TC_COMPAT(<14): drop-in replacement for the two-parameter `onChange(of:)`
    /// closure form (macOS 14+). Uses the classic `onChange(of:perform:)` API,
    /// which works on every supported version. Emits a deprecation warning on
    /// newer SDKs — expected and centralized here.
    func tcOnChange<V: Equatable>(of value: V, action: @escaping (V) -> Void) -> some View {
        onChange(of: value, perform: action)
    }

    /// TC_COMPAT(<14): `.toolbar(removing: .sidebarToggle)` requires macOS 14; no-op below.
    @ViewBuilder
    func tcRemoveSidebarToggle() -> some View {
        if #available(macOS 14.0, *) {
            toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }

    /// TC_COMPAT(<13): `contentTransition(.numericText())` requires macOS 13;
    /// plain no-op transition below.
    @ViewBuilder
    func tcNumericTextTransition() -> some View {
        if #available(macOS 13.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }
}

/// TC_COMPAT(<14): stand-in for `ContentUnavailableView` (macOS 14+).
/// Renders the native view on 14+ and a visually similar fallback on 12–13.
struct UnavailableStateView<L: View, D: View, A: View>: View {
    private let label: L
    private let description: D
    private let actions: A

    init(
        @ViewBuilder label: () -> L,
        @ViewBuilder description: () -> D,
        @ViewBuilder actions: () -> A
    ) {
        self.label = label()
        self.description = description()
        self.actions = actions()
    }

    var body: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView {
                label
            } description: {
                description
            } actions: {
                actions
            }
        } else {
            VStack(spacing: 8) {
                label
                    .font(.title3)
                description
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                actions
                    .padding(.top, 4)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
