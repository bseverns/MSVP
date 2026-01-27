import processing.video.*;
import codeanticode.syphon.*;
import themidibus.*;
import oscP5.*;
import netP5.*;

Movie video;
SyphonServer syphonServer;
MidiBus midiBus;
boolean midiReady = false;
boolean midiInitFailed = false;
boolean midiDeviceListsEmpty = false;
String midiStatusMessage = "";
String midiSelectedInputName = "";
boolean midiInputFromInterop = false;
boolean showStatusOverlay = true;
int lastCcChannel = -1;
int lastCcNumber = -1;
int lastCcValue = -1;
int stateOscIntervalMs = 100;
long lastStateOscMs = -1;
long lastStateBeat = -1;

OscP5 oscP5;
NetAddress oscTarget;
int oscListenPort;
String oscTargetHost;
int oscTargetPort;

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
boolean isPlaying = true;
boolean transportStale = false;
long  lastTickTimeMs = -1;
int   clockDropoutMs = 750;

// Effect type bias (via CC7)
// -1 → always lines, 0 → alternate, +1 → always rotate
int effectBias = 0;

void setup() {
  size(1000, 750, P3D);
  noSmooth();

  loadDefaultConfig();  // from Config.pde
  loadInteropConfig();  // from Interop.pde
  configureRigModeFromInterop();  // from RigMapping.pde
  initPresets(); // from Presets.pde
  initOsc(); // from below

  syphonServer = new SyphonServer(this, "MidiVideoSyphonBeats");

  // Put your video file in ./data/
  video = new Movie(this, "video.mp4");
  video.loop();
  video.play();

  // Choose correct MIDI input index after checking MidiBus.list() in console
  MidiBus.list();
  // Validate both input + output lists before we even attempt MidiBus init.
  if (!hasNonEmptyMidiDeviceLists()) {
    midiReady = false;
    midiDeviceListsEmpty = true;
    midiStatusMessage = NO_VALID_MIDI_DEVICES_MESSAGE;
    printInteropStatus("none");
  }
  if (!midiDeviceListsEmpty) {
    String[] nameHints = (interopPreferredInputName != null && interopPreferredInputName.length() > 0)
      ? new String[] { interopPreferredInputName }
      : new String[] { "Bus 1", "IAC" };
    int fallbackIndex = (interopPreferredInputName != null && interopPreferredInputName.length() > 0) ? -1 : 1;
    int[] midiInputCandidates = buildMidiInputCandidates(nameHints, fallbackIndex);
    if (midiInputCandidates.length == 0) {
      printNoUsableMidiInputPorts();
      midiReady = false;
      midiInitFailed = true;
      midiStatusMessage = "MIDI ERROR: no usable input found (\"Real Time Sequencer\" is ignored).";
      printInteropStatus("none");
    } else {
      boolean midiInitialized = false;
      String[] inputs = MidiBus.availableInputs();
      for (int i = 0; i < midiInputCandidates.length; i++) {
        int midiInputIndex = midiInputCandidates[i];
        String inputLabel = (inputs != null && midiInputIndex >= 0 && midiInputIndex < inputs.length)
          ? inputs[midiInputIndex]
          : ("index " + midiInputIndex);
        try {
          midiBus = new MidiBus(this, midiInputIndex, -1);
          midiReady = true;
          midiInitialized = true;
          midiSelectedInputName = inputLabel;
          midiInputFromInterop = isInteropSelectedInput(midiSelectedInputName);
          printInteropStatus(midiSelectedInputName);
          break;
        } catch (Throwable e) {
          println("MIDI init failed for input " + inputLabel + ".");
          println("MIDI init failed. TheMidiBus can throw a NullPointerException when the selected");
          println("device is not a real MIDI port (e.g. Java's \"Real Time Sequencer\") or when no");
          println("virtual loopback device is installed.");
          println("Fix: install a virtual MIDI port (IAC on macOS, loopMIDI on Windows) or choose a");
          println("hardware device index from MidiBus.list(), then update the indices above.");
          e.printStackTrace();
        }
      }

      if (!midiInitialized) {
        midiBus = null;
        midiReady = false;
        midiInitFailed = true;
        midiStatusMessage = "MIDI ERROR: input init failed. Check console and device list.";
        printInteropStatus("none");
        return;
      }
    }
  }

  updateLineProperties();
}

void initOsc() {
  oscListenPort = interopOscListenPort > 0 ? interopOscListenPort : CFG_OSC_LISTEN_PORT;
  oscTargetHost = interopOscTargetHost != null && interopOscTargetHost.length() > 0
    ? interopOscTargetHost
    : CFG_OSC_TARGET_HOST;
  oscTargetPort = interopOscTargetPort > 0 ? interopOscTargetPort : CFG_OSC_TARGET_PORT;
  oscP5 = new OscP5(this, oscListenPort);
  oscTarget = new NetAddress(oscTargetHost, oscTargetPort);
  println("OSC listen: " + oscListenPort + " -> target " + oscTargetHost + ":" + oscTargetPort);
}

void draw() {
  background(0);

  if (isPlaying && lastTickTimeMs >= 0) {
    long now = millis();
    if (now - lastTickTimeMs > clockDropoutMs) {
      transportStale = true;
    }
  }

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
    broadcastStateIfNeeded();
    return;
  }

  if (blackoutActive) {
    syphonServer.sendScreen();
    drawHud();
    broadcastStateIfNeeded();
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
  broadcastStateIfNeeded();
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

  broadcastStateNow();
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
  if (!showStatusOverlay) {
    return;
  }
  // HUD
  fill(255);
  textSize(14);
  text("BPM: " + nf(bpm, 0, 1), 10, 20);
  text("Beat: " + beatCount, 10, 40);
  text("Effect: " + effectType + (effectActive ? " (ON)" : " (OFF)"), 10, 60);
  text("Lines/frame: " + linesPerFrame, 10, 80);
  text("IntervalBeats: " + effectIntervalBeats + "  DurationBeats: " + effectDurationBeats, 10, 100);
  text("Preset: " + activePresetName, 10, 120);
  text("Transport: " + formatTransportStatus(), 10, 140);
  text("MIDI in: " + formatMidiInputStatus(), 10, 160);
  text("Last CC: " + formatLastCc(), 10, 180);
  if (!midiReady) {
    text("MIDI: not connected (see console)", 10, 200);
    if (midiStatusMessage != null && !midiStatusMessage.equals("")) {
      text(midiStatusMessage, 10, 220);
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

  if (status == 0xFA) {  // Start
    tickCounter = 0;
    beatCount = 0;
    lastBeatTimeMs = -1;
    lastTickTimeMs = millis();
    transportStale = false;
    isPlaying = true;
    return;
  } else if (status == 0xFC) {  // Stop
    isPlaying = false;
    return;
  } else if (status == 0xFB) {  // Continue
    isPlaying = true;
    transportStale = false;
    lastTickTimeMs = millis();
    return;
  } else if (status == 0xF2 && data.length >= 3) {  // Song Position Pointer
    int lsb = data[1] & 0x7F;
    int msb = data[2] & 0x7F;
    int songPosition = (msb << 7) | lsb; // in 16th notes
    beatCount = songPosition / 4;
    tickCounter = 0;
    lastBeatTimeMs = -1;
    return;
  }

  if (status == 0xF8) {  // MIDI Clock tick
    lastTickTimeMs = millis();
    transportStale = false;
    if (!isPlaying) return;
    tickCounter++;

    if (tickCounter >= ticksPerBeat) {
      long now = millis();
      beatCount++;

      if (lastBeatTimeMs >= 0) {
        float deltaMs = now - lastBeatTimeMs;
        if (deltaMs > 0 && deltaMs <= clockDropoutMs) {
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
  lastCcChannel = channel;
  lastCcNumber = number;
  lastCcValue = value;
  handleControllerChange(channel, number, value);
}

// Optional note mapping hooks
void noteOn(int channel, int pitch, int velocity) {
  if (!midiReady) return;
  handleSceneNoteOn(channel, pitch, velocity);
  // Example: pad to reset config
  // if (pitch == 36 && velocity > 0) loadDefaultConfig();
}

void noteOff(int channel, int pitch, int velocity) {
  if (!midiReady) return;
  handleSceneNoteOff(channel, pitch);
}

void keyPressed() {
  if (key == '?') {
    showStatusOverlay = !showStatusOverlay;
  }
}

void oscEvent(OscMessage message) {
  if (message == null) return;
  String address = message.addrPattern();
  String args = "";
  int count = message.typetag().length();
  for (int i = 0; i < count; i++) {
    if (args.length() > 0) args += ", ";
    args += message.get(i).toString();
  }
  println("OSC recv " + address + " " + args);

  if (address.startsWith("/msvp/macro/")) {
    if (rigTunedMode && message.typetag().length() >= 1) {
      String param = address.substring("/msvp/macro/".length());
      float value = message.get(0).floatValue();
      setParamNormalized(param, value);
    }
    return;
  } else if (address.startsWith("/msvp/analysis/")) {
    if (rigTunedMode && message.typetag().length() >= 1) {
      String param = address.substring("/msvp/analysis/".length());
      float value = message.get(0).floatValue();
      biasParamNormalized(param, value);
    }
    return;
  }

  if (address.equals("/video/scene/intro")) {
    if (oscMessageIsActive(message)) {
      applyPresetByName("intro");
    } else {
      applyPresetByName("neutral");
    }
    return;
  } else if (address.equals("/video/scene/crash")) {
    if (oscMessageIsActive(message)) {
      applyPresetByName("crash");
    } else {
      applyPresetByName("neutral");
    }
    return;
  } else if (address.equals("/video/scene/soft")) {
    if (oscMessageIsActive(message)) {
      applyPresetByName("soft");
    } else {
      applyPresetByName("neutral");
    }
    return;
  } else if (address.equals("/video/scene/neutral")) {
    if (oscMessageIsActive(message)) {
      applyPresetByName("neutral");
    }
    return;
  } else if (address.equals("/msvp/preset/neutral")) {
    if (oscMessageIsActive(message)) {
      applyPresetByName("neutral");
    }
    return;
  } else if (address.equals("/nw_wrld/feed/blackout")) {
    setBlackout(oscMessageBoolean(message));
    return;
  } else if (address.equals("/msvp/blackout")) {
    setBlackout(oscMessageBoolean(message));
    return;
  }

  if (address.equals("/preset")) {
    if (message.typetag().length() >= 1) {
      applyPresetByName(message.get(0).stringValue());
    }
  } else if (address.equals("/param")) {
    if (message.typetag().length() >= 2) {
      String name = message.get(0).stringValue();
      float value = message.get(1).floatValue();
      setParam(name, value);
    }
  } else if (address.equals("/bias")) {
    if (message.typetag().length() >= 2) {
      String name = message.get(0).stringValue();
      float value = message.get(1).floatValue();
      biasParam(name, value);
    }
  } else if (address.equals("/blackout")) {
    if (message.typetag().length() >= 1) {
      float value = message.get(0).floatValue();
      setBlackout(value > 0.5);
    }
  }
}

boolean oscMessageIsActive(OscMessage message) {
  if (message == null) return false;
  String types = message.typetag();
  if (types == null || types.length() == 0) return true;
  try {
    float value = message.get(0).floatValue();
    return value > 0.0;
  } catch (Throwable e) {
    try {
      String value = message.get(0).stringValue();
      if (value == null) return false;
      String trimmed = value.trim().toLowerCase();
      return trimmed.equals("1") || trimmed.equals("true") || trimmed.equals("on");
    } catch (Throwable inner) {
      return false;
    }
  }
}

boolean oscMessageBoolean(OscMessage message) {
  if (message == null) return false;
  String types = message.typetag();
  if (types == null || types.length() == 0) return true;
  try {
    float value = message.get(0).floatValue();
    return value > 0.0;
  } catch (Throwable e) {
    try {
      String value = message.get(0).stringValue();
      if (value == null) return false;
      String trimmed = value.trim().toLowerCase();
      return trimmed.equals("1") || trimmed.equals("true") || trimmed.equals("on");
    } catch (Throwable inner) {
      return false;
    }
  }
}

void sendOsc(String address, Object... args) {
  if (oscP5 == null || oscTarget == null) return;
  OscMessage message = new OscMessage(address);
  if (args != null) {
    for (int i = 0; i < args.length; i++) {
      Object arg = args[i];
      if (arg instanceof Integer) {
        message.add(((Integer) arg).intValue());
      } else if (arg instanceof Float) {
        message.add(((Float) arg).floatValue());
      } else if (arg instanceof Double) {
        message.add(((Double) arg).floatValue());
      } else if (arg instanceof Boolean) {
        message.add(((Boolean) arg).booleanValue() ? 1 : 0);
      } else {
        message.add(str(arg));
      }
    }
  }
  println("OSC send " + oscTargetHost + ":" + oscTargetPort + " " + address);
  oscP5.send(message, oscTarget);
}

void broadcastStateIfNeeded() {
  if (oscP5 == null || oscTarget == null) return;
  if (beatCount != lastStateBeat) {
    broadcastStateNow();
    return;
  }
  long now = millis();
  if (lastStateOscMs >= 0 && now - lastStateOscMs < stateOscIntervalMs) {
    return;
  }

  lastStateOscMs = now;
  sendOsc("/msvp/state/bpm", bpm);
  sendOsc("/msvp/state/beat", (int) beatCount);
  sendOsc("/msvp/state/preset", activePresetName);
  sendOsc("/msvp/state/effectActive", effectActive ? 1 : 0);
  sendOsc("/msvp/state/blackout", blackoutActive ? 1 : 0);
}

void broadcastStateNow() {
  if (oscP5 == null || oscTarget == null) return;
  lastStateBeat = beatCount;
  lastStateOscMs = millis();
  sendOsc("/msvp/state/bpm", bpm);
  sendOsc("/msvp/state/beat", (int) beatCount);
  sendOsc("/msvp/state/preset", activePresetName);
  sendOsc("/msvp/state/effectActive", effectActive ? 1 : 0);
  sendOsc("/msvp/state/blackout", blackoutActive ? 1 : 0);
}

String formatTransportStatus() {
  if (!isPlaying) return "stopped";
  if (transportStale) return "stale";
  return "playing";
}

String formatMidiInputStatus() {
  String label = (midiSelectedInputName == null || midiSelectedInputName.length() == 0)
    ? "none"
    : midiSelectedInputName;
  if (midiInputFromInterop) {
    return label + " (interop)";
  }
  return label;
}

String formatLastCc() {
  if (lastCcNumber < 0) return "none";
  int displayChannel = lastCcChannel + 1;
  return "ch " + displayChannel + " cc " + lastCcNumber + " val " + lastCcValue;
}

boolean isInteropSelectedInput(String inputName) {
  if (!interopLoaded) return false;
  if (interopPreferredInputName == null || interopPreferredInputName.length() == 0) return false;
  if (inputName == null || inputName.length() == 0) return false;
  String preferred = interopPreferredInputName.toLowerCase();
  String actual = inputName.toLowerCase();
  return actual.indexOf(preferred) >= 0;
}
