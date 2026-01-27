// Rig-tuned control mapping + generic fallback.

int rigMacroChannel = 9;
int rigAnalysisChannel = 14;

HashMap<Integer, String> rigMacroTargetsByCc = new HashMap<Integer, String>();
HashMap<Integer, String> rigAnalysisTargetsByCc = new HashMap<Integer, String>();
boolean rigMappingsFromInterop = false;

int rigBaseLinesPerFrame;
int rigBaseMaxLineSize;
int rigBaseOpacityMin;
int rigBaseEffectIntervalBeats;
int rigBaseEffectDurationBeats;
float rigBaseBpmSmoothing;
int rigBaseEffectBias;

float rigBiasLinesPerFrame = 0.0;
float rigBiasMaxLineSize = 0.0;
float rigBiasOpacityMin = 0.0;
float rigBiasEffectInterval = 0.0;
float rigBiasEffectDuration = 0.0;
float rigBiasBpmSmoothing = 0.0;
float rigBiasEffectBias = 0.0;

int RIG_LINES_PER_FRAME_BIAS_MAX = 80;
int RIG_MAX_LINE_SIZE_BIAS_MAX = 60;
int RIG_OPACITY_MIN_BIAS_MAX = 64;
int RIG_EFFECT_INTERVAL_BIAS_MAX = 4;
int RIG_EFFECT_DURATION_BIAS_MAX = 2;
float RIG_BPM_SMOOTHING_BIAS_MAX = 0.12;
float RIG_EFFECT_BIAS_WIND_MAX = 0.5;

void configureRigModeFromInterop() {
  if (CFG_RIG_AUTO_ENABLE_FROM_INTEROP && interopLoaded) {
    rigTunedMode = true;
  }
  configureRigChannels();
  configureRigMappingsFromInterop();
  seedRigBaseFromCurrent();
}

void configureRigChannels() {
  int macroChannel = interopMacroChannel >= 0 ? interopMacroChannel : CFG_RIG_DEFAULT_MACRO_CHANNEL;
  int analysisChannel = interopAnalysisChannel >= 0 ? interopAnalysisChannel : CFG_RIG_DEFAULT_ANALYSIS_CHANNEL;
  rigMacroChannel = normalizeChannelValue(macroChannel);
  rigAnalysisChannel = normalizeChannelValue(analysisChannel);
}

int normalizeChannelValue(int channel) {
  // Treat 1-16 as 1-based MIDI channels; otherwise assume already 0-based.
  if (channel >= 1 && channel <= 16) {
    return channel - 1;
  }
  return channel;
}

void seedRigBaseFromCurrent() {
  rigBaseLinesPerFrame = linesPerFrame;
  rigBaseMaxLineSize = maxLineSize;
  rigBaseOpacityMin = opacityMin;
  rigBaseEffectIntervalBeats = effectIntervalBeats;
  rigBaseEffectDurationBeats = effectDurationBeats;
  rigBaseBpmSmoothing = bpmSmoothing;
  rigBaseEffectBias = effectBias;
  applyRigEffectiveValues();
}

void handleControllerChange(int channel, int number, int value) {
  if (!rigTunedMode) {
    applyGenericMapping(number, value);
    return;
  }

  if (channel == rigMacroChannel) {
    if (rigMappingsFromInterop) {
      applyRigMacroTarget(rigMacroTargetsByCc.get(number), value);
    } else {
      applyRigMacroMapping(number, value);
    }
  } else if (channel == rigAnalysisChannel) {
    if (rigMappingsFromInterop) {
      applyRigAnalysisTarget(rigAnalysisTargetsByCc.get(number), value);
    } else {
      applyRigAnalysisMapping(number, value);
    }
  }
}

void applyGenericMapping(int number, int value) {
  if (number == 1) {  // CC1: line density
    float mapped = map(value, 0, 127,
                       CFG_LINES_PER_FRAME_MIN,
                       CFG_LINES_PER_FRAME_MAX);
    setParam("linesPerFrame", mapped);

  } else if (number == 2) {  // CC2: max line size
    float mapped = map(value, 0, 127,
                       CFG_MAX_LINE_SIZE_MIN,
                       CFG_MAX_LINE_SIZE_MAX);
    setParam("maxLineSize", mapped);

  } else if (number == 3) {  // CC3: opacityMin
    float mapped = map(value, 0, 127,
                       CFG_OPACITY_MIN_MIN,
                       CFG_OPACITY_MIN_MAX);
    setParam("opacityMin", mapped);

  } else if (number == 4) {   // CC4: effect interval (beats)
    float mapped = map(value, 0, 127,
                       CFG_EFFECT_INTERVAL_MIN,
                       CFG_EFFECT_INTERVAL_MAX);
    setParam("effectIntervalBeats", mapped);

  } else if (number == 5) {   // CC5: effect duration (beats)
    float mapped = map(value, 0, 127,
                       CFG_EFFECT_DURATION_MIN,
                       CFG_EFFECT_DURATION_MAX);
    setParam("effectDurationBeats", mapped);

  } else if (number == 6) {   // CC6: BPM smoothing
    float mapped = map(value, 0, 127,
                       CFG_BPM_SMOOTHING_MIN,
                       CFG_BPM_SMOOTHING_MAX);
    setParam("bpmSmoothing", mapped);

  } else if (number == 7) {   // CC7: effect bias
    float bias = value < 42 ? -1 : (value > 84 ? 1 : 0);
    setParam("effectBias", bias);
  }
}

void applyRigMacroMapping(int number, int value) {
  if (number == 1) {  // CC1: line density
    float mapped = map(value, 0, 127,
                       CFG_LINES_PER_FRAME_MIN,
                       CFG_LINES_PER_FRAME_MAX);
    setParam("linesPerFrame", mapped);
  } else if (number == 2) {  // CC2: max line size
    float mapped = map(value, 0, 127,
                       CFG_MAX_LINE_SIZE_MIN,
                       CFG_MAX_LINE_SIZE_MAX);
    setParam("maxLineSize", mapped);
  } else if (number == 3) {  // CC3: opacityMin
    float mapped = map(value, 0, 127,
                       CFG_OPACITY_MIN_MIN,
                       CFG_OPACITY_MIN_MAX);
    setParam("opacityMin", mapped);
  } else if (number == 4) {  // CC4: effect interval (beats)
    float mapped = map(value, 0, 127,
                       CFG_EFFECT_INTERVAL_MIN,
                       CFG_EFFECT_INTERVAL_MAX);
    setParam("effectIntervalBeats", mapped);
  } else if (number == 5) {  // CC5: effect duration (beats)
    float mapped = map(value, 0, 127,
                       CFG_EFFECT_DURATION_MIN,
                       CFG_EFFECT_DURATION_MAX);
    setParam("effectDurationBeats", mapped);
  } else if (number == 6) {  // CC6: BPM smoothing
    float mapped = map(value, 0, 127,
                       CFG_BPM_SMOOTHING_MIN,
                       CFG_BPM_SMOOTHING_MAX);
    setParam("bpmSmoothing", mapped);
  } else if (number == 7) {  // CC7: effect bias
    float bias = value < 42 ? -1 : (value > 84 ? 1 : 0);
    setParam("effectBias", bias);
  }
}

void applyRigAnalysisMapping(int number, int value) {
  float bias = map(value, 0, 127, -1.0, 1.0);
  if (number == 1) {  // CC1: density wind
    biasParam("linesPerFrame", bias);
  } else if (number == 2) {  // CC2: line size wind
    biasParam("maxLineSize", bias);
  } else if (number == 3) {  // CC3: opacity wind
    biasParam("opacityMin", bias);
  } else if (number == 4) {  // CC4: interval wind
    biasParam("effectIntervalBeats", bias);
  } else if (number == 5) {  // CC5: duration wind
    biasParam("effectDurationBeats", bias);
  } else if (number == 6) {  // CC6: smoothing wind
    biasParam("bpmSmoothing", bias);
  } else if (number == 7) {  // CC7: bias wind
    biasParam("effectBias", bias);
  }
}

void applyRigMacroTarget(String target, int value) {
  float mapped = mappedValueForTarget(target, value);
  if (mapped == Float.NEGATIVE_INFINITY) return;
  setParam(target, mapped);
}

void applyRigAnalysisTarget(String target, int value) {
  float bias = map(value, 0, 127, -1.0, 1.0);
  biasParam(target, bias);
}

void applyRigEffectiveValues() {
  int densityBias = int(RIG_LINES_PER_FRAME_BIAS_MAX * rigBiasLinesPerFrame);
  linesPerFrame = rigBaseLinesPerFrame + densityBias;
  linesPerFrame = constrain(linesPerFrame, CFG_LINES_PER_FRAME_MIN, CFG_LINES_PER_FRAME_MAX);

  int lineSizeBias = int(RIG_MAX_LINE_SIZE_BIAS_MAX * rigBiasMaxLineSize);
  maxLineSize = rigBaseMaxLineSize + lineSizeBias;
  maxLineSize = constrain(maxLineSize, CFG_MAX_LINE_SIZE_MIN, CFG_MAX_LINE_SIZE_MAX);

  int opacityBias = int(RIG_OPACITY_MIN_BIAS_MAX * rigBiasOpacityMin);
  opacityMin = rigBaseOpacityMin + opacityBias;
  opacityMin = constrain(opacityMin, CFG_OPACITY_MIN_MIN, CFG_OPACITY_MIN_MAX);
  if (opacityMin > opacityMax) opacityMin = opacityMax;

  int intervalBias = int(RIG_EFFECT_INTERVAL_BIAS_MAX * rigBiasEffectInterval);
  effectIntervalBeats = rigBaseEffectIntervalBeats + intervalBias;
  effectIntervalBeats = constrain(effectIntervalBeats, CFG_EFFECT_INTERVAL_MIN, CFG_EFFECT_INTERVAL_MAX);
  effectIntervalBeats = max(effectIntervalBeats, 1);

  int durationBias = int(RIG_EFFECT_DURATION_BIAS_MAX * rigBiasEffectDuration);
  effectDurationBeats = rigBaseEffectDurationBeats + durationBias;
  effectDurationBeats = constrain(effectDurationBeats, CFG_EFFECT_DURATION_MIN, CFG_EFFECT_DURATION_MAX);
  effectDurationBeats = max(effectDurationBeats, 1);

  float smoothingBias = RIG_BPM_SMOOTHING_BIAS_MAX * rigBiasBpmSmoothing;
  bpmSmoothing = rigBaseBpmSmoothing + smoothingBias;
  bpmSmoothing = constrain(bpmSmoothing, CFG_BPM_SMOOTHING_MIN, CFG_BPM_SMOOTHING_MAX);

  float combinedBias = rigBaseEffectBias + (rigBiasEffectBias * RIG_EFFECT_BIAS_WIND_MAX);
  if (combinedBias <= -0.5) {
    effectBias = -1;
  } else if (combinedBias >= 0.5) {
    effectBias = 1;
  } else {
    effectBias = 0;
  }
}

void configureRigMappingsFromInterop() {
  rigMacroTargetsByCc.clear();
  rigAnalysisTargetsByCc.clear();
  rigMappingsFromInterop = false;

  boolean parsed = false;

  if (interopMappingsObject != null) {
    parsed = true;
    JSONObject macroMappings = interopMappingsObject.getJSONObject("macro");
    JSONObject analysisMappings = interopMappingsObject.getJSONObject("analysis");
    if (macroMappings != null) {
      addMappingsFromObject(macroMappings, "macro");
    }
    if (analysisMappings != null) {
      addMappingsFromObject(analysisMappings, "analysis");
    }
  }

  if (interopMappingsArray != null) {
    parsed = true;
    for (int i = 0; i < interopMappingsArray.size(); i++) {
      JSONObject mapping = interopMappingsArray.getJSONObject(i);
      if (mapping == null) continue;
      String lane = readString(mapping, "lane");
      if (lane.length() == 0) {
        lane = readString(mapping, "channel");
      }
      int cc = readInt(mapping, "cc", -1);
      if (cc < 0) {
        cc = readInt(mapping, "controller", -1);
      }
      String target = readString(mapping, "target");
      if (target.length() == 0) {
        target = readString(mapping, "param");
      }
      addRigMapping(lane, cc, target);
    }
  }

  if (rigMacroTargetsByCc.size() == 0 && rigAnalysisTargetsByCc.size() == 0) {
    seedDefaultRigMappings();
    rigMappingsFromInterop = false;
    return;
  }

  rigMappingsFromInterop = parsed;
}

void seedDefaultRigMappings() {
  addRigMapping("macro", 1, "linesPerFrame");
  addRigMapping("macro", 2, "maxLineSize");
  addRigMapping("macro", 3, "opacityMin");
  addRigMapping("macro", 4, "effectIntervalBeats");
  addRigMapping("macro", 5, "effectDurationBeats");
  addRigMapping("macro", 6, "bpmSmoothing");
  addRigMapping("macro", 7, "effectBias");

  addRigMapping("analysis", 1, "linesPerFrame");
  addRigMapping("analysis", 2, "maxLineSize");
  addRigMapping("analysis", 3, "opacityMin");
  addRigMapping("analysis", 4, "effectIntervalBeats");
  addRigMapping("analysis", 5, "effectDurationBeats");
  addRigMapping("analysis", 6, "bpmSmoothing");
  addRigMapping("analysis", 7, "effectBias");
}

void addMappingsFromObject(JSONObject mappingObject, String lane) {
  if (mappingObject == null) return;
  String[] keys = mappingObject.keys();
  if (keys == null) return;
  for (int i = 0; i < keys.length; i++) {
    String key = keys[i];
    if (key == null) continue;
    int cc = parseCcKey(key);
    String target = readString(mappingObject, key);
    addRigMapping(lane, cc, target);
  }
}

int parseCcKey(String key) {
  try {
    return Integer.parseInt(key.trim());
  } catch (Throwable e) {
    return -1;
  }
}

void addRigMapping(String lane, int cc, String target) {
  if (cc < 0 || cc > 127) return;
  if (target == null) return;
  String trimmedTarget = target.trim();
  if (trimmedTarget.length() == 0) return;
  String normalizedLane = lane == null ? "" : lane.trim().toLowerCase();
  if (normalizedLane.equals("macro")) {
    rigMacroTargetsByCc.put(cc, trimmedTarget);
  } else if (normalizedLane.equals("analysis")) {
    rigAnalysisTargetsByCc.put(cc, trimmedTarget);
  }
}

String normalizeTargetKey(String target) {
  if (target == null) return "";
  String lower = target.trim().toLowerCase();
  if (lower.length() == 0) return "";
  String result = "";
  for (int i = 0; i < lower.length(); i++) {
    char c = lower.charAt(i);
    if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
      result += c;
    }
  }
  return result;
}

float mappedValueForTarget(String target, int ccValue) {
  String key = normalizeTargetKey(target);
  if (key.equals("linesperframe") || key.equals("density")) {
    return map(ccValue, 0, 127, CFG_LINES_PER_FRAME_MIN, CFG_LINES_PER_FRAME_MAX);
  } else if (key.equals("maxlinesize") || key.equals("linesize")) {
    return map(ccValue, 0, 127, CFG_MAX_LINE_SIZE_MIN, CFG_MAX_LINE_SIZE_MAX);
  } else if (key.equals("opacitymin") || key.equals("opacityfloor")) {
    return map(ccValue, 0, 127, CFG_OPACITY_MIN_MIN, CFG_OPACITY_MIN_MAX);
  } else if (key.equals("effectintervalbeats") || key.equals("intervalbeats") || key.equals("effectinterval")) {
    return map(ccValue, 0, 127, CFG_EFFECT_INTERVAL_MIN, CFG_EFFECT_INTERVAL_MAX);
  } else if (key.equals("effectdurationbeats") || key.equals("durationbeats") || key.equals("effectduration")) {
    return map(ccValue, 0, 127, CFG_EFFECT_DURATION_MIN, CFG_EFFECT_DURATION_MAX);
  } else if (key.equals("bpmsmoothing") || key.equals("bpmsmooth") || key.equals("smoothing")) {
    return map(ccValue, 0, 127, CFG_BPM_SMOOTHING_MIN, CFG_BPM_SMOOTHING_MAX);
  } else if (key.equals("effectbias") || key.equals("bias")) {
    return ccValue < 42 ? -1 : (ccValue > 84 ? 1 : 0);
  }
  return Float.NEGATIVE_INFINITY;
}
