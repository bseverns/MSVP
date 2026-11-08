# frZone → MSVP MIDI input

MSVP accepts frZone’s existing canonical analysis MIDI without changing frZone’s rig
profile or OSC contract. Both applications use the same virtual MIDI bus:

1. In macOS **Audio MIDI Setup**, create or enable an IAC bus (for example,
   `MSVP Loopback`).
2. Select that bus as frZone’s MIDI **output**.
3. Start MSVP in rig-tuned mode and select the same bus as its MIDI **input**.
   `MidiVideoSyphonBeats/data/live_rig_interop.json` configures its analysis
   channel as MIDI channel 15.
4. Start frZone in its legacy/rig-tuned analysis mode. Its existing Ch 15
   outputs are received by MSVP directly; no OSC bridge or second process is
   required.

## Additive mapping

frZone values are energy values in the inclusive range `0..127`; zero is silence.
MSVP treats them as *positive additive biases* so silence preserves each MSVP macro
base setting. This differs deliberately from MSVP’s signed controller-analysis lane
(CC 1–7), where centre (`64`) is neutral.

| frZone semantic output | MIDI | MSVP visual bias |
| --- | --- | --- |
| `analysis.low_band` | Ch 15, CC 20 | `linesPerFrame` |
| `analysis.mid_band` | Ch 15, CC 22 | `maxLineSize` |
| `analysis.upper_mid_band` | Ch 15, CC 23 | `opacityMin` |
| `analysis.high_band` | Ch 15, CC 24 | `effectBias` |

The second raw frZone band remains local-only, as defined by frZone’s rig contract.
MSVP’s normal Ch 15 CC 1–7 analysis mapping continues to work unchanged; the
frZone CCs do not overlap it.

## Pre-performance check

- Run `python3 scripts/validate_rig_interop.py --local-only` from this repository.
- Run frZone’s `python3 tools/validate_rig_alignment.py` from its repository.
- Use `MidiClockMonitor` to confirm Ch 15 CC 20, 22, 23, and 24 reach the selected
  IAC input before opening a performance patch.
- Verify the four mappings with a sustained tone, then restore MSVP macro defaults.

This is MIDI-only integration. frZone’s OSC output remains available for its existing
live-rig endpoint and is intentionally not redirected to MSVP.
