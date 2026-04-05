# Rig Smoke Test

Run the contract check first:

```sh
python3 scripts/validate_rig_interop.py
```

If sibling `live-rig` and `live-rig-control` repos are checked out next to this
repo, that same command will flag scene or lane drift there too.

Then verify the live path with the sketch running and the `?` overlay visible.

## Checklist

1. Loopback MIDI port exists and is selected.
   Expected: the HUD shows the intended MIDI input and the console does not
   mention `Real Time Sequencer` as the active route.

2. `rigTunedMode` is `true`.
   Expected: MSVP is using the rig contract, not the generic any-channel CC map.

3. Scene `Intro`, `Crash`, and `Soft` respond correctly.
   Expected: Ch10 notes `60`, `61`, and `62`, or OSC
   `/video/scene/intro|crash|soft`, switch the active preset accordingly.

4. Macro lane changes base intent.
   Expected: Ch10 CC1..CC7, or `/msvp/macro/<param>`, move the base visual state
   in a stable, repeatable way.

5. Analysis lane adds bias without replacing macro.
   Expected: Ch15 CC1..CC7, or `/msvp/analysis/<param>`, nudge the current macro
   state rather than wipe it out.

6. Debug overlay shows expected BPM, active preset, and last CC.
   Expected: BPM tracks the incoming master clock, preset matches the last scene
   trigger, and `Last CC` reflects the most recent lane message.

7. Stale clock behavior is visible and understandable.
   Expected: when clock stops arriving without an explicit MIDI `Stop`, the HUD
   changes to `Transport: stale`, BPM freezes at the last known value, and beat
   changes stop.

## Fail Fast Notes

- If the window is black with a MIDI warning, fix loopback routing before
  testing presets or lanes.
- If scene triggers work but lanes do not, verify `macroChannel` and
  `analysisChannel` first.
- If OSC works but MIDI does not, treat that as a port-selection issue, not a
  contract issue.
