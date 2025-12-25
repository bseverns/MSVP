# Example MIDI CC Mappings  
_For MidiVideoSyphonBeats_

These mappings are designed to be practical for live performance.  
Adapt them to your controller layout as needed.

---

## Overview

| CC # | Parameter Controlled | Range (approx)     | Description                                      |
|------|----------------------|--------------------|--------------------------------------------------|
| 1    | `linesPerFrame`      | 10 → 400           | Line density per frame (visual thickness).       |
| 2    | `maxLineSize`        | 5 → 300 px         | Maximum line length.                             |
| 3    | `opacityMin`         | 0 → 255            | Minimum line alpha.                              |
| 4    | `effectIntervalBeats`| 1 → 64 beats       | How often an effect window starts.               |
| 5    | `effectDurationBeats`| 1 → 16 beats       | How long the effect stays active.                |
| 6    | `bpmSmoothing`       | 0.05 → 0.6         | Responsiveness of BPM tracking.                  |
| 7    | `effectBias`         | -1 / 0 / +1        | Lines only / Alternate / Rotate only.            |

---

## Control Glossary (visual outcome)

| Control | What you see on screen |
|---------|-------------------------|
| `linesPerFrame` | How crowded the frame feels: a few quiet marks vs. a wall of scratches. |
| `maxLineSize` | How far a single stroke can stretch before it breaks. |
| `opacityMin` | The faintest a line can get: ghost haze vs. full ink. |
| `effectIntervalBeats` | How often the glitch wakes up. |
| `effectDurationBeats` | How long the glitch sticks around. |
| `bpmSmoothing` | How quickly the visuals chase tempo changes. |
| `effectBias` | Whether you mostly see lines, rotations, or a mix. |

---

## Suggested Layout (generic 8-knob controller)

- **Knob 1 (CC1)** – Texture density  
  Low for sparse, airy strokes. High for dense noise-field textures.

- **Knob 2 (CC2)** – Stroke reach  
  Controls how long strokes can be. Short for grain, long for sweeping gestures.

- **Knob 3 (CC3)** – Transparency floor  
  At 0, lines can be very faint; at 255, everything is fully opaque.

- **Knob 4 (CC4)** – Effect interval (in beats)  
  Turn right to make effect windows rarer (e.g., every 16 or 32 bars).

- **Knob 5 (CC5)** – Effect duration (in beats)  
  Turn right to stretch the effect across more of the phrase.

- **Knob 6 (CC6)** – BPM smoothing  
  Left: very twitchy BPM, follows micro jitter.  
  Right: very lazy, smooth BPM changes for long transitions.

- **Knob 7 (CC7)** – Effect mode bias  
  - Left third: always **LINES**  
  - Middle third: **ALTERNATE** lines / rotate  
  - Right third: always **ROTATE**

---

## Debugging Your Own Controller

1. Run `MidiClockMonitor`.
2. Move knobs / press buttons.
3. Watch the console for logs like:

   ```text
   CC  ch:0  num:21  val:64
   ```

4. Take the `num` value (here, 21) and map it in `controllerChange(...)`
   inside `MidiVideoSyphonBeats.pde`.

This way you can adapt the mappings to any hardware you like.
