# MSVP Scene Behavior Note

## Current Answer

Scenes currently behave like **momentary performance gestures implemented as
base-state replacements**.

They are not temporary overlays in the current implementation because applying a
scene writes directly into the rig base parameters through `setParam(...)`.
They are also not durable scene modes in the MIDI fallback path because note-off
returns the active preset to `Neutral`.

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

- `handleSceneNoteOn(...)` applies the matching preset when rig mode is enabled
  and the note arrives on the rig macro channel.
- `handleSceneNoteOff(...)` applies `presetNeutral` when
  `PRESET_NOTE_OFF_REVERT_TO_NEUTRAL` is true.
- `applyPreset(...)` calls `setParam(...)` for the scene values.

Because `setParam(...)` writes rig-mode values into `rigBase*` fields in
[ActionRouter.pde](../MidiVideoSyphonBeats/ActionRouter.pde), scene changes
overwrite the current macro base state. Macro state is not restored when the
scene releases. Instead, note-off and OSC off apply the startup neutral preset.

Analysis state is separate. Scene changes do not clear the `rigBias*` fields;
`applyRigEffectiveValues()` continues to combine the current analysis bias with
whatever base state the scene or macro lane last wrote.

## Current Classification

- **Base-state replacement:** yes, implementation-wise.
- **Temporary overlay:** no, because there is no saved/restored pre-scene macro
  base.
- **Momentary performance gesture:** yes, contract-wise for MIDI note fallback
  and OSC scene on/off, because release returns to neutral.

## Recommendation

Make scenes explicitly **momentary performance gestures that temporarily override
the macro base and restore the previous macro base on release**.

Implementation path:

1. Keep the existing scene contract and note/OSC on-off semantics.
2. Before the first active scene override, snapshot the current `rigBase*`
   macro values.
3. Apply scene presets as the temporary base while the scene is active.
4. On MIDI note-off or OSC off, restore the saved macro base instead of applying
   the startup neutral preset.
5. Leave `rigBias*` analysis values untouched so analysis continues to behave as
   bias on top of the active base.
6. Document whether overlapping scene triggers are last-wins or stack-based
   before changing the implementation.
