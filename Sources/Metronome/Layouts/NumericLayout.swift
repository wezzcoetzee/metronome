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
                    Text(settings.timeSignature.description)
                    Text(settings.sound.name)
                }
                .monospaced()
                .foregroundStyle(Color.dim)
            }

            Slider(
                value: Binding(get: { Double(settings.bpm) }, set: { store.setBPM(Int($0.rounded())) }),
                in: Double(Tempo.range.lowerBound)...Double(Tempo.range.upperBound)
            )
            .tint(.white)

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
            VStack(spacing: 0) {
                ForEach(Array(settings.presets.prefix(9).enumerated()), id: \.element.id) { index, preset in
                    let active = settings.matches(preset)
                    HStack {
                        Text("\(index + 1)").foregroundStyle(Color.dim).frame(width: 16, alignment: .leading)
                        Text(preset.name)
                        Spacer()
                        Text("\(preset.bpm)")
                    }
                    .fontWeight(active ? .semibold : .regular)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { store.apply(preset) }
                }
            }
            .monospaced()
        }
    }
}
