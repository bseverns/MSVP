import processing.video.*;
import codeanticode.syphon.*;
import themidibus.*;

Movie video;
SyphonServer syphonServer;
MidiBus midiBus;
boolean midiReady = false;
boolean midiInitFailed = false;
boolean midiDeviceListsEmpty = false;
String midiStatusMessage = "";

int currentLineSize;
float currentStrokeWeight;
int currentOpacity;

boolean effectActive = false;
String effectType = "lines";      // "lines" or "rotate"
long effectStartBeat = 0;

float bpm = 100.0;
float videoSpeed = 1.0;

// MIDI clock → BPM
int   ticksPerBeat = 24;
int   tickCounter  = 0;
long  lastBeatTimeMs = -1;
long  beatCount = 0;
long  lastBeatSeenInDraw = -1;

// Effect type bias (via CC7)
// -1 → always lines, 0 → alternate, +1 → always rotate
int effectBias = 0;

void setup() {
  size(1000, 750, P3D);
  noSmooth();

  loadDefaultConfig();  // from Config.pde

  syphonServer = new SyphonServer(this, "MidiVideoSyphonBeats");

  // Put your video file in ./data/
  video = new Movie(this, "video.mp4");
  video.loop();
  video.play();

  // Choose correct MIDI input index after checking MidiBus.list() in console
  MidiBus.list();
  // Validate inputs before we even attempt MidiBus init.
  if (!hasUsableMidiInputs()) {
    midiReady = false;
    midiDeviceListsEmpty = true;
    midiStatusMessage = NO_VALID_MIDI_DEVICES_MESSAGE;
  }
  if (!midiDeviceListsEmpty) {
    int midiInputIndex = findMidiInputIndex(new String[] { "Bus 1", "IAC" }, 1); // fallback: console index for IAC/Bus 1
    if (midiInputIndex == -1) {
      midiReady = false;
      midiInitFailed = true;
      midiStatusMessage = "MIDI ERROR: no safe input found (\"Real Time Sequencer\" is ignored).";
    } else {
      midiBus = safeMidiBus(midiInputIndex, -1);
      if (midiBus == null) {
        midiReady = false;
        midiInitFailed = true;
        midiStatusMessage = "MIDI ERROR: input init failed. Check console and device list.";
      } else {
        midiReady = true;
      }
    }
  }

  updateLineProperties();
}

void draw() {
  background(0);

  if (!midiReady) {
    // MIDI isn't online yet: keep the window alive, stay black, show HUD text,
    // and skip every video/effect touchpoint so nothing tries to read null pixels.
    drawHud();
    if (midiDeviceListsEmpty) {
      drawNoValidMidiBanner();
    }
    if (midiInitFailed) {
      drawMidiInitFailedOverlay();
    }
    syphonServer.sendScreen();
    return;
  }

  if (video.width == 0 || video.height == 0) {
    return;
  }

  // 100 BPM → speed 1.0
  videoSpeed = bpm / 100.0;
  video.speed(videoSpeed);

  // Beat-quantized logic, run once per beat
  if (beatCount != lastBeatSeenInDraw) {
    onBeat();
    lastBeatSeenInDraw = beatCount;
  }

  if (effectActive) {
    if (effectType.equals("lines")) {
      image(video, 0, 0, width, height);

      if (frameCount % 10 == 0) {
        updateLineProperties();
      }

      for (int i = 0; i < linesPerFrame; i++) {
        drawVariableLine();
      }

    } else if (effectType.equals("rotate")) {
      PImage frameCopy = video.get();
      rotateImage(frameCopy);
      image(frameCopy, 0, 0, width, height);
    }

  } else {
    image(video, 0, 0, width, height);
  }

  syphonServer.sendScreen();
  drawHud();
}

void onBeat() {
  // Start new effect window based on config + bias
  if (!effectActive && beatCount > 0 && beatCount % effectIntervalBeats == 0) {
    effectActive = true;
    effectStartBeat = beatCount;

    if (effectBias < 0) {
      effectType = "lines";
    } else if (effectBias > 0) {
      effectType = "rotate";
    } else {
      effectType = effectType.equals("lines") ? "rotate" : "lines";
    }
  }

  // End current effect window
  if (effectActive && beatCount - effectStartBeat >= effectDurationBeats) {
    effectActive = false;
  }
}

void drawVariableLine() {
  int vw = video.width;
  int vh = video.height;
  if (vw == 0 || vh == 0) return;

  int x = int(random(vw));
  int y = int(random(vh));

  color pixelColor = video.get(x, y);
  currentOpacity = int(random(opacityMin, opacityMax + 1));
  pixelColor = color(red(pixelColor), green(pixelColor), blue(pixelColor), currentOpacity);
  stroke(pixelColor);

  strokeWeight(currentStrokeWeight);
  int lineSize = currentLineSize;

  float r = random(1);

  if (r < 0.25) {
    float angle = random(-PI / 8, PI / 8);
    float x1 = x - lineSize / 2.0 * cos(angle);
    float y1 = y - lineSize / 2.0 * sin(angle);
    float x2 = x + lineSize / 2.0 * cos(angle);
    float y2 = y + lineSize / 2.0 * sin(angle);
    line(x1, y1, x2, y2);

  } else if (r < 0.5) {
    float angle = random(-PI / 8, PI / 8);
    float x1 = x - lineSize / 2.0 * sin(angle);
    float y1 = y - lineSize / 2.0 * cos(angle);
    float x2 = x + lineSize / 2.0 * sin(angle);
    float y2 = y + lineSize / 2.0 * cos(angle);
    line(x1, y1, x2, y2);

  } else if (r < 0.75) {
    line(x - lineSize / 2.0, y - lineSize / 2.0,
         x + lineSize / 2.0, y + lineSize / 2.0);

  } else {
    line(x - lineSize / 2.0, y + lineSize / 2.0,
         x + lineSize / 2.0, y - lineSize / 2.0);
  }
}

void rotateImage(PImage img) {
  int layers = min(img.width, img.height) / 2;

  for (int layer = 0; layer < layers; layer++) {
    color prevColor = img.get(layer, layer);

    for (int column = layer + 1; column < img.width - layer; column++) {
      color nextColor = img.get(column, layer);
      img.set(column, layer, prevColor);
      prevColor = nextColor;
    }

    for (int row = layer + 1; row < img.height - layer; row++) {
      color nextColor = img.get(img.width - layer - 1, row);
      img.set(img.width - layer - 1, row, prevColor);
      prevColor = nextColor;
    }

    for (int column = img.width - layer - 2; column >= layer; column--) {
      color nextColor = img.get(column, img.height - layer - 1);
      img.set(column, img.height - layer - 1, prevColor);
      prevColor = nextColor;
    }

    for (int row = img.height - layer - 2; row >= layer; row--) {
      color nextColor = img.get(layer, row);
      img.set(layer, row, prevColor);
      prevColor = nextColor;
    }
  }
}

void updateLineProperties() {
  currentLineSize = int(random(10, maxLineSize));
  currentStrokeWeight = random(1, 5);
}

void drawHud() {
  // HUD
  fill(255);
  textSize(14);
  text("BPM: " + nf(bpm, 0, 1), 10, 20);
  text("Beat: " + beatCount, 10, 40);
  text("Effect: " + effectType + (effectActive ? " (ON)" : " (OFF)"), 10, 60);
  text("Lines/frame: " + linesPerFrame, 10, 80);
  text("IntervalBeats: " + effectIntervalBeats + "  DurationBeats: " + effectDurationBeats, 10, 100);
  if (!midiReady) {
    text("MIDI: not connected (see console)", 10, 120);
    if (midiStatusMessage != null && !midiStatusMessage.equals("")) {
      text(midiStatusMessage, 10, 140);
    }
  }
}

void drawNoValidMidiBanner() {
  // Loud banner so you don't miss that there are zero usable MIDI ports.
  pushStyle();
  fill(160, 0, 0, 220);
  noStroke();
  rect(0, 0, width, 36);
  fill(255);
  textAlign(LEFT, TOP);
  textSize(18);
  String bannerMessage = midiDeviceListsEmpty
    ? NO_VALID_MIDI_DEVICES_MESSAGE
    : "No valid MIDI ports detected";
  text(bannerMessage, 14, 8);
  popStyle();
}

void drawMidiMissingOverlay() {
  // Loud overlay so you can spot the missing MIDI at a glance.
  pushStyle();
  fill(0, 180);
  noStroke();
  rect(0, 0, width, height);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(36);
  text("No MIDI port; check console", width / 2.0, height / 2.0);
  popStyle();
}

void drawMidiInitFailedOverlay() {
  // MIDI init exploded; keep the message loud and unmissable.
  pushStyle();
  fill(120, 0, 0, 200);
  noStroke();
  rect(0, 0, width, height);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(36);
  text("MIDI init failed; see console", width / 2.0, height / 2.0);
  popStyle();
}

// Video frames
void movieEvent(Movie m) {
  m.read();
}

// MIDI clock → BPM + beatCount
void rawMidi(byte[] data) {
  if (!midiReady) return;
  if (data == null || data.length == 0) return;

  int status = data[0] & 0xFF;

  if (status == 0xF8) {  // MIDI Clock tick
    tickCounter++;

    if (tickCounter >= ticksPerBeat) {
      long now = millis();
      beatCount++;

      if (lastBeatTimeMs >= 0) {
        float deltaMs = now - lastBeatTimeMs;
        if (deltaMs > 0) {
          float instantBpm = 60000.0 / deltaMs;
          bpm = lerp(bpm, instantBpm, bpmSmoothing);
        }
      }
      lastBeatTimeMs = now;
      tickCounter = 0;
    }
  }
}

// Generic MIDI CC mappings (any channel)
void controllerChange(int channel, int number, int value) {
  if (!midiReady) return;
  if (number == 1) {  // CC1: line density
    linesPerFrame = int(map(value, 0, 127,
                            CFG_LINES_PER_FRAME_MIN,
                            CFG_LINES_PER_FRAME_MAX));

  } else if (number == 2) {  // CC2: max line size
    maxLineSize = int(map(value, 0, 127,
                          CFG_MAX_LINE_SIZE_MIN,
                          CFG_MAX_LINE_SIZE_MAX));

  } else if (number == 3) {  // CC3: opacityMin
    opacityMin = int(map(value, 0, 127,
                         CFG_OPACITY_MIN_MIN,
                         CFG_OPACITY_MIN_MAX));
    if (opacityMin > opacityMax) opacityMin = opacityMax;

  } else if (number == 4) {   // CC4: effect interval (beats)
    effectIntervalBeats = int(map(value, 0, 127,
                                  CFG_EFFECT_INTERVAL_MIN,
                                  CFG_EFFECT_INTERVAL_MAX));
    effectIntervalBeats = max(effectIntervalBeats, 1);

  } else if (number == 5) {   // CC5: effect duration (beats)
    effectDurationBeats = int(map(value, 0, 127,
                                  CFG_EFFECT_DURATION_MIN,
                                  CFG_EFFECT_DURATION_MAX));
    effectDurationBeats = max(effectDurationBeats, 1);

  } else if (number == 6) {   // CC6: BPM smoothing
    bpmSmoothing = map(value, 0, 127,
                       CFG_BPM_SMOOTHING_MIN,
                       CFG_BPM_SMOOTHING_MAX);

  } else if (number == 7) {   // CC7: effect bias
    if (value < 42) {
      effectBias = -1;   // lines only
    } else if (value > 84) {
      effectBias = 1;    // rotate only
    } else {
      effectBias = 0;    // alternate
    }
  }
}

// Optional note mapping hooks
void noteOn(int channel, int pitch, int velocity) {
  if (!midiReady) return;
  // Example: pad to reset config
  // if (pitch == 36 && velocity > 0) loadDefaultConfig();
}
