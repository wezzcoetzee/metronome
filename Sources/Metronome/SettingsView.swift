import AppKit
import MetronomeCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(MetronomeStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var selectedPreset: Preset.ID?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        let settings = store.settings
        VStack(alignment: .leading, spacing: 0) {
            row("Layout") { segmented("Layout", \.layout, MetronomeLayout.allCases, label: \.name) }
            row("Sound") {
                HStack {
                    segmented("Sound", \.sound, Sound.allCases, label: \.name)
                    Button { store.preview() } label: {
                        Image(systemName: "play.fill").frame(width: 24, height: 24).contentShape(Rectangle())
                    }
                        .buttonStyle(.plain)
                        .help("Preview")
                        .accessibilityLabel("Preview sound")
                }
            }
            row("Time signature") {
                HStack(spacing: 4) {
                    Picker("Beats", selection: binding(\.timeSignature.beats)) {
                        ForEach(TimeSignature.beatRange, id: \.self) { Text("\($0)") }
                    }
                    Text("/")
                    Picker("Note value", selection: binding(\.timeSignature.noteValue)) {
                        ForEach(TimeSignature.noteValues, id: \.self) { Text("\($0)") }
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            row("Accent") { BeatDots(size: 14) }
            row("Subdivision") { segmented("Subdivision", \.subdivision, Subdivision.allCases, label: \.symbol, help: \.name) }
            row("Volume") { Slider(value: binding(\.volume), in: 0...1) { Text("Volume") }.labelsHidden().tint(.white).frame(width: 200) }
            row("Launch at login") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            presets(settings)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(width: 640)
        .background(.black)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private func presets(_ settings: MetronomeSettings) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Preset").frame(maxWidth: .infinity, alignment: .leading)
                Text("BPM").frame(width: 60, alignment: .leading)
                Text("Sig").frame(width: 70, alignment: .leading)
                Text("Sound").frame(width: 120, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.dim)
            .padding(.top, 14)
            .padding(.horizontal, 16)

            List(selection: $selectedPreset) {
                ForEach(settings.presets) { preset in
                    HStack {
                        TextField("Name", text: presetBinding(preset.id, \.name))
                            .fontWeight(settings.matches(preset) ? .semibold : .regular)
                            .frame(maxWidth: .infinity)
                        TextField("BPM", value: presetBinding(preset.id, \.bpm), format: .number).frame(width: 60).monospaced()
                        Text(preset.meter).monospaced().frame(width: 70, alignment: .leading)
                        Picker("Sound", selection: presetBinding(preset.id, \.sound)) {
                            ForEach(Sound.allCases) { Text($0.name).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    .textFieldStyle(.plain)
                    .tag(preset.id)
                }
                .onMove(perform: move)
            }
            .scrollContentBackground(.hidden)
            .onDeleteCommand { selectedPreset.map(remove) }
            .frame(height: 170)

            HStack(spacing: 12) {
                Button("+ Add current") { store.saveCurrentAsPreset() }
                    .help(store.settings.isSavedAsPreset ? "Already saved" : "")
                    .disabled(store.settings.isSavedAsPreset)
                Button("− Remove") { selectedPreset.map(remove) }
                    .disabled(selectedPreset == nil)
                Spacer()
                Text("Drag to reorder").foregroundStyle(Color.dim)
            }
            .buttonStyle(.plain)
        }
    }

    /// Removes a preset. Undo reinserts just that preset at its old position, and redo removes it again.
    private func remove(_ id: Preset.ID) {
        guard let index = store.settings.presets.firstIndex(where: { $0.id == id }) else { return }
        let preset = store.settings.presets[index]
        store.update { $0.presets.remove(at: index) }
        if selectedPreset == id { selectedPreset = nil }
        registerUndo("Remove Preset") { reinsert(preset, at: index) }
    }

    private func reinsert(_ preset: Preset, at index: Int) {
        store.update { $0.presets.insert(preset, at: min(index, $0.presets.count)) }
        registerUndo("Remove Preset") { remove(preset.id) }
    }

    private func move(_ source: IndexSet, _ destination: Int) {
        let previous = store.settings.presets.map(\.id)
        store.update { $0.presets.move(fromOffsets: source, toOffset: destination) }
        registerUndo("Move Preset") { reorder(previous) }
    }

    /// Restores an order by id, so undoing a move keeps any edits made since.
    private func reorder(_ ids: [Preset.ID]) {
        let current = store.settings.presets.map(\.id)
        store.update { settings in
            settings.presets.sort { (ids.firstIndex(of: $0.id) ?? .max) < (ids.firstIndex(of: $1.id) ?? .max) }
        }
        registerUndo("Move Preset") { reorder(current) }
    }

    private func registerUndo(_ name: String, _ action: @escaping @MainActor () -> Void) {
        undoManager?.registerUndo(withTarget: store) { _ in MainActor.assumeIsolated(action) }
        undoManager?.setActionName(name)
    }

    private func row(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }

    private func segmented<Value: Hashable>(
        _ title: String,
        _ keyPath: WritableKeyPath<MetronomeSettings, Value>,
        _ options: [Value],
        label: KeyPath<Value, String>,
        help: KeyPath<Value, String>? = nil
    ) -> some View {
        let selectedName = store.settings[keyPath: keyPath][keyPath: help ?? label]
        return Picker(title, selection: binding(keyPath)) {
            ForEach(options, id: \.self) { option in
                let name = option[keyPath: help ?? label]
                Text(option[keyPath: label]).tag(option).help(name).accessibilityLabel(name)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        // Segment-level modifiers can be dropped by the native control, so name the selection here too.
        .help(selectedName)
        .accessibilityValue(selectedName)
    }

    private func presetBinding<Value>(_ id: Preset.ID, _ keyPath: WritableKeyPath<Preset, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings.presets.first { $0.id == id }?[keyPath: keyPath] ?? Preset(name: "", bpm: 0)[keyPath: keyPath] },
            set: { value in store.updatePreset(id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<MetronomeSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in store.update { $0[keyPath: keyPath] = value } }
        )
    }
}
