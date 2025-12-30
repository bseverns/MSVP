// Shared MIDI setup helpers.
//
// This file is intentionally duplicated across sketches so Processing auto-loads it.
// If you change logic here, copy the same edits into the other MidiHelpers.pde files
// to keep every sketch behaving identically.

final String NO_VALID_MIDI_DEVICES_MESSAGE = "No valid MIDI devices detected (Rosetta/MIDI bug?)";

MidiBus safeMidiBus(int inputIndex, int outputIndex) {
  try {
    if (!hasRequestedMidiPorts(inputIndex, outputIndex)) {
      println(NO_VALID_MIDI_DEVICES_MESSAGE + " Skipping MidiBus init.");
      return null;
    }
    return new MidiBus(this, inputIndex, outputIndex);
  } catch (Throwable e) {
    println("MIDI init failed. TheMidiBus can throw a NullPointerException when the selected");
    println("device is not a real MIDI port (e.g. Java's \"Real Time Sequencer\") or when no");
    println("virtual loopback device is installed.");
    println("Fix: install a virtual MIDI port (IAC on macOS, loopMIDI on Windows) or choose a");
    println("hardware device index from MidiBus.list(), then update the indices above.");
    e.printStackTrace();
    return null;
  }
}

boolean hasRequestedMidiPorts(int inputIndex, int outputIndex) {
  boolean needsInput = inputIndex >= 0;
  boolean needsOutput = outputIndex >= 0;

  if (needsInput && !hasUsableMidiInputs()) {
    println(NO_VALID_MIDI_DEVICES_MESSAGE);
    return false;
  }

  if (needsOutput && !hasUsableMidiOutputs()) {
    println(NO_VALID_MIDI_DEVICES_MESSAGE);
    return false;
  }

  return true;
}

boolean hasUsableMidiInputs() {
  return hasUsableMidiNames(MidiBus.availableInputs());
}

boolean hasUsableMidiOutputs() {
  return hasUsableMidiNames(MidiBus.availableOutputs());
}

boolean hasUsableMidiNames(String[] ports) {
  if (ports == null || ports.length == 0) {
    return false;
  }

  for (int i = 0; i < ports.length; i++) {
    String portName = ports[i];
    if (!isValidMidiPortName(portName)) continue;
    return true;
  }

  return false;
}

boolean isValidMidiPortName(String portName) {
  if (portName == null) return false;
  String trimmed = portName.trim();
  if (trimmed.length() == 0) return false;
  String normalized = trimmed.toLowerCase();
  return normalized.indexOf("real time sequencer") < 0;
}

int findMidiInputIndex(String[] nameHints, int fallbackIndex) {
  String[] inputs = MidiBus.availableInputs();
  if (!hasUsableMidiNames(inputs)) {
    println(NO_VALID_MIDI_DEVICES_MESSAGE);
    return -1;
  }

  int validCount = 0;
  for (int i = 0; i < inputs.length; i++) {
    String inputName = inputs[i];
    if (!isValidMidiPortName(inputName)) continue;
    String normalized = inputName.trim().toLowerCase();
    validCount++;
    for (int hintIndex = 0; hintIndex < nameHints.length; hintIndex++) {
      String hint = nameHints[hintIndex];
      if (hint == null) continue;
      if (normalized.indexOf(hint.toLowerCase()) >= 0) {
        return i;
      }
    }
  }

  if (fallbackIndex >= 0 && fallbackIndex < inputs.length) {
    String fallbackName = inputs[fallbackIndex];
    if (isValidMidiPortName(fallbackName)) {
      return fallbackIndex;
    }
  }

  if (validCount == 0) {
    println("No usable MIDI input ports detected (only Java's \"Real Time Sequencer\"). Create a virtual loopback port (IAC on macOS, loopMIDI on Windows).");
  }
  return -1;
}

int findMidiOutputIndex(String[] nameHints, int fallbackIndex) {
  String[] outputs = MidiBus.availableOutputs();
  if (!hasUsableMidiNames(outputs)) {
    println(NO_VALID_MIDI_DEVICES_MESSAGE);
    return -1;
  }

  int validCount = 0;
  for (int i = 0; i < outputs.length; i++) {
    String outputName = outputs[i];
    if (!isValidMidiPortName(outputName)) continue;
    String normalized = outputName.trim().toLowerCase();
    validCount++;
    for (int hintIndex = 0; hintIndex < nameHints.length; hintIndex++) {
      String hint = nameHints[hintIndex];
      if (hint == null) continue;
      if (normalized.indexOf(hint.toLowerCase()) >= 0) {
        return i;
      }
    }
  }

  if (fallbackIndex >= 0 && fallbackIndex < outputs.length) {
    String fallbackName = outputs[fallbackIndex];
    if (isValidMidiPortName(fallbackName)) {
      return fallbackIndex;
    }
  }

  if (validCount == 0) {
    println("No usable MIDI output ports detected (only Java's \"Real Time Sequencer\"). Create a virtual loopback port (IAC on macOS, loopMIDI on Windows).");
  }
  return -1;
}
