# Rig-Tuned Audit

This audit covers the current shipped contract at
`MidiVideoSyphonBeats/data/live_rig_interop.json` and the operator guidance in
`docs/rig-tuned-quickstart.md`.

## Boundary

MSVP has two modes and the boundary is explicit:

- Generic sketch mode: `runtime.rigTunedMode` is `false`. CC1..CC7 remain the
  simple controller-agnostic map and the sketch accepts them on any channel.
- Rig endpoint mode: `runtime.rigTunedMode` is `true`. Scene notes, macro lane,
  analysis lane, and OSC equivalents become authoritative for live-rig use.

The interop file should describe rig mode precisely without changing the fact
that generic mode is still the default shipping behavior.

## Contract-Critical Fields

| Field | Current value | Why it is critical |
| ---- | ---- | ---- |
| `runtime.rigTunedMode` | `false` by default | This is the mode boundary. If it is off, generic mode wins and rig channel gating is not authoritative. |
| `runtime.midi.preferredInput` | `"IAC Bus 1"` | This is the first routing assumption operators see. If it does not match the actual loopback port, MIDI init can fail or fall back to another port. |
| `runtime.midi.macroChannel` | `10` | This is the rig macro lane channel. Scene note pads also live on this channel in the shipped contract. |
| `runtime.midi.analysisChannel` | `15` | This is the rig analysis lane channel. If it drifts, bias controls stop lining up with the intended source. |
| Scene note assignments | `60=intro`, `61=crash`, `62=soft` on Ch10 | These are the preset triggers the sketch derives from the profile pads. If the notes drift, the live-rig scene sheet and MSVP diverge. |
| Scene OSC addresses | `/video/scene/intro`, `/video/scene/crash`, `/video/scene/soft` | These are the OSC equivalents the sketch listens for directly. Wrong addresses silently bypass preset selection. |
| Macro OSC paths | `/msvp/macro/<param>` | These are the rig macro endpoints used by OSC senders and by the interop-derived mapping logic. |
| Analysis OSC paths | `/msvp/analysis/<param>` | These are the rig bias endpoints. If they drift, analysis stops acting as wind on top of macro. |

## Authoritative Rig Mapping

When rig mode is on, the shipped contract now makes the rig surface explicit:

| Lane | Channel | CCs | Meaning |
| ---- | ---- | ---- | ---- |
| Macro | 10 | `1..7` | `linesPerFrame`, `maxLineSize`, `opacityMin`, `effectIntervalBeats`, `effectDurationBeats`, `bpmSmoothing`, `effectBias` |
| Analysis | 15 | `1..7` | Same parameter list, but as bias rather than replacement |

The OSC equivalents use the same parameter names:

- `/msvp/macro/linesPerFrame`
- `/msvp/macro/maxLineSize`
- `/msvp/macro/opacityMin`
- `/msvp/macro/effectIntervalBeats`
- `/msvp/macro/effectDurationBeats`
- `/msvp/macro/bpmSmoothing`
- `/msvp/macro/effectBias`
- `/msvp/analysis/linesPerFrame`
- `/msvp/analysis/maxLineSize`
- `/msvp/analysis/opacityMin`
- `/msvp/analysis/effectIntervalBeats`
- `/msvp/analysis/effectDurationBeats`
- `/msvp/analysis/bpmSmoothing`
- `/msvp/analysis/effectBias`

## Operator Notes

- The shipped JSON keeps `rigTunedMode` off on purpose so the repo still opens
  as a generic sketch without hidden rig assumptions.
- The profile pads are still useful when rig mode is off, but they should be
  treated as contract metadata, not runtime authority.
- Scene pads now declare an explicit exclusive group and explicit note/OSC
  off-values so the rig contract is clearer to both humans and tooling.

## TODOs

- The sketch supports `/video/scene/neutral` and `/msvp/preset/neutral`, but
  the shipped profile does not publish a dedicated neutral pad yet.
- The HUD shows transport, preset, MIDI input, and last CC, but it does not
  currently show an explicit `generic` vs `rig` mode badge.
