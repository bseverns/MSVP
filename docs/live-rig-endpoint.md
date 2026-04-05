# MSVP as a live-rig Endpoint

This document describes the aligned contract between three repos:

- `MSVP` as the visual endpoint
- `live-rig` as the field manual and scene-sheet source
- `live-rig-control` as the performer-facing controller surface

The goal is not just "can these talk?" but "do they describe the same stage
surface with the same scene names, lane meanings, and transport rules?"

## Repo Roles

### `MSVP`

`MidiVideoSyphonBeats` is the sink:

- follows MIDI clock
- accepts scene cues
- accepts macro shaping on MIDI Ch `10`
- accepts analysis bias on MIDI Ch `15`
- publishes a Syphon stream

### `live-rig`

`live-rig` is the rig-level semantic sheet:

- stable scene IDs
- stable scene OSC addresses
- stable fallback MIDI note assignments
- transport ownership rules

Its `mappings.json` should keep the MSVP scene vocabulary stable:

- `vid_scene_intro` -> `/video/scene/intro` -> note `60`
- `vid_scene_crash` -> `/video/scene/crash` -> note `61`
- `vid_scene_soft` -> `/video/scene/soft` -> note `62`

### `live-rig-control`

`live-rig-control` is the active emitter:

- `msvp` page for scene cues and shaping
- scene row is OSC-primary
- macro row emits MIDI CC on Ch `10`
- analysis row emits MIDI CC on Ch `15`

It intentionally does not double-fire scene changes through both OSC and MIDI on
the main MSVP page.

## Stable Contract Surfaces

The shared contract mirror is
[contracts/msvp_live_rig_control.yaml](/Users/bseverns/Documents/GitHub/MSVP/contracts/msvp_live_rig_control.yaml).

The local endpoint config that MSVP actually loads at runtime is
[live_rig_interop.json](/Users/bseverns/Documents/GitHub/MSVP/MidiVideoSyphonBeats/data/live_rig_interop.json).

Those two files together should keep these surfaces fixed:

1. Scene semantic IDs.
2. Scene OSC addresses.
3. Scene MIDI note fallback.
4. Macro lane channel and CC meanings.
5. Analysis lane channel and CC meanings.
6. Transport ownership.

## Transport Ownership

MSVP is follower-only.

- Clock comes from upstream MIDI realtime.
- Continuous shaping comes from MIDI CC.
- Semantic scene commands are OSC-primary with MIDI note fallback.
- If clock goes stale, MSVP holds the last derived BPM; it does not become the
  transport owner.

See [TRANSPORT_OWNERSHIP.md](/Users/bseverns/Documents/GitHub/MSVP/docs/TRANSPORT_OWNERSHIP.md).

## Scene Commands

Canonical scene contract:

| Semantic ID | OSC | MIDI fallback |
| --- | --- | --- |
| `vid_scene_intro` | `/video/scene/intro` | Ch `10`, note `60` |
| `vid_scene_crash` | `/video/scene/crash` | Ch `10`, note `61` |
| `vid_scene_soft` | `/video/scene/soft` | Ch `10`, note `62` |

`live-rig-control` emits the OSC addresses on the `msvp` page.
MSVP still listens for the note fallback path so manual/debug routing stays
possible.

## Continuous Shaping Lanes

Macro lane:

- transport: MIDI CC primary
- channel: `10`
- OSC equivalent: `/msvp/macro/<param>`

Analysis lane:

- transport: MIDI CC primary
- channel: `15`
- OSC equivalent: `/msvp/analysis/<param>`

Shared parameter vocabulary for both lanes:

- `linesPerFrame`
- `maxLineSize`
- `opacityMin`
- `effectIntervalBeats`
- `effectDurationBeats`
- `bpmSmoothing`
- `effectBias`

The meaning split matters:

- macro sets base intent
- analysis adds bias on top

## Output Surface

MSVP publishes Syphon under:

```text
MidiVideoSyphonBeats
```

That makes it a visual node downstream of the rig contract, not part of the
controller contract itself.

## Validation

Run:

```sh
python3 scripts/validate_rig_interop.py
```

That validates:

- this repo's shipped `live_rig_interop.json`
- `../live-rig/mappings.json` when present
- `../live-rig-control/src/mappings.json` when present

If you only want to validate this repo in isolation:

```sh
python3 scripts/validate_rig_interop.py --local-only
```
