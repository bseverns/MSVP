# How MSVP plugs into live-rig (MIDI + OSC)

One-page operator sheet for using **MidiVideoSyphonBeats** as either:

- a generic sketch with simple CC control, or
- an explicit live-rig endpoint driven by the shared interop contract.

## 1) Know which mode you are in

### Generic sketch mode

- `runtime.rigTunedMode` is `false`
- this is the shipped default
- CC1..CC7 respond on any MIDI channel
- use this when you want a controller-agnostic sketch, not a rig endpoint

### Rig endpoint mode

- `runtime.rigTunedMode` is `true`
- macro and analysis lanes become authoritative
- scene notes and scene OSC addresses become contract surfaces
- use this when MSVP is acting as a live-rig sink

The config flip is the boundary. Do not blur the two modes together.

## 2) Make a real virtual MIDI port

Follow [docs/midi-loopback-setup.md](/Users/bseverns/Documents/GitHub/MSVP/docs/midi-loopback-setup.md).
You need a real loopback device such as IAC on macOS or loopMIDI on Windows.

## 3) Use the interop contract

The contract lives at
[live_rig_interop.json](/Users/bseverns/Documents/GitHub/MSVP/MidiVideoSyphonBeats/data/live_rig_interop.json).

The shipped file keeps rig mode off so the repo still behaves generically by default.
To make MSVP act as a rig endpoint, flip the runtime flag and set the preferred
loopback input:

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

Validate before launch:

```sh
python3 scripts/validate_rig_interop.py
```

## 4) Clock routing and transport ownership

MSVP is a **clock follower**.

- Send MIDI Clock (`0xF8`) into the selected loopback port.
- `Start`, `Stop`, and `Continue` are honored.
- MSVP never generates MIDI Clock.
- If ticks stop arriving for about `750ms` while transport is still playing, the
  HUD changes to `stale` and BPM holds its last derived value.

See [TRANSPORT_OWNERSHIP.md](/Users/bseverns/Documents/GitHub/MSVP/docs/TRANSPORT_OWNERSHIP.md) for the operator-facing transport rules.

## 5) Scene triggers in rig endpoint mode

MIDI scene triggers use Ch10 notes with velocity greater than `0`:

| Note | Preset |
| ---- | ------ |
| 60 | Intro |
| 61 | Crash |
| 62 | Soft |

NoteOff, or NoteOn with velocity `0`, returns to `Neutral`.

OSC scene equivalents use explicit addresses with `1` for on and `0` for off:

```text
/video/scene/intro
/video/scene/crash
/video/scene/soft
```

## 6) Generic CC map

This map is active only when `runtime.rigTunedMode` is `false`.

| CC | Param | Meaning |
| -- | ----- | ------- |
| 1 | `linesPerFrame` | line density |
| 2 | `maxLineSize` | max line length |
| 3 | `opacityMin` | minimum alpha |
| 4 | `effectIntervalBeats` | how often effect starts |
| 5 | `effectDurationBeats` | effect length |
| 6 | `bpmSmoothing` | tempo responsiveness |
| 7 | `effectBias` | `-1` lines / `0` alternate / `+1` rotate |

## 7) Rig-tuned macro and analysis lanes

These lanes are active only when `runtime.rigTunedMode` is `true`.

Defaults:

```json
"runtime": {
  "midi": {
    "macroChannel": 10,
    "analysisChannel": 15
  }
}
```

Macro lane sets base intent:

| CC | Param |
| -- | ----- |
| 1 | `linesPerFrame` |
| 2 | `maxLineSize` |
| 3 | `opacityMin` |
| 4 | `effectIntervalBeats` |
| 5 | `effectDurationBeats` |
| 6 | `bpmSmoothing` |
| 7 | `effectBias` |

Analysis lane uses the same parameter list as bias, not replacement.

OSC equivalents use normalized `0..1` values:

```text
/msvp/macro/<param> <0..1>
/msvp/analysis/<param> <0..1>
```

## 8) Syphon output

Syphon server name:

```text
MidiVideoSyphonBeats
```

Pick it up in Resolume, MadMapper, or another Processing sketch.

## 9) On-screen debug overlay

Press `?` to toggle the overlay. During healthy rig use it should show:

- the selected MIDI input
- `Transport: playing`
- BPM and beat count
- active preset
- last CC
- video ready state

If anything is dead:

- if you only see **`Real Time Sequencer`**, the loopback port is missing
- if the overlay says MIDI is not connected, fix routing before testing scenes
- use [RIG_SMOKE_TEST.md](/Users/bseverns/Documents/GitHub/MSVP/docs/RIG_SMOKE_TEST.md) as the operator checklist
