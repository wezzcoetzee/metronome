# Metronome

Metronome is a macOS 14+ windowed app with tap tempo, presets, time signatures, per-beat accents, subdivisions, and five synthesised sounds. Choose between Dial, Numeric, Grid, and Ruler layouts in Settings.

## Build and run

Requires macOS 14+ and Xcode with Swift 6. If `xcode-select -p` points to Command Line Tools, select Xcode for this shell first (adjust the path if needed):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

```sh
./scripts/bundle.sh
open build/Metronome.app
```

To make a drag-to-Applications disk image, run `./scripts/dmg.sh`. It rebuilds the app and writes `build/Metronome.dmg`.

## Use

Start and stop playback in the main window. Use Tap to set the tempo, and open Settings to change the layout, sound, time signature, accents, subdivision, volume, and launch-at-login preference. Settings also lets you add, edit, remove, and reorder presets. Tempo is limited to 30–300 BPM; settings and presets persist between launches.

With the main window focused:

| Key | Action |
| --- | --- |
| Space | Start or stop |
| T | Tap tempo |
| S | Save the current tempo, time signature, and sound as a preset |
| 1–9 | Load a preset by its position |
| ↑ or → / ↓ or ← | Increase / decrease tempo by 1 BPM |
| Shift + arrow | Increase / decrease tempo by 5 BPM |

Use the Settings button or ⌘, to open Settings; ⌘Q quits the app.

## Development

`swift test` runs the core tests. `swift scripts/make-icon.swift` regenerates `Resources/AppIcon.icns`. To render PNGs of all four layouts and Settings, run:

```sh
swift build
mkdir -p /tmp/metronome-snapshots
METRONOME_SNAPSHOT=/tmp/metronome-snapshots .build/debug/Metronome
```

## Layout

- `Sources/MetronomeCore` holds models, `MetronomeStore` (the single place settings change and persist), `ClickEngine` (sample-accurate `AVAudioSourceNode` output) and `SoundSynth`.
- `Sources/Metronome` holds the SwiftUI app. Every layout is a view over the same store.
