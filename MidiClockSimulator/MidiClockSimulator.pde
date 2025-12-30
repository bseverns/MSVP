import themidibus.*;
import javax.sound.midi.*;

MidiBus midiOut;
boolean midiReady = false;
boolean midiInitFailed = false;
boolean midiDeviceListsEmpty = false;
String midiStatusMessage = "";
MidiDevice midiClockDevice;
Receiver midiClockReceiver;
boolean midiClockReady = false;
boolean midiClockInitFailed = false;
String midiClockStatusMessage = "";

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
  // Validate both input + output lists before we even attempt MidiBus init.
  if (!hasNonEmptyMidiDeviceLists()) {
    midiReady = false;
    midiDeviceListsEmpty = true;
    midiStatusMessage = NO_VALID_MIDI_DEVICES_MESSAGE;
  }
  if (!midiDeviceListsEmpty) {
  // Choose correct MIDI output index (virtual loopback, or hardware/DAW input)
  // Example: midiOut = new MidiBus(this, -1, 0);  // out: device #0
  int[] midiOutputCandidates = buildMidiOutputCandidates(new String[] { "Bus 1", "IAC" }, 1); // fallback: console index for IAC/Bus 1
  if (midiOutputCandidates.length == 0) {
    midiReady = false;
    midiStatusMessage = "MIDI WARNING: no safe output found (\"Real Time Sequencer\" is ignored).";
  } else {
    boolean midiInitialized = false;
    String selectedOutputLabel = null;
    String[] outputs = MidiBus.availableOutputs();
    for (int i = 0; i < midiOutputCandidates.length; i++) {
      int midiOutputIndex = midiOutputCandidates[i];
      String outputLabel = (outputs != null && midiOutputIndex >= 0 && midiOutputIndex < outputs.length)
        ? outputs[midiOutputIndex]
        : ("index " + midiOutputIndex);
      try {
        midiOut = new MidiBus(this, -1, midiOutputIndex);
        midiReady = true;
        midiInitialized = true;
        selectedOutputLabel = outputLabel;
        break;
      } catch (Throwable e) {
        println("MIDI init failed for output " + outputLabel + ".");
        println("MIDI init failed. TheMidiBus can throw a NullPointerException when the selected");
        println("device is not a real MIDI port (e.g. Java's \"Real Time Sequencer\") or when no");
        println("virtual loopback device is installed.");
        println("Fix: install a virtual MIDI port (IAC on macOS, loopMIDI on Windows) or choose a");
        println("hardware device index from MidiBus.list(), then update the indices above.");
        e.printStackTrace();
      }
    }

    if (!midiInitialized) {
      midiOut = null;
      midiReady = false;
      midiInitFailed = true;
      midiStatusMessage = "MIDI ERROR: output init failed. Check console and device list.";
      return;
    }
    midiClockReady = initMidiClockReceiver(selectedOutputLabel);
    if (!midiClockReady) {
      midiClockInitFailed = true;
      midiClockStatusMessage = "MIDI WARNING: clock output init failed; CCs still send.";
    }
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
  if (midiReady && !midiClockReady) {
    text("MIDI Clock: not sending (see console)", 10, 110);
    if (midiClockStatusMessage != null && !midiClockStatusMessage.equals("")) {
      text(midiClockStatusMessage, 10, 130);
    }
  }
  if (midiDeviceListsEmpty) {
    drawNoValidMidiBanner();
  }
  if (midiInitFailed) {
    drawMidiInitFailedBanner();
  }
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

void drawNoValidMidiBanner() {
  // Loud banner so you don't miss that there are zero usable MIDI ports.
  pushStyle();
  fill(160, 0, 0);
  noStroke();
  rect(0, 0, width, 28);
  fill(255);
  textAlign(LEFT, TOP);
  textSize(14);
  String bannerMessage = midiDeviceListsEmpty
    ? NO_VALID_MIDI_DEVICES_MESSAGE
    : "No valid MIDI ports detected";
  text(bannerMessage, 10, 6);
  popStyle();
}

void drawMidiInitFailedBanner() {
  // Big red heads-up: the MIDI init threw, so the sim is idling on purpose.
  pushStyle();
  fill(180, 40, 0);
  noStroke();
  rect(0, 28, width, 28);
  fill(255);
  textAlign(LEFT, TOP);
  textSize(14);
  text("MIDI init failed (see console)", 10, 34);
  popStyle();
}

void computeMsPerTick() {
  float msPerBeat = 60000.0 / bpm;
  msPerTick = msPerBeat / ticksPerBeatSim;
}

void sendClockTick() {
  if (!midiReady) return;
  if (!midiClockReady || midiClockReceiver == null) return;
  try {
    ShortMessage clock = new ShortMessage();
    clock.setMessage(ShortMessage.TIMING_CLOCK);
    midiClockReceiver.send(clock, -1);
  } catch (InvalidMidiDataException e) {
    println("MIDI clock send failed: invalid data for timing clock.");
    e.printStackTrace();
    midiClockReady = false;
    midiClockInitFailed = true;
    midiClockStatusMessage = "MIDI WARNING: clock send failed; disabling clock.";
  } catch (IllegalStateException e) {
    println("MIDI clock send failed: receiver closed.");
    e.printStackTrace();
    midiClockReady = false;
    midiClockInitFailed = true;
    midiClockStatusMessage = "MIDI WARNING: clock receiver closed; disabling clock.";
  }
}

void sendCCLFO() {
  if (!midiReady || midiOut == null) return;

  float t = millis() / 1000.0;
  float lfo = 0.5 + 0.5 * sin(TWO_PI * lfoSpeed * t);
  int value = int(lfo * 127.0);
  midiOut.sendControllerChange(channel, ccNumber, value);
}

boolean initMidiClockReceiver(String outputLabel) {
  if (outputLabel == null) {
    println("MIDI WARNING: clock receiver init skipped (no output label).");
    return false;
  }
  String trimmedLabel = outputLabel.trim();
  if (trimmedLabel.length() == 0) {
    println("MIDI WARNING: clock receiver init skipped (blank output label).");
    return false;
  }
  String normalizedLabel = trimmedLabel.toLowerCase();
  MidiDevice.Info[] infos = MidiSystem.getMidiDeviceInfo();
  for (int i = 0; i < infos.length; i++) {
    MidiDevice.Info info = infos[i];
    if (!midiDeviceMatchesLabel(info, normalizedLabel)) {
      continue;
    }
    try {
      MidiDevice device = MidiSystem.getMidiDevice(info);
      if (device.getMaxReceivers() == 0) {
        continue;
      }
      device.open();
      Receiver receiver = device.getReceiver();
      midiClockDevice = device;
      midiClockReceiver = receiver;
      println("MIDI clock receiver opened on \"" + outputLabel + "\".");
      return true;
    } catch (MidiUnavailableException e) {
      println("MIDI WARNING: clock receiver init failed for \"" + outputLabel + "\".");
      e.printStackTrace();
    }
  }
  println("MIDI WARNING: no clock-capable receiver found for \"" + outputLabel + "\".");
  return false;
}

boolean midiDeviceMatchesLabel(MidiDevice.Info info, String normalizedLabel) {
  if (info == null) return false;
  String name = info.getName();
  String description = info.getDescription();
  String combined = ((name == null ? "" : name) + " " + (description == null ? "" : description)).trim();
  if (combined.length() == 0) return false;
  String normalizedCombined = combined.toLowerCase();
  if (normalizedCombined.indexOf(normalizedLabel) >= 0) return true;
  if (normalizedLabel.indexOf(normalizedCombined) >= 0) return true;
  if (name != null && name.toLowerCase().indexOf(normalizedLabel) >= 0) return true;
  return false;
}

void dispose() {
  closeMidiClockReceiver();
}

void closeMidiClockReceiver() {
  if (midiClockReceiver != null) {
    midiClockReceiver.close();
    midiClockReceiver = null;
  }
  if (midiClockDevice != null && midiClockDevice.isOpen()) {
    midiClockDevice.close();
    midiClockDevice = null;
  }
}
