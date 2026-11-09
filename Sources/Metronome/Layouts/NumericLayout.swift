import MetronomeCore
import SwiftUI

/// Dense, keyboard-first layout. Shortcut hints mirror the handlers in `MetronomeView`.
struct NumericLayout: View {
    @Environment(MetronomeStore.self) private var store

    var body: some View {
        let settings = store.settings
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                BPMText(bpm: settings.bpm, size: 64)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(settings.meter)
                    Text(settings.sound.name)
                }
                .monospaced()
                .foregroundStyle(Color.dim)
            }

            Slider(
                value: Binding(get: { Double(settings.bpm) }, set: { store.setBPM(Int($0.rounded())) }),
                in: Double(Tempo.range.lowerBound)...Double(Tempo.range.upperBound)
            ) { Text("Tempo") }
            .labelsHidden()
            .tint(.white)

            BeatDots()

            HStack(spacing: 6) {
                ForEach([-5, -1, 1, 5], id: \.self) { delta in
                    NudgeButton(delta: delta, label: delta > 0 ? "+\(delta)" : "−\(-delta)")
                }
            }
            HStack(spacing: 6) {
                PlayButton(hint: "  ␣").frame(maxWidth: .infinity)
                TapButton(hint: "  T").frame(width: 90)
            }

            Divider()
            PresetList()
        }
    }
}
