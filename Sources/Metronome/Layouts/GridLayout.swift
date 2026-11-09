import MetronomeCore
import SwiftUI

/// The bar is the hero: one cell per beat, click a cell to toggle its accent.
struct GridLayout: View {
    @Environment(MetronomeStore.self) private var store

    var body: some View {
        let settings = store.settings
        let accents = settings.barAccents
        let columns = min(accents.count, 8)
        // A signature set in Settings that isn't a quick pick still shows, selected, at the end.
        let signatures = TimeSignature.quickPicks.contains(settings.timeSignature)
            ? TimeSignature.quickPicks
            : TimeSignature.quickPicks + [settings.timeSignature]
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(Array(accents.enumerated()), id: \.offset) { beat, accented in
                    let shape = RoundedRectangle(cornerRadius: 6)
                    Button { store.toggleAccent(beat) } label: {
                        shape
                            .fill(accented ? .white : .clear)
                            .overlay(shape.stroke(Color.outline))
                            .soundingRing(shape, store.currentBeat == beat)
                            .frame(height: accents.count > 4 ? 40 : 56)
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Beat \(beat + 1)")
                    .accessibilityValue(accented ? "Accented" : "Normal")
                    .help("Toggle accent")
                }
            }
            .padding(3)

            HStack {
                NudgeButton(delta: -1).frame(width: 44)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    BPMText(bpm: settings.bpm, size: 34)
                    Text("BPM").foregroundStyle(Color.dim)
                }
                Spacer()
                NudgeButton(delta: 1).frame(width: 44)
            }

            HStack {
                HStack(spacing: 0) {
                    ForEach(signatures, id: \.self) { signature in
                        let selected = signature == settings.timeSignature
                        Button { store.setTimeSignature(signature) } label: {
                            Text(signature.description)
                                .monospaced()
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .foregroundStyle(selected ? .black : .white)
                                .background(selected ? Color.white : .clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.outline))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
                Text(settings.subdivision == .quarter ? settings.sound.name : "\(settings.subdivision.symbol) · \(settings.sound.name)")
                    .foregroundStyle(Color.dim)
            }

            HStack(spacing: 6) {
                PlayButton().frame(maxWidth: .infinity)
                TapButton().frame(width: 90)
            }

            Divider()
            PresetList()
        }
    }
}
