# Integrating `videoProcessing-midi-sync` with `live-rig`

This document describes how to treat `MidiVideoSyphonBeats` as a *visual endpoint*
inside a larger performance system like `live-rig`.

The goal is to make this Processing sketch behave like another “visual instrument”
in your graph:

- It listens to **MIDI clock** for transport.
- It listens to **MIDI CCs** for control.
- It exposes a **Syphon server** as its output, which can be routed into any
  VJ tool or another Processing sketch.

This repo ships with two main modes:

1. **Generic mode** (this repository):
   - No assumptions about channels or controllers.
   - Simple, controller-agnostic CC mapping.
2. **Rig-tuned mode** (in your `live-rig` repo):
   - Knows about specific devices (e.g. PCM-30 on Ch 10, frZone on Ch 15).
   - Uses your macro / analysis lane semantics.

This document focuses on the *conceptual wiring* so you can map it cleanly
from `live-rig` or any other routing system.

---

## 1. Transport: MIDI Clock

`MidiVideoSyphonBeats` expects MIDI Clock messages:

- Message: `0xF8` (MIDI Clock).
- Resolution: **24 ticks per beat**.

In `MidiVideoSyphonBeats.pde`:

```java
int   ticksPerBeat = 24;
int   tickCounter  = 0;
long  lastBeatTimeMs = -1;
long  beatCount = 0;
float bpm = 100.0;
```

Every 24 ticks it:

- Increments `beatCount`.
- Estimates **BPM** from tick timing.
- Smooths BPM using `bpmSmoothing` from `Config.pde`.
- Sets `video.speed(bpm / 100.0)` so that:

  - `100 BPM → 1.0x speed`
  - `50 BPM → 0.5x`
  - `200 BPM → 2.0x`, etc.

### How to feed clock from `live-rig`

- If `live-rig` already sends MIDI clock to other devices:
  - Add *one more* routing target pointing to this Processing sketch.
- If you’re testing in isolation:
  - Use the included `MidiClockSimulator` sketch.
  - Route its MIDI **output** to the same virtual port that Processing listens to.

The key invariant is: **this sketch does not own the transport**.
It derives tempo from the same clock as the rest of your rig.

---

## 2. Control: Macros vs. Generic CCs

In the generic version (this repo), `controllerChange()` is intentionally simple:

- It responds to CCs **on any channel**.
- It uses fixed mappings:

  ```java
  CC1 -> linesPerFrame
  CC2 -> maxLineSize
  CC3 -> opacityMin
  CC4 -> effectIntervalBeats
  CC5 -> effectDurationBeats
  CC6 -> bpmSmoothing
  CC7 -> effectBias
  ```

This makes it easy to:

- Point *any* MIDI controller or routing node at the sketch.
- Start sculpting the visuals without worrying about rig semantics yet.

### When you integrate with `live-rig`

In your `live-rig` repo, you likely want a **tuned variant** of this sketch where:

- Macros from a specific device (e.g. PCM-30 on Ch 10) drive expressive controls:
  - glitch / feedback / tunnel / density / brightness
- Analysis from another lane (e.g. frZone on Ch 15) biases those parameters.
- Channels and CCs match your mapping sheets.

That tuned variant can live alongside this generic one, but conceptually:

- `live-rig` decides **which CCs mean what**.
- This sketch is a *sink* that converts those CCs into:
  - Line density
  - Line size
  - Rotation depth
  - Effect timing
  - etc.

To adapt this repo to your rig’s grammar:

1. Clone `MidiVideoSyphonBeats` into your `live-rig` repo.
2. Replace `controllerChange()` with your rig-specific mapping:
   - Gate by `channel` (e.g. 10 and 15).
   - Map from your macro/analysis concepts to the parameters here.
3. Optionally, keep this generic copy as a template / test harness.

---

## 3. Output: Syphon as a Visual Node

`MidiVideoSyphonBeats` exposes its output as a Syphon server:

```java
syphonServer = new SyphonServer(this, "MidiVideoSyphonBeats");
...
syphonServer.sendScreen();
```

The important pieces for integration:

- **Name**: `"MidiVideoSyphonBeats"` (you can change this).
- **Topology**:
  - Source: this Processing sketch.
  - Receiver: any Syphon client (Resolume, MadMapper, another Processing sketch).

For `live-rig`, you can treat this Syphon server as:

- A leaf node in your visual graph (raw endpoint).
- Or an intermediate node feeding into other tools for further processing.

The included `SyphonClientTest` and `SyphonPostProcess` sketches show how to
chain Syphon streams inside Processing itself.

---

## 4. Typical Wiring Scenarios

### A. DAW / Clock → `live-rig` → Processing

```text
[DAW or master clock]
     │ (MIDI Clock + CC)
     ├──> [live-rig routing / macros]
     │        │
     │        ├──> [other devices]
     │        └──> [Processing: MidiVideoSyphonBeats]
     │
     └──> [audio path → frZone or analysis]
```

- `live-rig` sends:
  - Clock → this sketch (direct or via loopback).
  - CC macros → this sketch.
- This sketch:
  - Renders visuals based on those controls.
  - Publishes a Syphon stream.

### B. Processing as a Visual Subsystem

```text
[live-rig] ──MIDI──> [Processing (MidiVideoSyphonBeats)]
                  └─Syphon──> [Resolume / other VJ app]
```

You can also:

- Add more Processing sketches as Syphon clients.
- Treat each as a separate “visual instrument” in the rig.

---

## 5. Recommended Files to Copy into `live-rig`

When you integrate:

- Copy `MidiVideoSyphonBeats/` into a suitable folder (e.g. `visuals/processing/`).
- Copy `SyphonClientTest/` and `SyphonPostProcess/` if you want chained Processing nodes.
- Optionally keep `MidiClockSimulator/` around as a local dev tool.

Then:

1. Add a note in `live-rig`’s docs linking to this repo.
2. Document your rig-specific `controllerChange()` mapping.
3. Treat this sketch like any other SCapp or visual endpoint in your graphs.

---

## 6. Summary

Conceptually, this sketch is:

- A **clock-synced visual agent**, not a transport owner.
- A **CC-controlled interpreter**, not a controller.
- A **Syphon publisher**, not a compositor.

`live-rig` is the conductor.
This repo provides a musician that plays along in time.
