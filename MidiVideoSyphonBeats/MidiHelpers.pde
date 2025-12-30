// Shared MIDI setup helpers.
//
// This file is intentionally duplicated across sketches so Processing auto-loads it.
// If you change logic here, copy the same edits into the other MidiHelpers.pde files
// to keep every sketch behaving identically.

final String NO_VALID_MIDI_DEVICES_MESSAGE = "No valid MIDI devices detected (Rosetta/MIDI bug?)";

MidiBus safeMidiBus(int inputIndex, int outputIndex) {
  try {
    if (!hasNonEmptyMidiDeviceLists()) {
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

boolean hasNonEmptyMidiDeviceLists() {
  String[] inputs = MidiBus.availableInputs();
  String[] outputs = MidiBus.availableOutputs();
  boolean inputsHaveNames = hasNonEmptyMidiNames(inputs);
  boolean outputsHaveNames = hasNonEmptyMidiNames(outputs);
  if (!inputsHaveNames || !outputsHaveNames) {
    println(NO_VALID_MIDI_DEVICES_MESSAGE);
    return false;
  }
  return true;
}

boolean hasNonEmptyMidiNames(String[] ports) {
  if (ports == null || ports.length == 0) {
    return false;
  }

  for (int i = 0; i < ports.length; i++) {
    String portName = ports[i];
    if (portName == null) continue;
    String trimmed = portName.trim();
    if (trimmed.length() == 0) continue;
    return true;
  }

  return false;
}

int findMidiInputIndex(String[] nameHints, int fallbackIndex) {
  String[] inputs = MidiBus.availableInputs();
  if (!hasNonEmptyMidiNames(inputs)) {
    println(NO_VALID_MIDI_DEVICES_MESSAGE);
    return -1;
  }

  int validCount = 0;
  for (int i = 0; i < inputs.length; i++) {
    String inputName = inputs[i];
    if (inputName == null) continue;
    String trimmed = inputName.trim();
    if (trimmed.length() == 0) continue;
    String normalized = trimmed.toLowerCase();
    if (normalized.indexOf("real time sequencer") >= 0) {
      continue;
    }
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
    if (fallbackName != null) {
      String trimmed = fallbackName.trim();
      if (trimmed.length() > 0) {
        String normalized = trimmed.toLowerCase();
        if (normalized.indexOf("real time sequencer") < 0) {
          return fallbackIndex;
        }
      }
    }
  }

  if (validCount == 0) {
    println("No valid MIDI ports detected. Install IAC/loopMIDI.");
  }
  return -1;
}

int findMidiOutputIndex(String[] nameHints, int fallbackIndex) {
  String[] outputs = MidiBus.availableOutputs();
  if (!hasNonEmptyMidiNames(outputs)) {
    println(NO_VALID_MIDI_DEVICES_MESSAGE);
    return -1;
  }

  int validCount = 0;
  for (int i = 0; i < outputs.length; i++) {
    String outputName = outputs[i];
    if (outputName == null) continue;
    String trimmed = outputName.trim();
    if (trimmed.length() == 0) continue;
    String normalized = trimmed.toLowerCase();
    if (normalized.indexOf("real time sequencer") >= 0) {
      continue;
    }
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
    if (fallbackName != null) {
      String trimmed = fallbackName.trim();
      if (trimmed.length() > 0) {
        String normalized = trimmed.toLowerCase();
        if (normalized.indexOf("real time sequencer") < 0) {
          return fallbackIndex;
        }
      }
    }
  }

  if (validCount == 0) {
    println("No valid MIDI ports detected. Install IAC/loopMIDI.");
  }
  return -1;
}
