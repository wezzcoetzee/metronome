import AppKit
import MetronomeCore
import SwiftUI

extension Color {
    static let dim = Color(white: 0.54)
    static let hairline = Color(white: 0.16)
    /// About 3:1 on black, the minimum contrast for control boundaries.
    static let outline = Color(white: 0.42)
}

struct OutlineButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        configuration.label
            .font(.system(size: 13, weight: prominent ? .semibold : .regular))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(prominent ? .black : .white)
            .background(shape.fill(prominent ? .white : .clear))
            .overlay(shape.stroke(prominent ? .white : .outline))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
    static var prominent: OutlineButtonStyle { OutlineButtonStyle(prominent: true) }
}

struct PlayButton: View {
    @Environment(MetronomeStore.self) private var store
    var hint = ""

    var body: some View {
        let title = store.isPlaying ? "Stop" : "Start"
        Button(title + hint) { store.toggle() }
            .buttonStyle(.prominent)
            .accessibilityLabel(title)
            .help("Space")
    }
}

struct TapButton: View {
    @Environment(MetronomeStore.self) private var store
    var hint = ""

    var body: some View {
        Button("Tap" + hint) { store.tap() }
            .buttonStyle(.outline)
            .accessibilityLabel("Tap tempo")
            .help("T")
    }
}

struct NudgeButton: View {
    @Environment(MetronomeStore.self) private var store
    let delta: Int
    var label: String?

    var body: some View {
        Button(label ?? (delta > 0 ? "+" : "−")) { store.nudge(delta) }
            .buttonStyle(.outline)
            .monospaced()
            .help(abs(delta) == 5 ? "Shift + arrow keys" : "Arrow keys")
            .accessibilityLabel(delta > 0 ? "Faster by \(delta)" : "Slower by \(-delta)")
    }
}

struct BPMText: View {
    let bpm: Int
    let size: CGFloat

    var body: some View {
        Text("\(bpm)")
            .font(.system(size: size, weight: .semibold, design: .monospaced))
            .contentTransition(.numericText())
    }
}

extension View {
    /// A ring just outside the shape marks the sounding beat, so it reads on filled (accented) beats too.
    func soundingRing<S: InsettableShape>(_ shape: S, _ sounding: Bool) -> some View {
        overlay { if sounding { shape.inset(by: -3).stroke(.white, lineWidth: 1.5) } }
    }

    /// Exposes a custom tempo control (dial, ruler) to VoiceOver as an adjustable value.
    func tempoAccessibility(_ store: MetronomeStore) -> some View {
        accessibilityElement()
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(store.settings.bpm) BPM")
            .accessibilityAdjustableAction { direction in
                store.nudge(direction == .increment ? 1 : -1)
            }
    }
}

/// One dot per beat, eight to a row: filled when accented, ringed while sounding.
/// Click a dot to toggle its accent.
struct BeatDots: View {
    @Environment(MetronomeStore.self) private var store
    var size: CGFloat = 12

    var body: some View {
        let columns = Array(repeating: GridItem(.fixed(size + 6), spacing: size * 0.5), count: min(store.settings.timeSignature.beats, 8))
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(store.settings.barAccents.enumerated()), id: \.offset) { beat, accented in
                Button { store.toggleAccent(beat) } label: {
                    Circle()
                        .fill(accented ? .white : .clear)
                        .overlay(Circle().stroke(Color.dim))
                        .soundingRing(Circle(), store.currentBeat == beat)
                        .frame(width: size, height: size)
                        .padding(3)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Beat \(beat + 1)")
                .accessibilityValue(accented ? "Accented" : "Normal")
                .help("Toggle accent")
            }
        }
        .fixedSize()
    }
}

/// The first nine presets, numbered to match the 1 to 9 shortcuts. The rest live in Settings.
struct PresetList: View {
    @Environment(MetronomeStore.self) private var store
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let presets = store.settings.presets
        VStack(spacing: 0) {
            ForEach(Array(presets.prefix(9).enumerated()), id: \.element.id) { index, preset in
                let active = store.settings.matches(preset)
                Button { store.apply(preset) } label: {
                    HStack {
                        Text("\(index + 1)").foregroundStyle(Color.dim).frame(width: 14, alignment: .leading)
                        Text(preset.displayName).lineLimit(1)
                        Spacer()
                        Text(preset.meter).foregroundStyle(Color.dim)
                        Text("\(preset.bpm)").foregroundStyle(active ? .white : .dim).frame(width: 30, alignment: .trailing)
                    }
                    .monospacedDigit()
                    .fontWeight(active ? .semibold : .regular)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset.displayName), \(preset.bpm) BPM, \(preset.meter)")
                .accessibilityAddTraits(active ? .isSelected : [])
            }
            if presets.count > 9 {
                Button("\(presets.count - 9) more in Settings") { openSettings() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }
}

/// Reports scroll-wheel and trackpad scrolling over its area as whole BPM steps without
/// blocking clicks or drags on the views beneath it.
struct ScrollSteps: NSViewRepresentable {
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> CaptureView {
        CaptureView()
    }

    func updateNSView(_ view: CaptureView, context: Context) {
        view.onStep = onStep
    }

    final class CaptureView: NSView {
        var onStep: ((Int) -> Void)?
        private var accumulated: CGFloat = 0

        /// Only claim scroll events so clicks and drags fall through to SwiftUI.
        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .scrollWheel ? super.hitTest(point) : nil
        }

        override func scrollWheel(with event: NSEvent) {
            let horizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            // Vertical follows the fingers or wheel (up is faster) whatever the natural scrolling setting.
            let vertical = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
            // Horizontal moves the ruler tape with the fingers, matching a drag.
            let sideways = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaX : event.scrollingDeltaX
            let delta = horizontal ? sideways : vertical
            accumulated += event.hasPreciseScrollingDeltas ? delta / 4 : delta
            let steps = Int(accumulated)
            if steps != 0 {
                accumulated -= CGFloat(steps)
                onStep?(steps)
            }
        }
    }
}
