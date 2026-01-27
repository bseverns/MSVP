// Scene presets driven by rig note messages.

class ScenePreset {
  String name;
  int linesPerFrame;
  int maxLineSize;
  int opacityMin;
  int effectIntervalBeats;
  int effectDurationBeats;
  int effectBias;

  ScenePreset(String name,
              int linesPerFrame,
              int maxLineSize,
              int opacityMin,
              int effectIntervalBeats,
              int effectDurationBeats,
              int effectBias) {
    this.name = name;
    this.linesPerFrame = linesPerFrame;
    this.maxLineSize = maxLineSize;
    this.opacityMin = opacityMin;
    this.effectIntervalBeats = effectIntervalBeats;
    this.effectDurationBeats = effectDurationBeats;
    this.effectBias = effectBias;
  }
}

boolean PRESET_NOTE_OFF_REVERT_TO_NEUTRAL = true;

ScenePreset presetNeutral;
ScenePreset presetIntro;
ScenePreset presetCrash;
ScenePreset presetSoft;
String activePresetName = "neutral";

void initPresets() {
  presetNeutral = new ScenePreset(
    "neutral",
    linesPerFrame,
    maxLineSize,
    opacityMin,
    effectIntervalBeats,
    effectDurationBeats,
    effectBias
  );

  presetIntro = new ScenePreset(
    "intro",
    60,   // linesPerFrame
    140,  // maxLineSize
    40,   // opacityMin
    8,    // effectIntervalBeats
    2,    // effectDurationBeats
    0     // effectBias (alternate)
  );

  presetCrash = new ScenePreset(
    "crash",
    280,  // linesPerFrame
    220,  // maxLineSize
    160,  // opacityMin
    2,    // effectIntervalBeats
    4,    // effectDurationBeats
    1     // effectBias (rotate)
  );

  presetSoft = new ScenePreset(
    "soft",
    30,   // linesPerFrame
    80,   // maxLineSize
    20,   // opacityMin
    12,   // effectIntervalBeats
    1,    // effectDurationBeats
    -1    // effectBias (lines)
  );
}

void handleSceneNoteOn(int channel, int pitch, int velocity) {
  if (velocity <= 0) {
    handleSceneNoteOff(channel, pitch);
    return;
  }
  if (!rigTunedMode) return;
  if (channel != rigMacroChannel) return;
  ScenePreset preset = presetForNoteOrVerb(pitch);
  if (preset == null) return;
  applyPreset(preset);
}

void handleSceneNoteOff(int channel, int pitch) {
  if (!rigTunedMode) return;
  if (channel != rigMacroChannel) return;
  if (PRESET_NOTE_OFF_REVERT_TO_NEUTRAL && presetNeutral != null) {
    applyPreset(presetNeutral);
  }
}

ScenePreset presetForNoteOrVerb(int pitch) {
  if (pitch == 60) return presetIntro;
  if (pitch == 61) return presetCrash;
  if (pitch == 62) return presetSoft;

  String verb = interopSceneVerbByNote.get(pitch);
  if (verb == null) return null;
  String normalized = verb.trim().toLowerCase();
  if (normalized.equals("intro")) return presetIntro;
  if (normalized.equals("crash")) return presetCrash;
  if (normalized.equals("soft")) return presetSoft;
  return null;
}

void applyPreset(ScenePreset preset) {
  if (preset == null) return;
  setParam("linesPerFrame", preset.linesPerFrame);
  setParam("maxLineSize", preset.maxLineSize);
  setParam("opacityMin", preset.opacityMin);
  setParam("effectIntervalBeats", preset.effectIntervalBeats);
  setParam("effectDurationBeats", preset.effectDurationBeats);
  setParam("effectBias", preset.effectBias);
  applyEffectBiasToType();
  activePresetName = preset.name;
}

void applyEffectBiasToType() {
  if (effectBias < 0) {
    effectType = "lines";
  } else if (effectBias > 0) {
    effectType = "rotate";
  }
}
