import codeanticode.syphon.*;

SyphonClient client;
PGraphics feedbackBuffer;
PImage incoming;

float feedbackAmount = 0.85;  // how much of previous frame to keep
float zoom = 1.0;             // optional zoom for tunnel-like effect

void setup() {
  size(1000, 750, P3D);

  client = new SyphonClient(this); // first available Syphon server

  feedbackBuffer = createGraphics(width, height, P3D);
  feedbackBuffer.beginDraw();
  feedbackBuffer.background(0);
  feedbackBuffer.endDraw();
}

void draw() {
  // Pull latest Syphon frame
  if (client != null && client.available()) {
    incoming = client.getImage(incoming);
  }

  feedbackBuffer.beginDraw();

  // Fade previous frame slightly for trailing feedback
  feedbackBuffer.noStroke();
  feedbackBuffer.fill(0, (1.0 - feedbackAmount) * 255.0);
  feedbackBuffer.rect(0, 0, feedbackBuffer.width, feedbackBuffer.height);

  // Optional zoom to create a tunnel-like effect
  feedbackBuffer.pushMatrix();
  feedbackBuffer.translate(feedbackBuffer.width / 2.0, feedbackBuffer.height / 2.0);
  feedbackBuffer.scale(zoom);
  feedbackBuffer.translate(-feedbackBuffer.width / 2.0, -feedbackBuffer.height / 2.0);

  // Draw the previous frame into itself (feedback)
  feedbackBuffer.image(feedbackBuffer, 0, 0, feedbackBuffer.width, feedbackBuffer.height);

  feedbackBuffer.popMatrix();

  // Composite incoming frame on top
  if (incoming != null) {
    feedbackBuffer.image(incoming, 0, 0, feedbackBuffer.width, feedbackBuffer.height);
  }

  feedbackBuffer.endDraw();

  // Draw to screen
  image(feedbackBuffer, 0, 0, width, height);

  fill(255);
  textSize(14);
  text("SyphonPostProcess - feedback tunnel", 10, 20);
  text("feedbackAmount: " + nf(feedbackAmount, 0, 2), 10, 40);
  text("zoom: " + nf(zoom, 0, 2), 10, 60);
}

// Optional: simple key control for parameters
void keyPressed() {
  if (key == 'q') {
    feedbackAmount = constrain(feedbackAmount + 0.02, 0.0, 1.0);
  } else if (key == 'a') {
    feedbackAmount = constrain(feedbackAmount - 0.02, 0.0, 1.0);
  } else if (key == 'w') {
    zoom = min(zoom + 0.01, 1.1);
  } else if (key == 's') {
    zoom = max(zoom - 0.01, 0.9);
  }
}
