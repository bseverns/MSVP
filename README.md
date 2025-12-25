# videoProcessing-midi-sync

Processing sketches for live video processing with:

- **MIDI clock sync** (via TheMidiBus)
- **Beat-quantized effects** (video-speed synced to BPM)
- **Syphon output** to other tools (Resolume, MadMapper, VDMX, other Processing sketches)
- A helper sketch to **monitor MIDI BPM + beat count**
- A **Syphon client test** sketch
- A **MIDI clock + CC simulator** sketch

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
    data/
      video.mp4        # you provide this
      .gitkeep
  MidiClockMonitor/
    MidiClockMonitor.pde
  SyphonClientTest/
    SyphonClientTest.pde
  MidiClockSimulator/
    MidiClockSimulator.pde
  .github/
    workflows/
      noop.yml         # placeholder CI workflow
```

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

### Generic MIDI CC mapping (default)

| CC # | Parameter              | Description                                                        |
|-----|------------------------|--------------------------------------------------------------------|
| 1   | `linesPerFrame`        | Line density per frame (visual “thickness”).                       |
| 2   | `maxLineSize`          | Max length of lines in pixels.                                     |
| 3   | `opacityMin`           | Lower bound of line alpha range (0–255).                           |
| 4   | `effectIntervalBeats`  | How often an effect window starts (beats).                          |
| 5   | `effectDurationBeats`  | How long the effect window lasts (beats).                           |
| 6   | `bpmSmoothing`         | How quickly BPM responds to changes (0.05 = snappy, 0.6 = smooth). |
| 7   | `effectBias`           | -1 = lines only, 0 = alternate, +1 = rotate only.                  |

It responds on any MIDI channel by default; you can gate by channel if desired.

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

## Sketch: SyphonClientTest

Simple Syphon **client** that:

- Connects to a Syphon server (by default the first available one).
- Draws the incoming Syphon texture to the window.
- Optionally overlays a minimal HUD so you can see it’s alive.

Use this to:

- Test that your Syphon server (e.g. `MidiVideoSyphonBeats`) is working.
- Chain Processing → Syphon → another Processing sketch.

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

Place a video file in:

```text
MidiVideoSyphonBeats/data/video.mp4
```

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

4. Change this line in `MidiVideoSyphonBeats.pde`:

   ```java
   midiBus = new MidiBus(this, 0, -1);
   ```

   Replace `0` with the index of the MIDI input receiving clock.

Do the same in `MidiClockMonitor.pde` and `MidiClockSimulator.pde` (for output).

### 2.5. MIDI device gotchas (aka: why “Real Time Sequencer” bites you)

If your console only shows **"Real Time Sequencer"** and the sketch crashes on the
`new MidiBus(...)` line, that device is *not* a real port. It’s Java’s internal
software sequencer, and TheMidiBus can throw a `NullPointerException` when you try
to open it.

**Fix it like you mean it:**

- **Install a virtual MIDI loopback** (IAC Bus on macOS, loopMIDI on Windows).
- Route your DAW/simulator into that virtual port.
- Use the virtual port’s **index** in the sketch.

Each sketch now uses a tiny `safeMidiBus(...)` helper that catches the NPE, prints
why it failed, and keeps the window open so you can read the console. It won’t
magically conjure a MIDI port, but it will stop the hard crash and tell you
exactly what to fix.

### 3. Syphon output / input

- **Output**: `MidiVideoSyphonBeats` exposes a Syphon server named:

  ```text
  MidiVideoSyphonBeats
  ```

- **Input**: `SyphonClientTest` will connect to the first available Syphon server by default.

---

MIT licensed. See `LICENSE` for details.
