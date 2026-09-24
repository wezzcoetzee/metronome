import AppKit
import MetronomeCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(MetronomeStore.self) private var store
    @State private var selectedPreset: Preset.ID?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        let settings = store.settings
        VStack(alignment: .leading, spacing: 0) {
            row("Layout") { segmented(\.layout, PopoverLayout.allCases, label: \.name) }
            row("Menu bar") { segmented(\.menuBarStyle, MenuBarStyle.allCases, label: \.name) }
            row("Sound") {
                HStack {
                    segmented(\.sound, Sound.allCases, label: \.name)
                    Button { store.preview() } label: { Image(systemName: "play.fill") }
                        .buttonStyle(.plain)
                        .help("Preview")
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
            row("Accent") { BeatDots(size: 14, editable: true) }
            row("Subdivision") { segmented(\.subdivision, Subdivision.allCases, label: \.symbol) }
            row("Volume") { Slider(value: binding(\.volume), in: 0...1).tint(.white).frame(width: 200) }
            row("Launch at login") {
                Toggle("", isOn: $launchAtLogin)
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
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }

    private func presets(_ settings: MetronomeSettings) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Preset").frame(maxWidth: .infinity, alignment: .leading)
                Text("BPM").frame(width: 60, alignment: .leading)
                Text("Sig").frame(width: 40, alignment: .leading)
                Text("Sound").frame(width: 120, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.dim)
            .padding(.top, 14)
            .padding(.horizontal, 16)

            List(selection: $selectedPreset) {
                ForEach(settings.presets) { preset in
                    HStack {
                        TextField("Name", text: presetBinding(preset.id, \.name)).frame(maxWidth: .infinity)
                        TextField("BPM", value: presetBinding(preset.id, \.bpm), format: .number).frame(width: 60).monospaced()
                        Text(preset.timeSignature.description).monospaced().frame(width: 40, alignment: .leading)
                        Picker("Sound", selection: presetBinding(preset.id, \.sound)) {
                            ForEach(Sound.allCases) { Text($0.name).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    .textFieldStyle(.plain)
                    .tag(preset.id)
                }
                .onMove { from, to in store.update { $0.presets.move(fromOffsets: from, toOffset: to) } }
            }
            .scrollContentBackground(.hidden)
            .frame(height: 170)

            HStack(spacing: 12) {
                Button("+ Add current") { store.saveCurrentAsPreset() }
                Button("− Remove") {
                    store.update { $0.presets.removeAll { $0.id == selectedPreset } }
                    selectedPreset = nil
                }
                .disabled(selectedPreset == nil)
                Spacer()
                Text("Drag to reorder").foregroundStyle(Color.dim)
            }
            .buttonStyle(.plain)
        }
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
        _ keyPath: WritableKeyPath<MetronomeSettings, Value>,
        _ options: [Value],
        label: KeyPath<Value, String>
    ) -> some View {
        Picker("", selection: binding(keyPath)) {
            ForEach(options, id: \.self) { Text($0[keyPath: label]).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
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
