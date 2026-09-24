import AppKit
import MetronomeCore
import SwiftUI

extension Color {
    static let dim = Color(white: 0.54)
    static let hairline = Color(white: 0.16)
    static let outline = Color(white: 0.27)
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
        Button((store.isPlaying ? "Stop" : "Start") + hint) { store.toggle() }
            .buttonStyle(.prominent)
    }
}

struct TapButton: View {
    @Environment(MetronomeStore.self) private var store
    var hint = ""

    var body: some View {
        Button("Tap" + hint) { store.tap() }
            .buttonStyle(.outline)
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

/// One dot per beat: filled when accented, outlined otherwise, brighter ring on the sounding beat.
struct BeatDots: View {
    @Environment(MetronomeStore.self) private var store
    var size: CGFloat = 10
    var editable = false

    var body: some View {
        HStack(spacing: size * 0.6) {
            ForEach(Array(store.settings.accents.enumerated()), id: \.offset) { beat, accented in
                Circle()
                    .fill(accented ? .white : .clear)
                    .overlay(Circle().stroke(store.currentBeat == beat ? .white : .dim, lineWidth: store.currentBeat == beat ? 2 : 1))
                    .frame(width: size, height: size)
                    .contentShape(Circle())
                    .onTapGesture { if editable { store.toggleAccent(beat) } }
            }
        }
    }
}

struct PresetList: View {
    @Environment(MetronomeStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ForEach(store.settings.presets) { preset in
                let active = store.settings.matches(preset)
                HStack {
                    Text(preset.name)
                    Spacer()
                    Text("\(preset.bpm)").monospaced().foregroundStyle(active ? .white : .dim)
                }
                .fontWeight(active ? .semibold : .regular)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture { store.apply(preset) }
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
            let delta = horizontal ? -event.scrollingDeltaX : event.scrollingDeltaY
            accumulated += event.hasPreciseScrollingDeltas ? delta / 4 : delta
            let steps = Int(accumulated)
            if steps != 0 {
                accumulated -= CGFloat(steps)
                onStep?(steps)
            }
        }
    }
}
