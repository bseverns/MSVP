// Shared tunables + defaults for MidiVideoSyphonBeats

// Hard limits for safe MIDI CC mapping
int CFG_LINES_PER_FRAME_MIN   = 10;
int CFG_LINES_PER_FRAME_MAX   = 400;

int CFG_MAX_LINE_SIZE_MIN     = 5;
int CFG_MAX_LINE_SIZE_MAX     = 300;

int CFG_OPACITY_MIN_MIN       = 0;
int CFG_OPACITY_MIN_MAX       = 255;

int CFG_EFFECT_INTERVAL_MIN   = 1;
int CFG_EFFECT_INTERVAL_MAX   = 64;

int CFG_EFFECT_DURATION_MIN   = 1;
int CFG_EFFECT_DURATION_MAX   = 16;

float CFG_BPM_SMOOTHING_MIN   = 0.05;
float CFG_BPM_SMOOTHING_MAX   = 0.6;

// Runtime parameters
int   effectIntervalBeats;   // every N beats, start effect window
int   effectDurationBeats;   // effect window length in beats
int   linesPerFrame;         // lines drawn per frame in lines effect
int   maxLineSize;           // max line length in pixels
int   opacityMin;            // minimum alpha for lines
int   opacityMax;            // maximum alpha for lines
float bpmSmoothing;          // smoothing for BPM changes

void loadDefaultConfig() {
  effectIntervalBeats = 8;
  effectDurationBeats = 2;

  linesPerFrame       = 100;
  maxLineSize         = 100;

  opacityMin          = 50;
  opacityMax          = 255;

  bpmSmoothing        = 0.3;
}
