# videoProcessing-midi-sync

Processing sketches for live video processing with:

- **MIDI clock sync** (via TheMidiBus)
- **Beat-quantized effects** (video-speed synced to BPM)
- **Syphon output** to other tools (Resolume, MadMapper, VDMX, other Processing sketches)
- A helper sketch to **monitor MIDI BPM + beat count**
- A **MIDI clock + CC simulator** sketch
- A set of **Syphon demos** (client test + post-process feedback toy)

## Structure

```text
videoProcessing-midi-sync/
  README.md
  LICENSE
  .gitignore
  ExampleMappings.md
  MidiVideoSyphonBeats/
    MidiVideoSyphonBeats.pde
    Config.pde
    MidiHelpers.pde
    data/
      video.mp4        # bundled short sample clip; replace as needed
      .gitkeep
  MidiClockMonitor/
    MidiClockMonitor.pde
  MidiClockSimulator/
    MidiClockSimulator.pde
  OscControlSimulator/
    OscControlSimulator.pde
  demos/
    README.md
    SyphonClientTest/
      SyphonClientTest.pde
    SyphonPostProcess/
      SyphonPostProcess.pde
```

## Signal Flow (AKA "what talks to what")

```text
MIDI clock/CC
    ↓
Processing (MidiVideoSyphonBeats)
    ↓
Syphon
    ↓
VJ app
```

## Rig-tuned quickstart (live-rig operator sheet)

If you want the rig-tuned variant (interop contract, macro/analysis lanes, scene presets),
start here: `docs/rig-tuned-quickstart.md`.

### Wiring recipes (copy/paste this into your muscle memory)

1. **DAW → virtual MIDI loopback → Processing**
   - Clock + CC out of your DAW.
   - Pipe it through a virtual MIDI cable (IAC, loopMIDI, etc.).
   - Point `MidiVideoSyphonBeats` at that input. Boom: tempo-locked visuals.

2. **Processing → Syphon → Resolume**
   - `MidiVideoSyphonBeats` is your Syphon server.
   - Resolume is the receiver.
   - Add a Syphon source in Resolume and play it like a synth with pixels.

## Requirements

1. **Processing** (Java mode)
2. Libraries (install via *Sketch → Import Library → Add Library...*):
   - `Video` (Processing Video library, `processing.video.*`)
   - `Syphon for Processing` (`codeanticode.syphon.*`)
   - `TheMidiBus` (`themidibus.*`)
3. A MIDI clock source (hardware, DAW, virtual device, or the provided simulator).
4. A Syphon-capable receiver if you want to route the output into other apps.

---

## Sketch: MidiVideoSyphonBeats

Beat-quantized video processor:

- Receives MIDI clock (24 ticks per beat) and estimates **BPM**.
- Maps BPM to video playback speed:

  ```java
  videoSpeed = bpm / 100.0;
  video.speed(videoSpeed); // 100 BPM -> 1.0x
  ```

- Alternates between two effects, scheduled on **beats**, not frames:
  - **lines** — pseudo-random line field sampled from the video pixels.
  - **rotate** — ring-style pixel rotation of the current video frame.

Effect scheduling is controlled in **beats**:

- `effectIntervalBeats`: how often an effect window starts.
- `effectDurationBeats`: how many beats the effect stays active.

Tunables live in `Config.pde` and several are exposed to MIDI CC.

### Generic MIDI CC mapping (default when rig mode is off)

| CC # | Parameter              | Description                                                        |
|-----|------------------------|--------------------------------------------------------------------|
| 1   | `linesPerFrame`        | Line density per frame (visual “thickness”).                       |
| 2   | `maxLineSize`          | Max length of lines in pixels.                                     |
| 3   | `opacityMin`           | Lower bound of line alpha range (0–255).                           |
| 4   | `effectIntervalBeats`  | How often an effect window starts (beats).                          |
| 5   | `effectDurationBeats`  | How long the effect window lasts (beats).                           |
| 6   | `bpmSmoothing`         | How quickly BPM responds to changes (0.05 = snappy, 0.6 = smooth). |
| 7   | `effectBias`           | -1 = lines only, 0 = alternate, +1 = rotate only.                  |

It responds on any MIDI channel when `runtime.rigTunedMode` is `false` in the interop file.
When rig mode is enabled, macro and analysis channels are gated by the interop contract.

---

## Sketch: MidiClockMonitor

Minimal helper to debug MIDI routing:

- Displays **beat count** and **BPM** on screen.
- Prints beat + BPM to the Processing console.
- Logs incoming `noteOn` and `controllerChange` messages so you can see which
  controller/CC numbers your hardware uses.

Use this first to:

- Confirm MIDI clock is reaching Processing.
- Identify the correct MIDI input index for `MidiBus`.
- Discover what CC numbers your knobs/faders send.

---

## Demos (Syphon playground)

The Syphon client + post-process sketches are **demos**, not core tools. They live in `demos/` and act as quick sanity checks plus remixable starting points.

- **SyphonClientTest**: dead-simple Syphon client to confirm your server is alive.
- **SyphonPostProcess**: feedback-tunnel post-process toy for learning how to fold Syphon frames into your own buffer.

See `demos/README.md` for the full intent + usage notes.

---

## Sketch: MidiClockSimulator

A tiny MIDI **clock + CC simulator** using TheMidiBus:

- Sends MIDI clock ticks (0xF8) at a specified BPM.
- Periodically sends CC messages as simple LFOs on a chosen channel.
- Intended to drive `MidiVideoSyphonBeats` when you don’t have a DAW or hardware connected.

You’ll need a **virtual MIDI loopback** device (e.g. IAC Bus on macOS, loopMIDI on Windows):

- Set the simulator’s MIDI **output** to the virtual port.
- Set `MidiVideoSyphonBeats`’s MIDI **input** to the same virtual port.

---

## Usage

### 1. Put a video in the data folder

The repo ships a short sample clip at:

```text
MidiVideoSyphonBeats/data/video.mp4
```

Replace it with your own loop whenever you want.

Quick spec sheet (keep it punk, keep it playable):

- **Preferred codec:** H.264 (Processing’s `Movie` can choke on some codecs).
- **Resolution:** 720p is a solid default; 1080p if your machine’s beefy; lower if it stutters.
- **File size:** Keep it reasonable — smaller files = faster load + fewer dropped frames.
  Dropping resolution is the easiest win when the effect-heavy `draw()` loop starts to sweat.

Or update the filename in `MidiVideoSyphonBeats.pde`:

```java
video = new Movie(this, "your-video-name.mp4");
```

### 2. Select the MIDI input

1. Open **MidiVideoSyphonBeats** in Processing.
2. Run it once.
3. In the console, look for the output of:

   ```java
   MidiBus.list();
   ```

4. By default, the sketches try the interop file’s preferred MIDI input first, then common loopback names like `Bus 1` and `IAC`.
5. If you want to force a specific device, update `runtime.midi.preferredInput` in `MidiVideoSyphonBeats/data/live_rig_interop.json`.

`MidiClockMonitor` and `MidiClockSimulator` use the same candidate-selection logic.

### 2.5. MIDI device gotchas (aka: why “Real Time Sequencer” bites you)

If your console only shows **"Real Time Sequencer"** and the sketch crashes on the
`new MidiBus(...)` line, that device is *not* a real port. It’s Java’s internal
software sequencer, and TheMidiBus can throw a `NullPointerException` when you try
to open it.

**Fix it like you mean it:**

- **Install a virtual MIDI loopback** (IAC Bus on macOS, loopMIDI on Windows).
- Quick setup guide: [`docs/midi-loopback-setup.md`](docs/midi-loopback-setup.md).
- Route your DAW/simulator into that virtual port.
- Use the virtual port’s **index** in the sketch.

Each sketch now uses a tiny `safeMidiBus(...)` helper that catches the NPE, prints
why it failed, and keeps the window open so you can read the console. It won’t
magically conjure a MIDI port, but it will stop the hard crash and tell you
exactly what to fix.

### Shared MIDI helper pattern (aka “keep it in lockstep”)

Processing only auto-loads `.pde` files that live **inside** each sketch folder,
so the shared helpers are intentionally duplicated as `MidiHelpers.pde` in every
sketch that touches MIDI.

**Workflow, punk-rock edition:**

- Pick one `MidiHelpers.pde` to edit.
- Copy those exact changes into the other `MidiHelpers.pde` files.
- Now every sketch behaves the same, and future-you doesn’t get surprised on
  stage.

### 3. Syphon output / input

- **Output**: `MidiVideoSyphonBeats` exposes a Syphon server named:

  ```text
  MidiVideoSyphonBeats
  ```

- **Input**: `demos/SyphonClientTest` will connect to the first available Syphon server by default.

---

MIT licensed. See `LICENSE` for details.
