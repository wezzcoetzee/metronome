import MetronomeCore
import SwiftUI

/// A tempo scale you scrub horizontally. Presets show as marks on the scale.
struct RulerLayout: View {
    @Environment(MetronomeStore.self) private var store
    @State private var dragStartBPM: Int?

    private let pointsPerBPM: CGFloat = 6

    var body: some View {
        let settings = store.settings
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                BPMText(bpm: settings.bpm, size: 40)
                Spacer()
                Text("\(Tempo.marking(for: settings.bpm)) · \(settings.timeSignature.description)").foregroundStyle(Color.dim)
            }

            ruler
                .frame(height: 50)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        let start = dragStartBPM ?? settings.bpm
                        dragStartBPM = start
                        store.setBPM(start - Int((drag.translation.width / pointsPerBPM).rounded()))
                    }
                    .onEnded { _ in dragStartBPM = nil })
                .overlay(ScrollSteps { store.nudge($0) })

            BeatDots()
            HStack(spacing: 6) {
                PlayButton().frame(maxWidth: .infinity)
                TapButton().frame(width: 90)
            }
            Divider()
            PresetList()
        }
    }

    private var ruler: some View {
        let bpm = store.settings.bpm
        let presetBPMs = Set(store.settings.presets.map(\.bpm))
        return Canvas { context, size in
            let mid = size.width / 2
            let halfSpan = Int(mid / pointsPerBPM) + 1
            for value in (bpm - halfSpan)...(bpm + halfSpan) where Tempo.range.contains(value) {
                let x = mid + CGFloat(value - bpm) * pointsPerBPM
                let height: CGFloat = value % 10 == 0 ? 16 : value % 5 == 0 ? 10 : 5
                context.fill(Path(CGRect(x: x - 0.5, y: 34 - height, width: 1, height: height)), with: .color(.outline))
                if value % 10 == 0 {
                    context.draw(Text("\(value)").font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.dim), at: CGPoint(x: x, y: 44))
                }
                if presetBPMs.contains(value) {
                    context.fill(Path(CGRect(x: x - 3, y: 2, width: 6, height: 6)), with: .color(.white))
                }
            }
            context.fill(Path(CGRect(x: mid - 1, y: 8, width: 2, height: 30)), with: .color(.white))
        }
    }
}
