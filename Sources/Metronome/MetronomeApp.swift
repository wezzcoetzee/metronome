import MetronomeCore
import SwiftUI

@main
struct MetronomeApp: App {
    @State private var store = MetronomeStore()

    init() {
        let store = store
        DispatchQueue.main.async { MainActor.assumeIsolated { Snapshot.renderIfRequested(store) } }
    }

    var body: some Scene {
        Window("Metronome", id: "main") {
            MetronomeView().environment(store)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView().environment(store)
        }
    }
}
