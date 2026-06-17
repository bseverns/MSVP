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

boolean SCENE_RELEASE_RESTORES_MACRO_BASE = true;

ScenePreset presetNeutral;
ScenePreset presetIntro;
ScenePreset presetCrash;
ScenePreset presetSoft;
String activePresetName = "neutral";

boolean sceneOverrideActive = false;
String sceneOverrideName = "";
int sceneSavedRigBaseLinesPerFrame;
int sceneSavedRigBaseMaxLineSize;
int sceneSavedRigBaseOpacityMin;
int sceneSavedRigBaseEffectIntervalBeats;
int sceneSavedRigBaseEffectDurationBeats;
float sceneSavedRigBaseBpmSmoothing;
int sceneSavedRigBaseEffectBias;
String sceneSavedPresetName = "neutral";
String sceneSavedEffectType = "lines";

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
  applySceneOverride(preset);
}

void handleSceneNoteOff(int channel, int pitch) {
  if (!rigTunedMode) return;
  if (channel != rigMacroChannel) return;
  ScenePreset preset = presetForNoteOrVerb(pitch);
  if (preset == null) return;
  releaseSceneOverride(preset.name);
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

void applySceneOverride(ScenePreset preset) {
  if (preset == null) return;
  if (!rigTunedMode) {
    applyPreset(preset);
    return;
  }

  if (!sceneOverrideActive) {
    snapshotSceneMacroBase();
  }

  sceneOverrideActive = true;
  sceneOverrideName = preset.name;
  applyPreset(preset);
}

void releaseSceneOverride(String sceneName) {
  if (!SCENE_RELEASE_RESTORES_MACRO_BASE) {
    if (presetNeutral != null) {
      applyPreset(presetNeutral);
    }
    return;
  }

  if (!rigTunedMode) {
    if (presetNeutral != null) {
      applyPreset(presetNeutral);
    }
    return;
  }

  if (!sceneOverrideActive) return;
  if (sceneName != null && sceneOverrideName != null && !sceneOverrideName.equals(sceneName)) {
    return;
  }

  restoreSceneMacroBase();
  sceneOverrideActive = false;
  sceneOverrideName = "";
}

void cancelSceneOverride() {
  sceneOverrideActive = false;
  sceneOverrideName = "";
}

void snapshotSceneMacroBase() {
  sceneSavedRigBaseLinesPerFrame = rigBaseLinesPerFrame;
  sceneSavedRigBaseMaxLineSize = rigBaseMaxLineSize;
  sceneSavedRigBaseOpacityMin = rigBaseOpacityMin;
  sceneSavedRigBaseEffectIntervalBeats = rigBaseEffectIntervalBeats;
  sceneSavedRigBaseEffectDurationBeats = rigBaseEffectDurationBeats;
  sceneSavedRigBaseBpmSmoothing = rigBaseBpmSmoothing;
  sceneSavedRigBaseEffectBias = rigBaseEffectBias;
  sceneSavedPresetName = activePresetName;
  sceneSavedEffectType = effectType;
}

void restoreSceneMacroBase() {
  rigBaseLinesPerFrame = sceneSavedRigBaseLinesPerFrame;
  rigBaseMaxLineSize = sceneSavedRigBaseMaxLineSize;
  rigBaseOpacityMin = sceneSavedRigBaseOpacityMin;
  rigBaseEffectIntervalBeats = sceneSavedRigBaseEffectIntervalBeats;
  rigBaseEffectDurationBeats = sceneSavedRigBaseEffectDurationBeats;
  rigBaseBpmSmoothing = sceneSavedRigBaseBpmSmoothing;
  rigBaseEffectBias = sceneSavedRigBaseEffectBias;
  activePresetName = sceneSavedPresetName;
  effectType = sceneSavedEffectType;
  applyRigEffectiveValues();
}

void applyEffectBiasToType() {
  if (effectBias < 0) {
    effectType = "lines";
  } else if (effectBias > 0) {
    effectType = "rotate";
  }
}
