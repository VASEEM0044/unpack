import SwiftUI

/// Root responsive navigation container supporting iPad sidebar (NavigationSplitView) and iPhone floating TabView.
public struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: TabItem? = .home

    public enum TabItem: String, Hashable, CaseIterable {
        case home = "Home"
        case settings = "Settings"

        public var icon: String {
            switch self {
            case .home: return "archivebox.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    public init() {}

    public var body: some View {
        if horizontalSizeClass == .regular {
            // iPad / Mac Catalyst Split View Sidebar
            NavigationSplitView {
                List(TabItem.allCases, id: \.self, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
                .navigationTitle("Unpack")
            } detail: {
                detailView(for: selectedTab ?? .home)
            }
        } else {
            // iPhone TabView with Frosted Surface
            TabView(selection: Binding(
                get: { selectedTab ?? .home },
                set: { selectedTab = $0 }
            )) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "archivebox.fill")
                    }
                    .tag(TabItem.home)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(TabItem.settings)
            }
            .tint(.accentColor)
        }
    }

    @ViewBuilder
    private func detailView(for tab: TabItem) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .settings:
            SettingsView()
        }
    }
}
