# Rig-tuned plan (grounding pass)

## Current behavior summary

### MidiVideoSyphonBeats/MidiVideoSyphonBeats.pde
- Initializes a 1000x750 P3D window, loads defaults from `Config.pde`, starts a Syphon server named `MidiVideoSyphonBeats`, and loops `data/video.mp4`.
- MIDI init: lists devices, refuses to start if device lists are empty, then tries input candidates matching `"Bus 1"` / `"IAC"` (fallback index 1), skipping Java's "Real Time Sequencer"; no MIDI output is used (`-1`). On failure it keeps a black frame with HUD/overlays.
- Draw loop:
  - If MIDI isn't ready, draws HUD + error overlays and sends a black Syphon frame.
  - If video isn't ready, returns early.
  - Sets `video.speed(bpm / 100.0)`.
  - Runs `onBeat()` once per beat to start/stop effect windows.
  - Effect modes:
    - `lines`: draws the video + randomized strokes sampled from video pixels.
    - `rotate`: rotates pixels in-place and draws the modified frame.
  - Sends the Syphon frame and draws the HUD every frame.
- Beat tracking: `rawMidi()` handles MIDI clock `0xF8`, counts 24 ticks per beat, and smooths BPM via `bpmSmoothing`.
- Generic control mapping: `controllerChange()` listens on any channel and maps CC1-CC7 to parameters (density, line size, opacity min, effect interval/duration, BPM smoothing, effect bias).
- Note hooks exist but are unused.
- There is no MIDI Start/Stop/Continue handling; beatCount never resets unless you restart the sketch.

### MidiVideoSyphonBeats/MidiHelpers.pde
- Shared MIDI helpers to avoid the "Real Time Sequencer" trap.
- Validates that input/output lists contain real names.
- Builds candidate indices from name hints and a fallback index; always filters out "Real Time Sequencer".
- Provides `findMidiInputIndex` / `findMidiOutputIndex` helpers for other sketches.

### MidiVideoSyphonBeats/Config.pde
- Hard min/max bounds for CC mapping.
- Default runtime parameters:
  - `effectIntervalBeats = 8`, `effectDurationBeats = 2`
  - `linesPerFrame = 100`, `maxLineSize = 100`
  - `opacityMin = 50`, `opacityMax = 255`
  - `bpmSmoothing = 0.3`

### docs/live-rig-endpoint.md
- Describes the sketch as a "visual endpoint" with MIDI clock + CC input and Syphon output.
- Defines two modes: generic mode (controller-agnostic CCs) and rig-tuned mode (device/channel-aware macros).
- Explains CC mapping and suggests replacing `controllerChange()` in a rig-specific copy.

### docs/midi-loopback-setup.md
- Step-by-step instructions for creating IAC (macOS) or loopMIDI (Windows) virtual ports.
- Notes the "Real Time Sequencer" issue and how to avoid it.

### ExampleMappings.md
- Documents the CC1-CC7 mapping with ranges, descriptions, and suggested knob layout.
- Includes quick debug steps for reading MIDI CC numbers from `MidiClockMonitor`.

### Missing files referenced in prompt
- `live-rig-endpoint`, `midi-loopback-setup`, and `ExampleMappings` (without `.md`) do not exist in this repo; only the `.md` versions are present.

---

## Integration delta (rig-tuned mode, preserving generic mode)

1. **Mode switch (generic vs rig-tuned)**
   - Add a mode flag (compile-time or config-time) so generic behavior remains intact.
   - Rig-tuned mode should be opt-in and leave current defaults unchanged.

2. **Channel gating**
   - In rig-tuned mode, accept CCs only from specific channels (e.g., macro lane vs analysis lane).
   - Keep current "any channel" behavior in generic mode.

3. **Preset system**
   - Define preset parameter bundles (e.g., density/opacity/effect windows).
   - Add a way to select presets (e.g., CC or note), scoped to rig-tuned mode.

4. **Start/stop semantics**
   - Implement handling for MIDI Start/Stop/Continue (0xFA/0xFC/0xFB) or a rig-defined CC gate.
   - Decide how stop affects playback (pause video? freeze effects?) and whether start resets beat counters.

5. **Contract loading**
   - Load a rig contract (JSON/CSV) describing channels, CC mappings, and presets.
   - On missing/invalid contract, fall back to generic defaults without crashing.

---

## Execution checklist (next prompts)

- [ ] Prompt 1 — Add a rig-mode flag + lightweight contract schema; load a contract file from `MidiVideoSyphonBeats/data/` with safe fallback.
- [ ] Prompt 2 — Implement channel gating + rig-specific CC mapping from the contract while keeping current generic mapping unchanged.
- [ ] Prompt 3 — Add a preset table + selection mechanism (CC or note) for rig-tuned mode.
- [ ] Prompt 4 — Add transport start/stop/continue handling with defined beat/reset semantics.
- [ ] Prompt 5 — Update docs to describe rig-tuned mode, contract file format, and expected channels/CCs.

---

## Scene presets (rig-tuned)

| Preset | Note (Ch10) | linesPerFrame | maxLineSize | opacityMin | effectIntervalBeats | effectDurationBeats | effectBias |
| ------ | ---------- | ------------- | ----------- | ---------- | ------------------- | ------------------- | ---------- |
| Intro  | 60         | 60            | 140         | 40         | 8                   | 2                   | 0 (alt)    |
| Crash  | 61         | 280           | 220         | 160        | 2                   | 4                   | 1 (rotate) |
| Soft   | 62         | 30            | 80          | 20         | 12                  | 1                   | -1 (lines) |
