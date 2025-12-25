import themidibus.*;

MidiBus midiBus;
boolean midiReady = false;

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
  int midiInputIndex = findMidiInputIndex(new String[] { "Bus 1", "IAC" }, 1); // fallback: console index for IAC/Bus 1
  midiBus = safeMidiBus(midiInputIndex, -1);
  midiReady = (midiBus != null);
}

void draw() {
  background(0);
  fill(255);
  text("MIDI Clock Monitor", 10, 10);
  text("Beat: " + beatCountMon, 10, 40);
  text("BPM:  " + nf(bpmMon, 0, 2), 10, 70);
  text("Watch console for detailed logs.", 10, 110);
  if (!midiReady) {
    text("MIDI: not connected (see console)", 10, 140);
  }
}

void rawMidi(byte[] data) {
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
  println("noteOn  ch:" + channel + "  pitch:" + pitch + "  vel:" + velocity);
}

void controllerChange(int channel, int number, int value) {
  println("CC  ch:" + channel + "  num:" + number + "  val:" + value);
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
