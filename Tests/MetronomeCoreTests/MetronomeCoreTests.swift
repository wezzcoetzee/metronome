import Foundation
import Testing
@testable import MetronomeCore

@Suite struct TapTempoTests {
    @Test func averagesRecentIntervals() {
        var tempo = TapTempo()
        #expect(tempo.tap(at: 0) == nil)
        #expect(tempo.tap(at: 0.5) == 120)
        #expect(tempo.tap(at: 1.0) == 120)
    }

    @Test func longPauseRestartsMeasurement() {
        var tempo = TapTempo()
        _ = tempo.tap(at: 0)
        _ = tempo.tap(at: 1)
        #expect(tempo.tap(at: 10) == nil)
        #expect(tempo.tap(at: 10.25) == 240)
    }

    @Test func clampsToTempoRange() {
        var tempo = TapTempo()
        _ = tempo.tap(at: 0)
        #expect(tempo.tap(at: 0.01) == Tempo.range.upperBound)
    }
}

@Suite struct SequencerTests {
    @Test func ticksLandOnExpectedFrames() {
        var sequencer = Sequencer()
        let starts = (0..<2000).compactMap { frame in
            sequencer.advance(framesPerTick: 500, ticksPerBar: 4).map { (frame, $0) }
        }
        #expect(starts.map(\.0) == [0, 500, 1000, 1500])
        #expect(starts.map(\.1) == [0, 1, 2, 3])
    }

    @Test func fractionalTicksDoNotDrift() {
        var sequencer = Sequencer()
        let count = (0..<10_000).filter { _ in sequencer.advance(framesPerTick: 333.25, ticksPerBar: 4) != nil }.count
        #expect(count == 31)
    }

    @Test func shrinkingBarWrapsTick() {
        var sequencer = Sequencer()
        for _ in 0..<3 { _ = sequencer.advance(framesPerTick: 1, ticksPerBar: 8) }
        #expect(sequencer.advance(framesPerTick: 1, ticksPerBar: 2) == 1)
    }
}

@Suite struct SettingsTests {
    @Test func normalizeResizesAccentsAndClamps() {
        var settings = MetronomeSettings()
        settings.bpm = 1000
        settings.timeSignature.beats = 6
        settings.normalize()
        #expect(settings.bpm == 300)
        #expect(settings.accents == [true, false, false, false, false, false])

        settings.timeSignature.beats = 2
        settings.normalize()
        #expect(settings.accents == [true, false])
    }

    @Test func decodingOlderDataKeepsPresetsAndDefaultsTheRest() throws {
        let json = #"{"bpm": 90, "presets": [{"id": "9E1D5B6C-3C1A-4E8E-9F6B-1B2C3D4E5F60", "name": "Slow", "bpm": 60, "timeSignature": {"beats": 3, "noteValue": 4}, "sound": "beep"}]}"#
        let settings = try JSONDecoder().decode(MetronomeSettings.self, from: Data(json.utf8))
        #expect(settings.bpm == 90)
        #expect(settings.presets.map(\.name) == ["Slow"])
        #expect(settings.layout == MetronomeSettings().layout)
    }
}
