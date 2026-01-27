// Shared action layer for MIDI + OSC control paths.

boolean blackoutActive = false;

void applyPresetByName(String name) {
  if (name == null) return;
  String normalized = normalizeTargetKey(name);
  if (normalized.equals("intro")) {
    applyPreset(presetIntro);
  } else if (normalized.equals("crash")) {
    applyPreset(presetCrash);
  } else if (normalized.equals("soft")) {
    applyPreset(presetSoft);
  } else if (normalized.equals("neutral")) {
    applyPreset(presetNeutral);
  }
}

void setParam(String name, float value) {
  String key = normalizeTargetKey(name);
  if (key.length() == 0) return;

  if (rigTunedMode) {
    if (key.equals("linesperframe") || key.equals("density")) {
      rigBaseLinesPerFrame = constrain(round(value), CFG_LINES_PER_FRAME_MIN, CFG_LINES_PER_FRAME_MAX);
    } else if (key.equals("maxlinesize") || key.equals("linesize")) {
      rigBaseMaxLineSize = constrain(round(value), CFG_MAX_LINE_SIZE_MIN, CFG_MAX_LINE_SIZE_MAX);
    } else if (key.equals("opacitymin") || key.equals("opacityfloor")) {
      rigBaseOpacityMin = constrain(round(value), CFG_OPACITY_MIN_MIN, CFG_OPACITY_MIN_MAX);
    } else if (key.equals("effectintervalbeats") || key.equals("intervalbeats") || key.equals("effectinterval")) {
      rigBaseEffectIntervalBeats = constrain(round(value), CFG_EFFECT_INTERVAL_MIN, CFG_EFFECT_INTERVAL_MAX);
      rigBaseEffectIntervalBeats = max(rigBaseEffectIntervalBeats, 1);
    } else if (key.equals("effectdurationbeats") || key.equals("durationbeats") || key.equals("effectduration")) {
      rigBaseEffectDurationBeats = constrain(round(value), CFG_EFFECT_DURATION_MIN, CFG_EFFECT_DURATION_MAX);
      rigBaseEffectDurationBeats = max(rigBaseEffectDurationBeats, 1);
    } else if (key.equals("bpmsmoothing") || key.equals("bpmsmooth") || key.equals("smoothing")) {
      rigBaseBpmSmoothing = constrain(value, CFG_BPM_SMOOTHING_MIN, CFG_BPM_SMOOTHING_MAX);
    } else if (key.equals("effectbias") || key.equals("bias")) {
      rigBaseEffectBias = normalizeBias(value);
    } else {
      return;
    }

    applyRigEffectiveValues();
  } else {
    if (key.equals("linesperframe") || key.equals("density")) {
      linesPerFrame = constrain(round(value), CFG_LINES_PER_FRAME_MIN, CFG_LINES_PER_FRAME_MAX);
    } else if (key.equals("maxlinesize") || key.equals("linesize")) {
      maxLineSize = constrain(round(value), CFG_MAX_LINE_SIZE_MIN, CFG_MAX_LINE_SIZE_MAX);
    } else if (key.equals("opacitymin") || key.equals("opacityfloor")) {
      opacityMin = constrain(round(value), CFG_OPACITY_MIN_MIN, CFG_OPACITY_MIN_MAX);
      if (opacityMin > opacityMax) opacityMin = opacityMax;
    } else if (key.equals("effectintervalbeats") || key.equals("intervalbeats") || key.equals("effectinterval")) {
      effectIntervalBeats = constrain(round(value), CFG_EFFECT_INTERVAL_MIN, CFG_EFFECT_INTERVAL_MAX);
      effectIntervalBeats = max(effectIntervalBeats, 1);
    } else if (key.equals("effectdurationbeats") || key.equals("durationbeats") || key.equals("effectduration")) {
      effectDurationBeats = constrain(round(value), CFG_EFFECT_DURATION_MIN, CFG_EFFECT_DURATION_MAX);
      effectDurationBeats = max(effectDurationBeats, 1);
    } else if (key.equals("bpmsmoothing") || key.equals("bpmsmooth") || key.equals("smoothing")) {
      bpmSmoothing = constrain(value, CFG_BPM_SMOOTHING_MIN, CFG_BPM_SMOOTHING_MAX);
    } else if (key.equals("effectbias") || key.equals("bias")) {
      effectBias = normalizeBias(value);
      applyEffectBiasToType();
    } else {
      return;
    }
  }
}

void biasParam(String name, float value) {
  if (!rigTunedMode) return;
  String key = normalizeTargetKey(name);
  if (key.length() == 0) return;
  float bias = constrain(value, -1.0, 1.0);

  if (key.equals("linesperframe") || key.equals("density")) {
    rigBiasLinesPerFrame = bias;
  } else if (key.equals("maxlinesize") || key.equals("linesize")) {
    rigBiasMaxLineSize = bias;
  } else if (key.equals("opacitymin") || key.equals("opacityfloor")) {
    rigBiasOpacityMin = bias;
  } else if (key.equals("effectintervalbeats") || key.equals("intervalbeats") || key.equals("effectinterval")) {
    rigBiasEffectInterval = bias;
  } else if (key.equals("effectdurationbeats") || key.equals("durationbeats") || key.equals("effectduration")) {
    rigBiasEffectDuration = bias;
  } else if (key.equals("bpmsmoothing") || key.equals("bpmsmooth") || key.equals("smoothing")) {
    rigBiasBpmSmoothing = bias;
  } else if (key.equals("effectbias") || key.equals("bias")) {
    rigBiasEffectBias = bias;
  } else {
    return;
  }

  applyRigEffectiveValues();
}

void setParamNormalized(String name, float normalized) {
  float mapped = mapNormalizedParam(name, normalized);
  if (mapped == Float.NEGATIVE_INFINITY) return;
  setParam(name, mapped);
}

void biasParamNormalized(String name, float normalized) {
  float bias = map(constrain(normalized, 0.0, 1.0), 0.0, 1.0, -1.0, 1.0);
  biasParam(name, bias);
}

int normalizeBias(float value) {
  if (value <= -0.5) return -1;
  if (value >= 0.5) return 1;
  return 0;
}

void setBlackout(boolean enabled) {
  if (blackoutActive == enabled) return;
  blackoutActive = enabled;
  sendOsc("/msvp/state/blackout", enabled ? 1 : 0);
}

float mapNormalizedParam(String name, float normalized) {
  String key = normalizeTargetKey(name);
  if (key.length() == 0) return Float.NEGATIVE_INFINITY;
  float value = constrain(normalized, 0.0, 1.0);

  if (key.equals("linesperframe") || key.equals("density")) {
    return lerp(CFG_LINES_PER_FRAME_MIN, CFG_LINES_PER_FRAME_MAX, value);
  } else if (key.equals("maxlinesize") || key.equals("linesize")) {
    return lerp(CFG_MAX_LINE_SIZE_MIN, CFG_MAX_LINE_SIZE_MAX, value);
  } else if (key.equals("opacitymin") || key.equals("opacityfloor")) {
    return lerp(CFG_OPACITY_MIN_MIN, CFG_OPACITY_MIN_MAX, value);
  } else if (key.equals("effectintervalbeats") || key.equals("intervalbeats") || key.equals("effectinterval")) {
    return lerp(CFG_EFFECT_INTERVAL_MIN, CFG_EFFECT_INTERVAL_MAX, value);
  } else if (key.equals("effectdurationbeats") || key.equals("durationbeats") || key.equals("effectduration")) {
    return lerp(CFG_EFFECT_DURATION_MIN, CFG_EFFECT_DURATION_MAX, value);
  } else if (key.equals("bpmsmoothing") || key.equals("bpmsmooth") || key.equals("smoothing")) {
    return lerp(CFG_BPM_SMOOTHING_MIN, CFG_BPM_SMOOTHING_MAX, value);
  } else if (key.equals("effectbias") || key.equals("bias")) {
    return lerp(-1.0, 1.0, value);
  }

  return Float.NEGATIVE_INFINITY;
}
