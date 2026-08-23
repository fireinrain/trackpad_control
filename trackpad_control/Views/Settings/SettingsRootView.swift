import SwiftUI

struct SettingsRootView: View {
    @State private var selectedTab: SettingsTab? = .gestures

    var body: some View {
        Group {
            // TC_COMPAT(<13): NavigationSplitView requires macOS 13; custom
            // sidebar layout below covers macOS 12.
            if #available(macOS 13.0, *) {
                splitLayout
            } else {
                legacySidebarLayout
            }
        }
        .frame(minWidth: 780, minHeight: 520)
    }

    // TC_COMPAT(<13): availability gate only — same NavigationSplitView as before.
    @available(macOS 13.0, *)
    private var splitLayout: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            detailContent
        }
        .tcRemoveSidebarToggle() // TC_COMPAT(<14): toolbar(removing:) needs macOS 14
    }

    /// TC_COMPAT(<13): macOS 12 fallback — NavigationSplitView requires macOS 13.
    private var legacySidebarLayout: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        selectedTab == tab
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear
                    )
                    .cornerRadius(6)
                }
                Spacer()
            }
            .padding(10)
            .frame(width: 190)

            Divider()
                .ignoresSafeArea(edges: .vertical)

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .gestures, .none:
            GesturesView()
        case .recognition:
            RecognitionView()
        case .appearance:
            AppearanceView()
        case .advanced:
            AdvancedView()
        }
    }
}
