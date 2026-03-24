# How MSVP plugs into live-rig (MIDI + OSC)

One-page operator sheet for **MidiVideoSyphonBeats** as a live-rig endpoint.

## 1) Make a real virtual MIDI port

Follow: `docs/midi-loopback-setup.md`  
You need a real loopback device (IAC on macOS, loopMIDI on Windows).

## 2) Drop in the interop contract

Use the interop file in the sketch data folder:

```
MidiVideoSyphonBeats/data/live_rig_interop.json
```

The shipped file keeps rig mode off so the repo still behaves generically by default.
To enable rig-tuned lanes, flip the runtime flag and set your preferred MIDI port:

```json
{
  "runtime": {
    "rigTunedMode": true,
    "midi": {
      "preferredInput": "IAC Bus 1",
      "macroChannel": 10,
      "analysisChannel": 15
    }
  }
}
```

## 3) Clock routing + follower invariant

MSVP is a **clock follower**. It never owns transport.

- Send MIDI Clock (0xF8) into the loopback port.
- Start/Stop/Continue are honored, but MSVP never generates clock.
- BPM is derived from incoming ticks; if ticks drop out, BPM freezes (stale).

## 4) Scene triggers (MIDI + OSC)

MIDI (Ch10 notes, velocity > 0):

| Note | Preset |
| ---- | ------ |
| 60   | Intro  |
| 61   | Crash  |
| 62   | Soft   |

NoteOff (or velocity 0) returns to Neutral by default.

OSC (arg1 == 1 activates):

```
/video/scene/intro
/video/scene/crash
/video/scene/soft
```

## 5) Generic CC map (any channel, only when rig mode is off)

| CC | Param | Meaning |
| -- | ----- | ------- |
| 1  | linesPerFrame | line density |
| 2  | maxLineSize | max line length |
| 3  | opacityMin | minimum alpha |
| 4  | effectIntervalBeats | how often effect starts |
| 5  | effectDurationBeats | effect length |
| 6  | bpmSmoothing | tempo responsiveness |
| 7  | effectBias | -1 lines / 0 alt / +1 rotate |

## 6) Rig-tuned lanes (macro + analysis)

Defaults (configurable in `runtime.midi` or `runtime.channels`):

```json
"runtime": {
  "midi": {
    "macroChannel": 10,
    "analysisChannel": 15
  }
}
```

- **Macro lane** sets base intent (same params as CC map).
- **Analysis lane** adds wind (bias) without overriding macro.
These lanes are only active when `runtime.rigTunedMode` is `true`.

OSC equivalents (0..1 normalized):

```
/msvp/macro/<param> <0..1>
/msvp/analysis/<param> <0..1>
```

`<param>` matches the CC map names (e.g., `linesPerFrame`, `maxLineSize`, `effectBias`).

## 7) Syphon output

Syphon server name:

```
MidiVideoSyphonBeats
```

Pick it up in Resolume / MadMapper / another Processing sketch.

## 8) On-screen debug overlay

Press `?` to toggle. It shows:
- MIDI input + interop selection
- playing/stopped/stale
- BPM + beatCount
- active preset
- last CC (ch/cc/value)

---

If anything is dead:
- If you only see **"Real Time Sequencer"**, the loopback port is missing.
- Revisit `docs/midi-loopback-setup.md`.
