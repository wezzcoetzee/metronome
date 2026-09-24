# Metronome

Menu bar metronome for macOS 14+. Presets, tap tempo, time signatures, accents, subdivisions, five synthesised sounds, and four popover layouts (Dial, Numeric, Grid, Ruler) chosen in Settings.

## Run

```sh
./scripts/bundle.sh && open build/Metronome.app
```

`swift test` runs the core tests. `swift scripts/make-icon.swift` regenerates `Resources/AppIcon.icns`. `METRONOME_SNAPSHOT=/tmp/snap .build/debug/Metronome` renders each layout and settings to PNGs.

## Layout

- `Sources/MetronomeCore` holds models, `MetronomeStore` (the single place settings change and persist), `ClickEngine` (sample-accurate `AVAudioSourceNode` output) and `SoundSynth`.
- `Sources/Metronome` holds the SwiftUI menu bar app. Every layout is a view over the same store.

## Popover shortcuts

Space start/stop, T tap, S save preset, 1 to 9 load preset, arrows ±1 (shift ±5), ⌘, settings, ⌘Q quit.
