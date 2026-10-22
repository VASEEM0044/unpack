import SwiftUI

/// Main application entry point for Unpack.
@main
struct UnpackApp: App {
    @State private var appState = AppState.shared
    @AppStorage("appearanceMode") private var appearanceMode: String = "System"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedColorScheme)
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
                .sheet(item: Binding<IdentifiableURL?>(
                    get: { appState.deepLinkedArchiveURL.map { IdentifiableURL(url: $0) } },
                    set: { appState.deepLinkedArchiveURL = $0?.url }
                )) { item in
                    NavigationStack {
                        ArchiveBrowserView(archiveURL: item.url)
                    }
                }
                .task {
                    await NotificationService.shared.requestAuthorization()
                }
        }
    }

    private var selectedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
