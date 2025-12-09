import themidibus.*;

MidiBus midiBus;

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
  midiBus = new MidiBus(this, 0, -1);   // adjust input index to your MIDI clock source
}

void draw() {
  background(0);
  fill(255);
  text("MIDI Clock Monitor", 10, 10);
  text("Beat: " + beatCountMon, 10, 40);
  text("BPM:  " + nf(bpmMon, 0, 2), 10, 70);
  text("Watch console for detailed logs.", 10, 110);
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
