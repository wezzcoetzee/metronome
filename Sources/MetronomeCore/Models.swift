import Foundation

public enum Tempo {
    public static let range = 30...300

    public static func clamp(_ bpm: Int) -> Int {
        min(max(bpm, range.lowerBound), range.upperBound)
    }

    public static func marking(for bpm: Int) -> String {
        switch bpm {
        case ..<60: "Largo"
        case ..<76: "Adagio"
        case ..<108: "Andante"
        case ..<120: "Moderato"
        case ..<168: "Allegro"
        case ..<200: "Presto"
        default: "Prestissimo"
        }
    }
}

public struct TimeSignature: Codable, Hashable, Sendable, CustomStringConvertible {
    public static let beatRange = 1...16
    public static let noteValues = [2, 4, 8, 16]
    public static let common = TimeSignature(beats: 4, noteValue: 4)
    public static let quickPicks = [TimeSignature(beats: 3, noteValue: 4), .common, TimeSignature(beats: 6, noteValue: 8)]

    public var beats: Int
    public var noteValue: Int

    public init(beats: Int, noteValue: Int) {
        self.beats = beats
        self.noteValue = noteValue
    }

    public var description: String { "\(beats)/\(noteValue)" }
}

public enum Sound: String, Codable, CaseIterable, Identifiable, Sendable {
    case click, woodblock, beep, cowbell, hihat

    public var id: Self { self }

    public var name: String {
        switch self {
        case .click: "Click"
        case .woodblock: "Woodblock"
        case .beep: "Beep"
        case .cowbell: "Cowbell"
        case .hihat: "Hi-hat"
        }
    }
}

public enum Subdivision: Int, Codable, CaseIterable, Identifiable, Sendable {
    case quarter = 1, eighth, triplet, sixteenth

    public var id: Self { self }

    public var symbol: String {
        switch self {
        case .quarter: "♩"
        case .eighth: "♪♪"
        case .triplet: "♪♪♪"
        case .sixteenth: "♬♬"
        }
    }
}

public enum MetronomeLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    case dial, numeric, grid, ruler

    public var id: Self { self }

    public var name: String {
        switch self {
        case .dial: "Dial"
        case .numeric: "Numeric"
        case .grid: "Grid"
        case .ruler: "Ruler"
        }
    }
}

public struct Preset: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var bpm: Int
    public var timeSignature: TimeSignature
    public var sound: Sound

    public init(name: String, bpm: Int, timeSignature: TimeSignature = .common, sound: Sound = .click) {
        self.name = name
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.sound = sound
    }
}

/// Everything the user can configure. Persisted as a single JSON blob.
public struct MetronomeSettings: Codable, Equatable, Sendable {
    public var bpm = 120
    public var timeSignature = TimeSignature.common
    /// One entry per beat in the bar; `true` plays the accent voice.
    public var accents = [true, false, false, false]
    public var sound = Sound.woodblock
    public var subdivision = Subdivision.quarter
    public var volume = 0.8
    public var layout = MetronomeLayout.numeric
    public var presets = [
        Preset(name: "Warmup", bpm: 80),
        Preset(name: "Groove", bpm: 120, sound: .woodblock),
        Preset(name: "Fast run", bpm: 168, timeSignature: TimeSignature(beats: 6, noteValue: 8), sound: .beep),
    ]

    public init() {}

    /// Missing keys fall back to defaults, so adding a setting later never wipes saved presets.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let defaults = MetronomeSettings()
        bpm = value(.bpm, defaults.bpm)
        timeSignature = value(.timeSignature, defaults.timeSignature)
        accents = value(.accents, defaults.accents)
        sound = value(.sound, defaults.sound)
        subdivision = value(.subdivision, defaults.subdivision)
        volume = value(.volume, defaults.volume)
        layout = value(.layout, defaults.layout)
        presets = value(.presets, defaults.presets)
    }

    /// Keeps derived invariants intact after any edit.
    public mutating func normalize() {
        bpm = Tempo.clamp(bpm)
        timeSignature.beats = min(max(timeSignature.beats, TimeSignature.beatRange.lowerBound), TimeSignature.beatRange.upperBound)
        volume = min(max(volume, 0), 1)
        let beats = timeSignature.beats
        if accents.count > beats {
            accents.removeLast(accents.count - beats)
        } else if accents.count < beats {
            accents += Array(repeating: false, count: beats - accents.count)
        }
        for index in presets.indices {
            presets[index].bpm = Tempo.clamp(presets[index].bpm)
        }
    }

    public func matches(_ preset: Preset) -> Bool {
        preset.bpm == bpm && preset.timeSignature == timeSignature && preset.sound == sound
    }
}
