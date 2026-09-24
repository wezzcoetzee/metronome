import Foundation

/// The three voices a sound needs: accented downbeat, regular beat, and subdivision tick.
public struct Voices: Sendable {
    public var accent: [Float]
    public var normal: [Float]
    public var subdivision: [Float]

    static let silent = Voices(accent: [], normal: [], subdivision: [])
}

/// Synthesises every sound in code so the app ships without audio assets.
public enum SoundSynth {
    private enum Wave { case sine, square }

    private struct Recipe {
        var partials: [(frequency: Double, level: Double)]
        var wave = Wave.sine
        var noise = 0.0
        var highpassNoise = false
        var duration: Double
        var decay: Double
    }

    public static func voices(for sound: Sound, sampleRate: Double) -> Voices {
        let recipe = recipe(for: sound)
        return Voices(
            accent: render(recipe, pitch: 1.5, gain: 1, sampleRate: sampleRate),
            normal: render(recipe, pitch: 1, gain: 0.7, sampleRate: sampleRate),
            subdivision: render(recipe, pitch: 0.8, gain: 0.35, sampleRate: sampleRate)
        )
    }

    private static func recipe(for sound: Sound) -> Recipe {
        switch sound {
        case .click:
            Recipe(partials: [(2000, 1)], noise: 0.5, duration: 0.03, decay: 0.004)
        case .woodblock:
            Recipe(partials: [(900, 1), (1830, 0.3)], duration: 0.08, decay: 0.014)
        case .beep:
            Recipe(partials: [(1000, 1)], duration: 0.07, decay: 1)
        case .cowbell:
            Recipe(partials: [(540, 0.6), (800, 0.6)], wave: .square, duration: 0.25, decay: 0.06)
        case .hihat:
            Recipe(partials: [], noise: 1, highpassNoise: true, duration: 0.07, decay: 0.014)
        }
    }

    private static func render(_ recipe: Recipe, pitch: Double, gain: Float, sampleRate: Double) -> [Float] {
        let count = Int(recipe.duration * sampleRate)
        let attack = 0.001 * sampleRate
        let release = 0.003 * sampleRate
        var previousNoise = 0.0
        var samples = [Float](repeating: 0, count: count)

        for index in 0..<count {
            let t = Double(index) / sampleRate
            var value = 0.0
            for partial in recipe.partials {
                let phase = sin(2 * .pi * partial.frequency * pitch * t)
                value += partial.level * (recipe.wave == .square ? (phase >= 0 ? 1 : -1) : phase)
            }
            if recipe.noise > 0 {
                let white = Double.random(in: -1...1)
                value += recipe.noise * (recipe.highpassNoise ? white - previousNoise : white)
                previousNoise = white
            }
            let envelope = exp(-t / recipe.decay)
                * min(1, Double(index) / attack)
                * min(1, Double(count - index) / release)
            samples[index] = Float(value * envelope)
        }

        let peak = samples.map(abs).max() ?? 0
        return peak > 0 ? samples.map { $0 / peak * gain } : samples
    }
}
