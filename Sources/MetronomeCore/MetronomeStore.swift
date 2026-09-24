import Foundation
import Observation

@MainActor
@Observable
public final class MetronomeStore {
    private static let storageKey = "settings"

    public private(set) var settings: MetronomeSettings
    public private(set) var isPlaying = false
    /// Beat index within the bar that last sounded, or `nil` when stopped.
    public private(set) var currentBeat: Int?

    @ObservationIgnored private let engine: ClickEngine
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var tapTempo = TapTempo()

    public init(defaults: UserDefaults = .standard) {
        let stored = defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(MetronomeSettings.self, from: $0) }
        var settings = stored ?? MetronomeSettings()
        settings.normalize()

        self.defaults = defaults
        self.settings = settings
        engine = ClickEngine(config: .init(settings))
        engine.onBeat = { [weak self] beat in
            guard let self, self.isPlaying else { return }
            self.currentBeat = beat
        }
        engine.onStopped = { [weak self] in
            self?.isPlaying = false
            self?.currentBeat = nil
        }
    }

    /// The single entry point for edits: normalises, persists, and pushes the result to the engine.
    public func update(_ change: (inout MetronomeSettings) -> Void) {
        var next = settings
        change(&next)
        next.normalize()
        guard next != settings else { return }
        settings = next
        defaults.set(try? JSONEncoder().encode(next), forKey: Self.storageKey)
        engine.configure(.init(next))
    }

    public func toggle() {
        if isPlaying {
            engine.stop()
            isPlaying = false
            currentBeat = nil
        } else {
            isPlaying = (try? engine.start()) != nil
        }
    }

    public func setBPM(_ bpm: Int) {
        update { $0.bpm = bpm }
    }

    public func nudge(_ delta: Int) {
        setBPM(settings.bpm + delta)
    }

    public func tap() {
        if let bpm = tapTempo.tap(at: ProcessInfo.processInfo.systemUptime) {
            setBPM(bpm)
        }
    }

    public func setTimeSignature(_ signature: TimeSignature) {
        update { $0.timeSignature = signature }
    }

    public func toggleAccent(_ beat: Int) {
        update { $0.accents[beat].toggle() }
    }

    public func apply(_ preset: Preset) {
        update {
            $0.bpm = preset.bpm
            $0.timeSignature = preset.timeSignature
            $0.sound = preset.sound
        }
    }

    public func saveCurrentAsPreset() {
        update {
            $0.presets.append(Preset(name: "\($0.bpm) BPM", bpm: $0.bpm, timeSignature: $0.timeSignature, sound: $0.sound))
        }
    }

    public func updatePreset(_ id: Preset.ID, _ change: (inout Preset) -> Void) {
        update { settings in
            guard let index = settings.presets.firstIndex(where: { $0.id == id }) else { return }
            change(&settings.presets[index])
        }
    }

    public func preview() {
        engine.preview()
    }
}
