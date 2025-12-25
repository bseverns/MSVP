import themidibus.*;

MidiBus midiOut;
boolean midiReady = false;

float bpm = 120.0;      // simulated BPM
int   channel = 0;      // MIDI channel for CCs (0-based: 0 == Ch1)
int   ccNumber = 1;     // CC number to wiggle
float lfoSpeed = 0.25;  // Hz for CC LFO

int   ticksPerBeatSim = 24;
float msPerTick;
long  lastTickMs = 0;

void setup() {
  size(450, 240);
  background(0);
  fill(255);
  textSize(14);
  textAlign(LEFT, TOP);

  computeMsPerTick();

  MidiBus.list();
  // Choose correct MIDI output index (virtual loopback, or hardware/DAW input)
  // Example: midiOut = new MidiBus(this, -1, 0);  // out: device #0
  int midiOutputIndex = findMidiOutputIndex(new String[] { "Bus 1", "IAC" }, 1); // fallback: console index for IAC/Bus 1
  midiOut = safeMidiBus(-1, midiOutputIndex);
  midiReady = (midiOut != null);

  lastTickMs = millis();
}

void draw() {
  background(0);
  fill(255);
  text("MidiClockSimulator", 10, 10);
  text("BPM: " + bpm, 10, 30);
  text("Ticks per beat: " + ticksPerBeatSim, 10, 50);
  text("Sending MIDI Clock + CC on channel " + (channel + 1), 10, 70);
  text("Output device index is set in setup()", 10, 90);
  if (!midiReady) {
    text("MIDI: not connected (see console)", 10, 120);
  }

  long now = millis();
  if (now - lastTickMs >= msPerTick) {
    sendClockTick();
    lastTickMs += (long)msPerTick;
  }

  sendCCLFO();
}

void computeMsPerTick() {
  float msPerBeat = 60000.0 / bpm;
  msPerTick = msPerBeat / ticksPerBeatSim;
}

void sendClockTick() {
  if (midiOut == null) return;
  byte[] msg = new byte[1];
  msg[0] = (byte)0xF8;  // MIDI Clock
  midiOut.sendMessage(msg);
}

void sendCCLFO() {
  if (midiOut == null) return;

  float t = millis() / 1000.0;
  float lfo = 0.5 + 0.5 * sin(TWO_PI * lfoSpeed * t);
  int value = int(lfo * 127.0);
  midiOut.sendControllerChange(channel, ccNumber, value);
}

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
