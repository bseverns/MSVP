import codeanticode.syphon.*;

SyphonClient client;
PImage incoming;

void setup() {
  size(1000, 750, P3D);
  client = new SyphonClient(this); // connect to first available server
}

void draw() {
  background(0);

  if (client != null && client.available()) {
    incoming = client.getImage(incoming);
  }

  if (incoming != null) {
    image(incoming, 0, 0, width, height);
  }

  fill(255);
  textSize(14);
  text("SyphonClientTest - showing first available Syphon server", 10, 20);
}
