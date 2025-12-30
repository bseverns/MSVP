import themidibus.*;

MidiBus midiBus;
boolean midiReady = false;
boolean midiInitFailed = false;
boolean midiDeviceListsEmpty = false;
String midiStatusMessage = "";

int   ticksPerBeatMon   = 24;
int   tickCounterMon    = 0;
long  lastBeatTimeMsMon = -1;
long  beatCountMon      = 0;
float bpmMon            = 0;
float bpmSmoothMon      = 0.3;

void setup() {
  size(400, 200);
  background(0);
  fill(255);
  textSize(16);
  textAlign(LEFT, TOP);

  MidiBus.list();
  // Validate both input + output lists before we even attempt MidiBus init.
  if (!hasNonEmptyMidiDeviceLists()) {
    midiReady = false;
    midiDeviceListsEmpty = true;
    midiStatusMessage = NO_VALID_MIDI_DEVICES_MESSAGE;
    return;
  }
  int midiInputIndex = findMidiInputIndex(new String[] { "Bus 1", "IAC" }, 1); // fallback: console index for IAC/Bus 1
  if (midiInputIndex == -1) {
    midiReady = false;
    midiStatusMessage = "MIDI ERROR: no safe input found (\"Real Time Sequencer\" is ignored).";
  } else {
    try {
      midiBus = new MidiBus(this, midiInputIndex, -1);
      midiReady = true;
    } catch (Throwable e) {
      midiBus = null;
      midiReady = false;
      midiInitFailed = true;
      midiStatusMessage = "MIDI ERROR: input init failed. Check console and device list.";
      println("MIDI init failed. TheMidiBus can throw a NullPointerException when the selected");
      println("device is not a real MIDI port (e.g. Java's \"Real Time Sequencer\") or when no");
      println("virtual loopback device is installed.");
      println("Fix: install a virtual MIDI port (IAC on macOS, loopMIDI on Windows) or choose a");
      println("hardware device index from MidiBus.list(), then update the indices above.");
      e.printStackTrace();
      return;
    }
  }
}

void draw() {
  background(0);
  fill(255);
  text("MIDI Clock Monitor", 10, 10);
  text("Beat: " + beatCountMon, 10, 40);
  text("BPM:  " + nf(bpmMon, 0, 2), 10, 70);
  text("Watch console for detailed logs.", 10, 110);
  if (midiDeviceListsEmpty) {
    drawNoValidMidiBanner();
  }
  if (midiInitFailed) {
    drawMidiInitFailedBanner();
  }
  if (!midiReady) {
    text("MIDI: not connected (see console)", 10, 140);
    if (midiStatusMessage != null && !midiStatusMessage.equals("")) {
      text(midiStatusMessage, 10, 160);
    }
    if (midiInitFailed) {
      text("MIDI init failed; see console", 10, 180);
    }
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
  // Big red heads-up: the MIDI init threw, so the monitor is idling on purpose.
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

void rawMidi(byte[] data) {
  if (!midiReady) return;
  if (data == null || data.length == 0) return;

  int status = data[0] & 0xFF;

  if (status == 0xF8) {   // MIDI Clock tick
    tickCounterMon++;

    if (tickCounterMon >= ticksPerBeatMon) {
      long now = millis();
      beatCountMon++;

      if (lastBeatTimeMsMon >= 0) {
        float deltaMs = now - lastBeatTimeMsMon;
        if (deltaMs > 0) {
          float instantBpm = 60000.0 / deltaMs;
          bpmMon = lerp(bpmMon, instantBpm, bpmSmoothMon);
        }
      }

      lastBeatTimeMsMon = now;
      tickCounterMon = 0;

      println("Beat " + beatCountMon + "  BPM: " + bpmMon);
    }
  }
}

void noteOn(int channel, int pitch, int velocity) {
  if (!midiReady) return;
  println("noteOn  ch:" + channel + "  pitch:" + pitch + "  vel:" + velocity);
}

void controllerChange(int channel, int number, int value) {
  if (!midiReady) return;
  println("CC  ch:" + channel + "  num:" + number + "  val:" + value);
}
