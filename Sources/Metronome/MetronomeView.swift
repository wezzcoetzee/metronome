import MetronomeCore
import SwiftUI

struct MetronomeView: View {
    @Environment(MetronomeStore.self) private var store
    @Environment(\.openSettings) private var openSettings
    @FocusState private var focused: Bool
    /// Overrides the saved layout; used by `Snapshot`.
    var forcedLayout: MetronomeLayout?

    var body: some View {
        VStack(spacing: 12) {
            switch forcedLayout ?? store.settings.layout {
            case .dial: DialLayout()
            case .numeric: NumericLayout()
            case .grid: GridLayout()
            case .ruler: RulerLayout()
            }

            Divider()
            HStack {
                Button("Save preset") { store.saveCurrentAsPreset() }
                Spacer()
                Button("Settings") { openSettings() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.dim)
        }
        .padding(14)
        .frame(width: 300)
        .fixedSize()
        .background(.black)
        .foregroundStyle(.white)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(phases: .down, action: handleKey)
    }

    /// Shortcuts work in every layout: space, T, S, 1 to 9, and the arrow keys (shift for 5).
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let step = press.modifiers.contains(.shift) ? 5 : 1
        switch press.key {
        case .space: store.toggle()
        case .upArrow, .rightArrow: store.nudge(step)
        case .downArrow, .leftArrow: store.nudge(-step)
        default:
            switch press.characters.lowercased() {
            case "t": store.tap()
            case "s": store.saveCurrentAsPreset()
            case let key where Int(key).map((1...9).contains) == true:
                let index = Int(key)! - 1
                guard store.settings.presets.indices.contains(index) else { return .ignored }
                store.apply(store.settings.presets[index])
            default: return .ignored
            }
        }
        return .handled
    }
}
