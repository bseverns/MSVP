import themidibus.*;

MidiBus midiOut;
boolean midiReady = false;
boolean midiInitFailed = false;
String midiStatusMessage = "";

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
  if (midiOutputIndex == -1) {
    midiReady = false;
    midiStatusMessage = "MIDI ERROR: no safe output found (\"Real Time Sequencer\" is ignored).";
  } else {
    try {
      midiOut = new MidiBus(this, -1, midiOutputIndex);
      midiReady = true;
    } catch (Throwable e) {
      midiOut = null;
      midiReady = false;
      midiInitFailed = true;
      midiStatusMessage = "MIDI ERROR: output init failed. Check console and device list.";
      println("MIDI init failed. TheMidiBus can throw a NullPointerException when the selected");
      println("device is not a real MIDI port (e.g. Java's \"Real Time Sequencer\") or when no");
      println("virtual loopback device is installed.");
      println("Fix: install a virtual MIDI port (IAC on macOS, loopMIDI on Windows) or choose a");
      println("hardware device index from MidiBus.list(), then update the indices above.");
      e.printStackTrace();
    }
  }

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
    if (midiStatusMessage != null && !midiStatusMessage.equals("")) {
      text(midiStatusMessage, 10, 140);
    }
    if (midiInitFailed) {
      text("MIDI init failed; see console", 10, 160);
    }
  }

  if (midiReady) {
    long now = millis();
    if (now - lastTickMs >= msPerTick) {
      sendClockTick();
      lastTickMs += (long)msPerTick;
    }

    sendCCLFO();
  }
}

void computeMsPerTick() {
  float msPerBeat = 60000.0 / bpm;
  msPerTick = msPerBeat / ticksPerBeatSim;
}

void sendClockTick() {
  if (!midiReady || midiOut == null) return;
  byte[] msg = new byte[1];
  msg[0] = (byte)0xF8;  // MIDI Clock
  midiOut.sendMessage(msg);
}

void sendCCLFO() {
  if (!midiReady || midiOut == null) return;

  float t = millis() / 1000.0;
  float lfo = 0.5 + 0.5 * sin(TWO_PI * lfoSpeed * t);
  int value = int(lfo * 127.0);
  midiOut.sendControllerChange(channel, ccNumber, value);
}
