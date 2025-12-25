# Demos (aka: the jam room)

These sketches are **demos, not core tools**. They exist to prove Syphon wiring, poke at feedback tricks, and make sure your pipeline is alive before you trust it on stage.

Think of this folder as a studio notebook: messy, exploratory, and meant to teach you *what’s possible* rather than *what’s production-ready*.

## What’s in here

### SyphonClientTest
A dead-simple Syphon **client** that pulls from the first available Syphon server and slaps the texture onto a window. If your Syphon pipeline is broken, this sketch is your flashlight.

Use it to:
- sanity-check that a Syphon **server** exists (e.g., `MidiVideoSyphonBeats`),
- confirm frame flow across apps,
- chain Processing → Syphon → Processing without the drama.

### SyphonPostProcess
A feedback-tunnel toy that **reads Syphon input and post-processes it** with a feedback buffer, a soft fade, and a tiny zoom warp. It’s a demo for:

- how to do a cheap feedback loop in Processing,
- layering incoming Syphon frames over your own buffer,
- creating that infinite hallway vibe without a shader.

If you want to build your own post-pass effects, start here and remix.

---

## Why demos live here

These sketches are not the core MIDI/beat tools. They’re experiments and diagnostics. Keep them handy, tweak them, break them, learn from them. That’s the point.
