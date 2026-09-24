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
        MenuBarExtra {
            PopoverView().environment(store)
        } label: {
            Text(menuBarTitle).monospacedDigit()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environment(store)
        }
    }

    private var menuBarTitle: String {
        let bpm = store.settings.bpm
        switch store.settings.menuBarStyle {
        case .note:
            return "♩ \(bpm)"
        case .number:
            return "\(bpm)"
        case .playState:
            return "\(store.isPlaying ? "▶" : "■") \(bpm)"
        case .beats:
            let dots = store.settings.accents.indices.map { $0 == store.currentBeat ? "●" : "○" }
            return "\(dots.joined(separator: " ")) \(bpm)"
        }
    }
}
