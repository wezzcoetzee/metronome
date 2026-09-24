import MetronomeCore
import SwiftUI

/// The bar is the hero: one cell per beat, click a cell to toggle its accent.
struct GridLayout: View {
    @Environment(MetronomeStore.self) private var store

    var body: some View {
        let settings = store.settings
        let columns = min(settings.accents.count, 8)
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
                ForEach(Array(settings.accents.enumerated()), id: \.offset) { beat, accented in
                    let shape = RoundedRectangle(cornerRadius: 6)
                    let sounding = store.currentBeat == beat
                    shape
                        .fill(accented ? .white : .clear)
                        .overlay(shape.stroke(sounding ? .white : .outline, lineWidth: sounding ? 2 : 1))
                        .frame(height: settings.accents.count > 4 ? 40 : 56)
                        .contentShape(shape)
                        .onTapGesture { store.toggleAccent(beat) }
                }
            }

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

            HStack(spacing: 0) {
                ForEach(TimeSignature.quickPicks, id: \.self) { signature in
                    let selected = signature == settings.timeSignature
                    Text(signature.description)
                        .monospaced()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .foregroundStyle(selected ? .black : .white)
                        .background(selected ? Color.white : .clear)
                        .contentShape(Rectangle())
                        .onTapGesture { store.setTimeSignature(signature) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.outline))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                PlayButton().frame(maxWidth: .infinity)
                TapButton().frame(width: 90)
            }

            Divider()
            HStack(spacing: 14) {
                ForEach(settings.presets) { preset in
                    Text("\(preset.bpm)")
                        .fontWeight(settings.matches(preset) ? .semibold : .regular)
                        .foregroundStyle(settings.matches(preset) ? .white : .dim)
                        .onTapGesture { store.apply(preset) }
                        .help(preset.name)
                }
                Spacer()
            }
            .monospaced()
        }
    }
}
