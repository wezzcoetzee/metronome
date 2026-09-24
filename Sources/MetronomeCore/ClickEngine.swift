import AVFoundation
import os

/// Counts frames on the audio thread and reports which tick starts on each frame.
/// Ticks include subdivisions, so a 4/4 bar in eighths has 8 ticks.
struct Sequencer {
    private(set) var tick = 0
    private var framesUntilTick = 0.0

    mutating func reset() {
        tick = 0
        framesUntilTick = 0
    }

    /// Advances one frame. Fractional frame counts carry over so tempo never drifts.
    mutating func advance(framesPerTick: Double, ticksPerBar: Int) -> Int? {
        var started: Int?
        if framesUntilTick <= 0 {
            started = tick % ticksPerBar
            tick = (started! + 1) % ticksPerBar
            framesUntilTick += framesPerTick
        }
        framesUntilTick -= 1
        return started
    }
}

/// Sample-accurate metronome output. Timing is derived from the render callback's frame count,
/// not from timers, so the click stays locked to the audio clock.
public final class ClickEngine: @unchecked Sendable {
    public struct Config: Equatable, Sendable {
        public var bpm: Int
        public var accents: [Bool]
        public var subdivision: Subdivision
        public var volume: Double
        public var sound: Sound

        public init(_ settings: MetronomeSettings) {
            bpm = settings.bpm
            accents = settings.accents
            subdivision = settings.subdivision
            volume = settings.volume
            sound = settings.sound
        }
    }

    /// State shared between the main thread and the render callback.
    private struct Shared {
        var config: Config
        var sampleRate: Double
        var voices = Voices.silent
        var isRunning = false
        var resetRequested = false
        var previewRequested = false
    }

    /// Called on the main thread when a beat reaches the speakers.
    public var onBeat: (@MainActor (Int) -> Void)?
    /// Called on the main thread if playback stops on its own, e.g. the output device vanished.
    public var onStopped: (@MainActor () -> Void)?

    private let shared: OSAllocatedUnfairLock<Shared>
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    /// Lets the render callback hand beats to the main thread without allocating.
    /// Payload: beat index + 1 in the low byte (zero never fires), frame offset within the buffer above it.
    private let beatSignal = DispatchSource.makeUserDataReplaceSource(queue: .main)
    private var configurationObserver: NSObjectProtocol?

    // Touched only by the render callback.
    private var sequencer = Sequencer()
    private var voice: [Float] = []
    private var playhead = 0

    public init(config: Config) {
        shared = OSAllocatedUnfairLock(initialState: Shared(config: config, sampleRate: 48_000))
        connectSource()

        beatSignal.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.deliverBeat() }
        }
        beatSignal.activate()

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleConfigurationChange() }
        }
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        beatSignal.cancel()
    }

    public func configure(_ config: Config) {
        let (soundChanged, sampleRate) = shared.withLock { ($0.config.sound != config.sound, $0.sampleRate) }
        let voices = soundChanged ? SoundSynth.voices(for: config.sound, sampleRate: sampleRate) : nil
        shared.withLock { state in
            state.config = config
            if let voices { state.voices = voices }
        }
    }

    public func start() throws {
        shared.withLock {
            $0.isRunning = true
            $0.resetRequested = true
        }
        if !engine.isRunning { try engine.start() }
    }

    public func stop() {
        shared.withLock { $0.isRunning = false }
        engine.stop()
    }

    /// Plays a single regular beat, starting the audio engine briefly if it is idle.
    public func preview() {
        shared.withLock { $0.previewRequested = true }
        guard !engine.isRunning else { return }
        try? engine.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.shared.withLock({ $0.isRunning }) else { return }
            self.engine.stop()
        }
    }

    /// (Re)builds the source node at the output device's current sample rate.
    private func connectSource() {
        if let source {
            engine.disconnectNodeOutput(source)
            engine.detach(source)
        }
        let outputRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = outputRate > 0 ? outputRate : 48_000
        let sound = shared.withLock { $0.config.sound }
        let voices = SoundSynth.voices(for: sound, sampleRate: sampleRate)
        shared.withLock {
            $0.sampleRate = sampleRate
            $0.voices = voices
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let node = AVAudioSourceNode(format: format) { [unowned self] _, _, frameCount, buffers in
            self.render(frameCount: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(buffers))
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
    }

    /// The engine stops itself when the output device or its format changes (headphones, AirPods).
    @MainActor private func handleConfigurationChange() {
        connectSource()
        guard shared.withLock({ $0.isRunning }) else { return }
        do {
            try engine.start()
        } catch {
            shared.withLock { $0.isRunning = false }
            onStopped?()
        }
    }

    @MainActor private func deliverBeat() {
        let payload = beatSignal.data
        let beat = Int(payload & 0xFF) - 1
        let frame = Double(payload >> 8)
        let sampleRate = shared.withLock { $0.sampleRate }
        // The render callback runs ahead of the speakers; wait so the UI matches what you hear.
        let delay = engine.outputNode.presentationLatency + frame / sampleRate
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.shared.withLock({ $0.isRunning }) else { return }
                self.onBeat?(beat)
            }
        }
    }

    private func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        let state = shared.withLock { state -> Shared in
            let snapshot = state
            state.resetRequested = false
            state.previewRequested = false
            return snapshot
        }
        let config = state.config
        let ticksPerBeat = config.subdivision.rawValue
        let ticksPerBar = ticksPerBeat * max(config.accents.count, 1)
        let framesPerTick = state.sampleRate * 60 / Double(config.bpm) / Double(ticksPerBeat)
        let volume = Float(config.volume)

        if state.resetRequested { sequencer.reset() }
        if state.previewRequested {
            voice = state.voices.normal
            playhead = 0
        }

        for frame in 0..<frameCount {
            if state.isRunning, let tick = sequencer.advance(framesPerTick: framesPerTick, ticksPerBar: ticksPerBar) {
                playhead = 0
                if tick % ticksPerBeat == 0 {
                    let beat = tick / ticksPerBeat
                    voice = config.accents[beat] ? state.voices.accent : state.voices.normal
                    beatSignal.replace(data: UInt(beat + 1) | UInt(frame) << 8)
                } else {
                    voice = state.voices.subdivision
                }
            }

            let sample = playhead < voice.count ? voice[playhead] * volume : 0
            playhead += 1
            for buffer in buffers {
                buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
            }
        }
    }
}
