import MetronomeCore
import SwiftUI

/// A 270° ring you drag or scroll, like the tempo knob on a hardware metronome.
struct DialLayout: View {
    @Environment(MetronomeStore.self) private var store

    private static let sweep = 270.0
    private static let startAngle = 135.0
    private let diameter: CGFloat = 200

    private var fraction: Double {
        Double(store.settings.bpm - Tempo.range.lowerBound) / Double(Tempo.range.count - 1)
    }

    var body: some View {
        let settings = store.settings
        VStack(spacing: 12) {
            ZStack {
                ring(to: 1, color: .outline)
                ring(to: fraction, color: .white)
                knob
                VStack(spacing: 2) {
                    BPMText(bpm: settings.bpm, size: 46)
                    Text("BPM · \(settings.meter) · \(settings.sound.name)").font(.caption).foregroundStyle(Color.dim)
                }
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                // Only drags that start on the ring set tempo, so clicking the readout is harmless.
                guard isOnRing(drag.startLocation) else { return }
                setBPM(at: drag.location)
            })
            .overlay(ScrollSteps { store.nudge($0) })
            .tempoAccessibility(store)

            BeatDots()
            HStack(spacing: 8) {
                NudgeButton(delta: -1)
                PlayButton().frame(width: 130)
                NudgeButton(delta: 1)
            }
            TapButton()
            Divider()
            PresetList()
        }
    }

    private func ring(to fraction: Double, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: 0.75 * fraction)
            .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .rotationEffect(.degrees(Self.startAngle))
            .padding(5)
    }

    private var knob: some View {
        let radius = diameter / 2 - 5
        let angle = Angle.degrees(Self.startAngle + Self.sweep * fraction).radians
        return Circle()
            .fill(.black)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .frame(width: 16, height: 16)
            .offset(x: radius * cos(angle), y: radius * sin(angle))
    }

    /// True on the arc itself: not the readout in the middle, and not the gap at the bottom.
    private func isOnRing(_ point: CGPoint) -> Bool {
        hypot(point.x - diameter / 2, point.y - diameter / 2) > diameter / 2 - 28 && angle(of: point) <= Self.sweep
    }

    /// Degrees clockwise from the start of the arc, 0 to 360.
    private func angle(of point: CGPoint) -> Double {
        let degrees = atan2(point.y - diameter / 2, point.x - diameter / 2) * 180 / .pi
        let relative = (degrees - Self.startAngle).truncatingRemainder(dividingBy: 360)
        return relative < 0 ? relative + 360 : relative
    }

    private func setBPM(at point: CGPoint) {
        var relative = angle(of: point)
        // A drag that wanders into the bottom gap snaps to whichever end is closer.
        if relative > Self.sweep { relative = relative > (360 + Self.sweep) / 2 ? 0 : Self.sweep }
        let span = Double(Tempo.range.count - 1)
        store.setBPM(Tempo.range.lowerBound + Int((relative / Self.sweep * span).rounded()))
    }
}
