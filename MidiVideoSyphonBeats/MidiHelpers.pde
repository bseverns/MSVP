// Shared MIDI setup helpers.
//
// This file is intentionally duplicated across sketches so Processing auto-loads it.
// If you change logic here, copy the same edits into the other MidiHelpers.pde files
// to keep every sketch behaving identically.

MidiBus safeMidiBus(int inputIndex, int outputIndex) {
  try {
    return new MidiBus(this, inputIndex, outputIndex);
  } catch (Exception e) {
    println("MIDI init failed. TheMidiBus can throw a NullPointerException when the selected");
    println("device is not a real MIDI port (e.g. Java's \"Real Time Sequencer\") or when no");
    println("virtual loopback device is installed.");
    println("Fix: install a virtual MIDI port (IAC on macOS, loopMIDI on Windows) or choose a");
    println("hardware device index from MidiBus.list(), then update the indices above.");
    e.printStackTrace();
    return null;
  }
}

int findMidiInputIndex(String[] nameHints, int fallbackIndex) {
  String[] inputs = MidiBus.availableInputs();
  if (inputs == null || inputs.length == 0) {
    return fallbackIndex;
  }

  for (int i = 0; i < inputs.length; i++) {
    String inputName = inputs[i];
    if (inputName == null) continue;
    String normalized = inputName.toLowerCase();
    for (int hintIndex = 0; hintIndex < nameHints.length; hintIndex++) {
      String hint = nameHints[hintIndex];
      if (hint == null) continue;
      if (normalized.indexOf(hint.toLowerCase()) >= 0) {
        return i;
      }
    }
  }

  return fallbackIndex;
}

int findMidiOutputIndex(String[] nameHints, int fallbackIndex) {
  String[] outputs = MidiBus.availableOutputs();
  if (outputs == null || outputs.length == 0) {
    return fallbackIndex;
  }

  for (int i = 0; i < outputs.length; i++) {
    String outputName = outputs[i];
    if (outputName == null) continue;
    String normalized = outputName.toLowerCase();
    for (int hintIndex = 0; hintIndex < nameHints.length; hintIndex++) {
      String hint = nameHints[hintIndex];
      if (hint == null) continue;
      if (normalized.indexOf(hint.toLowerCase()) >= 0) {
        return i;
      }
    }
  }

  return fallbackIndex;
}
