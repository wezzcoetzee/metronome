import AppKit
import MetronomeCore
import SwiftUI

/// Dev tool: `METRONOME_SNAPSHOT=/some/dir .build/debug/Metronome` renders every layout
/// and the settings page to PNGs, then quits.
enum Snapshot {
    @MainActor static func renderIfRequested(_ store: MetronomeStore) {
        guard let directory = ProcessInfo.processInfo.environment["METRONOME_SNAPSHOT"] else { return }
        var views = MetronomeLayout.allCases.map { ($0.rawValue, AnyView(MetronomeView(forcedLayout: $0))) }
        views.append(("settings", AnyView(SettingsView())))

        for (name, view) in views {
            let host = NSHostingView(rootView: view.environment(store))
            host.frame.size = host.fittingSize
            let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        }
        exit(0)
    }
}
