import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress target;

String targetHost = "127.0.0.1";
int targetPort = 9010;

ArrayList<ActionButton> buttons = new ArrayList<ActionButton>();

void setup() {
  size(560, 420);
  textFont(createFont("SansSerif", 14));
  oscP5 = new OscP5(this, 0);
  target = new NetAddress(targetHost, targetPort);
  buildButtons();
}

void draw() {
  background(20);
  fill(240);
  text("OSC Control Simulator -> " + targetHost + ":" + targetPort, 16, 22);
  for (int i = 0; i < buttons.size(); i++) {
    buttons.get(i).draw();
  }
}

void mousePressed() {
  for (int i = 0; i < buttons.size(); i++) {
    ActionButton button = buttons.get(i);
    if (button.hit(mouseX, mouseY)) {
      button.onClick();
      break;
    }
  }
}

void buildButtons() {
  int x = 20;
  int y = 40;
  int w = 250;
  int h = 36;
  int gap = 8;

  addButton("Scene Intro", "/video/scene/intro", new Object[] { 1 }, x, y, w, h); y += h + gap;
  addButton("Scene Crash", "/video/scene/crash", new Object[] { 1 }, x, y, w, h); y += h + gap;
  addButton("Scene Soft", "/video/scene/soft", new Object[] { 1 }, x, y, w, h); y += h + gap;
  addButton("NW Blackout ON", "/nw_wrld/feed/blackout", new Object[] { 1 }, x, y, w, h); y += h + gap;
  addButton("MSVP Blackout ON", "/msvp/blackout", new Object[] { 1 }, x, y, w, h); y += h + gap;
  addButton("MSVP Blackout OFF", "/msvp/blackout", new Object[] { 0 }, x, y, w, h); y += h + gap;

  int x2 = 300;
  int y2 = 40;
  addButton("Macro density 0.85", "/msvp/macro/linesPerFrame", new Object[] { 0.85 }, x2, y2, w, h); y2 += h + gap;
  addButton("Macro lineSize 0.65", "/msvp/macro/maxLineSize", new Object[] { 0.65 }, x2, y2, w, h); y2 += h + gap;
  addButton("Macro opacity 0.25", "/msvp/macro/opacityMin", new Object[] { 0.25 }, x2, y2, w, h); y2 += h + gap;
  addButton("Macro interval 0.35", "/msvp/macro/effectIntervalBeats", new Object[] { 0.35 }, x2, y2, w, h); y2 += h + gap;
  addButton("Macro duration 0.40", "/msvp/macro/effectDurationBeats", new Object[] { 0.40 }, x2, y2, w, h); y2 += h + gap;

  int x3 = 300;
  int y3 = y2 + 12;
  addToggleButton("Analysis density bias", "/msvp/analysis/linesPerFrame",
    new Object[] { 0.85 }, new Object[] { 0.50 }, x3, y3, w, h); y3 += h + gap;
  addToggleButton("Analysis size bias", "/msvp/analysis/maxLineSize",
    new Object[] { 0.80 }, new Object[] { 0.50 }, x3, y3, w, h); y3 += h + gap;
  addToggleButton("Analysis opacity bias", "/msvp/analysis/opacityMin",
    new Object[] { 0.20 }, new Object[] { 0.50 }, x3, y3, w, h); y3 += h + gap;
}

void addButton(String label, String address, Object[] args, int x, int y, int w, int h) {
  buttons.add(new ActionButton(label, address, args, x, y, w, h));
}

void addToggleButton(String label, String address, Object[] onArgs, Object[] offArgs, int x, int y, int w, int h) {
  buttons.add(new ToggleButton(label, address, onArgs, offArgs, x, y, w, h));
}

void sendOsc(String address, Object[] args) {
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
      } else {
        message.add(str(arg));
      }
    }
  }
  println("OSC send " + targetHost + ":" + targetPort + " " + address);
  oscP5.send(message, target);
}

class ActionButton {
  String label;
  String address;
  Object[] args;
  int x;
  int y;
  int w;
  int h;

  ActionButton(String label, String address, Object[] args, int x, int y, int w, int h) {
    this.label = label;
    this.address = address;
    this.args = args;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }

  void onClick() {
    sendOsc(address, args);
  }

  void draw() {
    boolean hovering = hit(mouseX, mouseY);
    stroke(hovering ? 220 : 140);
    fill(hovering ? 70 : 50);
    rect(x, y, w, h, 6);
    fill(240);
    text(label, x + 12, y + h / 2 + 5);
  }

  boolean hit(int px, int py) {
    return px >= x && px <= x + w && py >= y && py <= y + h;
  }
}

class ToggleButton extends ActionButton {
  boolean active = false;
  Object[] onArgs;
  Object[] offArgs;
  String baseLabel;

  ToggleButton(String label, String address, Object[] onArgs, Object[] offArgs, int x, int y, int w, int h) {
    super(label, address, onArgs, x, y, w, h);
    this.onArgs = onArgs;
    this.offArgs = offArgs;
    this.baseLabel = label;
    updateLabel();
  }

  void onClick() {
    active = !active;
    updateLabel();
    sendOsc(address, active ? onArgs : offArgs);
  }

  void updateLabel() {
    label = baseLabel + (active ? " (ON)" : " (OFF)");
  }

  void draw() {
    boolean hovering = hit(mouseX, mouseY);
    stroke(hovering ? 220 : (active ? 200 : 140));
    fill(hovering ? 70 : (active ? 80 : 50));
    rect(x, y, w, h, 6);
    fill(240);
    text(label, x + 12, y + h / 2 + 5);
  }
}
