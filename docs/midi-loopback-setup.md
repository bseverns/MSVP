# MIDI loopback setup (macOS + Windows)

Short, practical steps to make a **real** virtual MIDI port. This is the fix for the
"Real Time Sequencer" trap — you want an actual loopback device that TheMidiBus can open
without face-planting.

## macOS (IAC Bus)

1. Open **Audio MIDI Setup** (Applications → Utilities).
2. From the menu bar, choose **Window → Show MIDI Studio**.
3. Double‑click **IAC Driver**.
4. Check **Device is online**.
5. (Optional) Click **+** to add a new bus, then rename it to something readable
   (e.g., `MSVP Loopback`).
6. Hit **Apply** and close the window.

You now have a legit MIDI input/output to route your DAW or simulator into.

## Windows (loopMIDI)

1. Download and install **loopMIDI** from:
   <https://www.tobias-erichsen.de/software/loopmidi.html>
2. Launch **loopMIDI**.
3. Click the **+** button to create a new virtual MIDI port.
4. Rename it to something obvious (e.g., `MSVP Loopback`) so you can spot it in lists.

That port will show up immediately in your MIDI app/DAW and TheMidiBus input list.

---

If you still see only **"Real Time Sequencer"**, you’re not looking at a real port yet.
Go back, make the virtual device, and then pick **its index** in the sketch.
