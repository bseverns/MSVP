# Transport Ownership

MSVP follows transport. It does not own transport.

## Source of truth

- MIDI Clock (`0xF8`) is the timing source.
- `Start` (`0xFA`), `Stop` (`0xFC`), and `Continue` (`0xFB`) are honored.
- MSVP never generates MIDI Clock and should not be treated as a transport
  authority.

## What Start, Stop, and Continue do

- `Start` resets beat tracking, clears stale state, sets transport to
  `playing`, and begins counting from beat `0`.
- `Stop` sets transport to `stopped`. The sketch window stays alive and the last
  rendered frame remains visible until new clock activity resumes.
- `Continue` resumes transport without resetting the beat counter.
- Song Position Pointer is honored for beat placement when received.

## Stale clock behavior

- MSVP marks transport as `stale` after about `750ms` without clock ticks while
  transport is still marked `playing`.
- BPM holds at the last derived value. It does not invent a new tempo.
- Beat-driven effect windows stop advancing because `beatCount` stops moving.
- The HUD should make this visible through `Transport: stale` rather than
  leaving operators guessing.

## If the loopback MIDI port is missing

- The sketch does not fall back to becoming a clock source.
- If only Java's `Real Time Sequencer` is present, MSVP refuses to use it.
- The window stays open, the output stays black, and the overlay/console become
  the failure surface:
  - top banner when there are no valid MIDI devices
  - full-screen `MIDI init failed; see console` when port init fails
  - HUD text showing MIDI is not connected
- The operator action is to create or select a real loopback port, then restart
  or relaunch the sketch.

## Healthy rig overlay

During healthy rig use, the `?` overlay should show at least:

- BPM tracking the incoming master clock
- beat count advancing
- `Transport: playing`
- active preset
- selected MIDI input, ideally the interop-preferred loopback input
- last CC received
- video ready state

If those fields are not coherent, treat that as a routing problem first, not a
transport invitation for MSVP to take over.
