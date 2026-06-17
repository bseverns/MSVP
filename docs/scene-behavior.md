# MSVP Scene Behavior Note

## Current Answer

Scenes behave like **momentary performance gestures that temporarily override
the macro base**.

Scene note-on or OSC on applies the scene preset as the active rig base while
the scene is held. Scene note-off, MIDI note-on with velocity `0`, or OSC off
restores the macro base that was active before the first active scene override.

## Current Behavior

Scene triggers enter through:

- MIDI note fallback in
  [MidiVideoSyphonBeats.pde](../MidiVideoSyphonBeats/MidiVideoSyphonBeats.pde)
  via `noteOn(...)` and `noteOff(...)`.
- OSC scene addresses in
  [MidiVideoSyphonBeats.pde](../MidiVideoSyphonBeats/MidiVideoSyphonBeats.pde)
  via `/video/scene/intro`, `/video/scene/crash`, and `/video/scene/soft`.

Preset application lives in
[Presets.pde](../MidiVideoSyphonBeats/Presets.pde):

- `handleSceneNoteOn(...)` applies the matching scene override when rig mode is
  enabled and the note arrives on the rig macro channel.
- `handleSceneNoteOff(...)` releases the matching scene override.
- OSC scene addresses use `1` or no args as on, and `0` as off.
- `applySceneOverride(...)` snapshots the current `rigBase*` macro values
  before the first active scene override, then applies the scene preset through
  `applyPreset(...)`.
- `releaseSceneOverride(...)` restores the saved `rigBase*` macro values.

`applyPreset(...)` still calls `setParam(...)` for the scene values, so a held
scene uses the same constrained rig-base path as the macro lane. The difference
is that release restores the saved base instead of applying the startup neutral
preset.

Analysis state is separate. Scene changes do not clear the `rigBias*` fields;
`applyRigEffectiveValues()` continues to combine the current analysis bias with
whatever base state the scene or macro lane last wrote.

Direct neutral preset commands remain direct preset commands:

- `/video/scene/neutral` with an active value applies `Neutral`.
- `/msvp/preset/neutral` with an active value applies `Neutral`.

## Overlap Semantics

Overlapping scene triggers are **last-wins with a single active scene slot**.

- The first active scene snapshots the macro base.
- A later scene-on replaces the active scene preset without taking a new
  snapshot.
- Release for an older, non-current scene is ignored.
- Release for the current last-triggered scene restores the original snapshot.
- Scene triggers are not reference-counted; duplicate note-ons for the same
  scene are released by the first matching note-off.

## Current Classification

- **Base-state replacement while held:** yes, scene presets are applied through
  the rig base path.
- **Temporary overlay:** yes, release restores the saved pre-scene macro base.
- **Momentary performance gesture:** yes, MIDI fallback and OSC scene on/off
  both use hold/release semantics.

## Implementation Notes

`rigBias*` analysis values are not part of the snapshot and are not cleared by
scene changes. Analysis continues to behave as bias on top of whichever base is
currently active: the scene base while held, or the restored macro base after
release.
