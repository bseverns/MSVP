// Interop contract loader for rig-tuned integration.

boolean interopLoaded = false;
String interopConfigPath = "live_rig_interop.json";
String interopPreferredInputName = "";
int interopMacroChannel = -1;
int interopAnalysisChannel = -1;
boolean interopRigTunedModeRequested = false;
String interopProfileId = "";
HashMap<Integer, String> interopSceneVerbByNote = new HashMap<Integer, String>();
HashMap<String, Integer> interopSceneNoteByVerb = new HashMap<String, Integer>();
JSONObject interopMappingsObject = null;
JSONArray interopMappingsArray = null;
String interopLoadError = "";
int interopOscListenPort = -1;
String interopOscTargetHost = "";
int interopOscTargetPort = -1;

void setInteropConfigPath(String path) {
  if (path == null) return;
  String trimmed = path.trim();
  if (trimmed.length() == 0) return;
  interopConfigPath = trimmed;
}

void loadInteropConfig() {
  interopLoaded = false;
  interopLoadError = "";
  interopPreferredInputName = "";
  interopMacroChannel = -1;
  interopAnalysisChannel = -1;
  interopRigTunedModeRequested = false;
  interopProfileId = "";
  interopSceneVerbByNote.clear();
  interopSceneNoteByVerb.clear();
  interopMappingsObject = null;
  interopMappingsArray = null;
  interopOscListenPort = -1;
  interopOscTargetHost = "";
  interopOscTargetPort = -1;

  JSONObject root = null;
  try {
    root = loadJSONObject(interopConfigPath);
  } catch (Throwable e) {
    // loadJSONObject throws on malformed JSON; missing files return null.
    interopLoadError = e.getMessage();
  }

  if (root == null) {
    interopLoaded = false;
    return;
  }

  interopLoaded = true;
  parseInteropSettings(root);

  JSONObject profiles = root.getJSONObject("profiles");
  if (profiles != null) {
    loadInteropProfiles(profiles);
  } else {
    loadLegacyInteropSettings(root);
  }
}

void parseInteropSettings(JSONObject root) {
  if (root == null) return;

  parseInteropSettingScope(root);

  JSONObject runtime = root.getJSONObject("runtime");
  if (runtime != null) {
    parseInteropSettingScope(runtime);
  }
}

void parseInteropSettingScope(JSONObject scope) {
  if (scope == null) return;

  if (scope.hasKey("rigTunedMode")) {
    interopRigTunedModeRequested = readBoolean(scope, "rigTunedMode", interopRigTunedModeRequested);
  } else if (scope.hasKey("rig_tuned_mode")) {
    interopRigTunedModeRequested = readBoolean(scope, "rig_tuned_mode", interopRigTunedModeRequested);
  }

  if (interopProfileId.length() == 0) {
    interopProfileId = readString(scope, "profile");
  }
  if (interopProfileId.length() == 0) {
    interopProfileId = readString(scope, "profileId");
  }

  if (interopPreferredInputName.length() == 0) {
    interopPreferredInputName = readString(scope, "preferred_midi_input");
  }
  if (interopPreferredInputName.length() == 0) {
    interopPreferredInputName = readString(scope, "preferredInput");
  }
  if (interopPreferredInputName.length() == 0) {
    interopPreferredInputName = readString(scope, "preferredMidiInput");
  }

  JSONObject midi = scope.getJSONObject("midi");
  if (midi != null) {
    if (interopPreferredInputName.length() == 0) {
      interopPreferredInputName = readString(midi, "preferred_input");
    }
    if (interopPreferredInputName.length() == 0) {
      interopPreferredInputName = readString(midi, "preferredInput");
    }
    if (interopPreferredInputName.length() == 0) {
      interopPreferredInputName = readString(midi, "preferred_midi_input");
    }
    if (interopPreferredInputName.length() == 0) {
      interopPreferredInputName = readString(midi, "preferredMidiInput");
    }

    if (interopMacroChannel < 0) {
      interopMacroChannel = readInt(midi, "macro_channel", -1);
    }
    if (interopMacroChannel < 0) {
      interopMacroChannel = readInt(midi, "macroChannel", -1);
    }
    if (interopAnalysisChannel < 0) {
      interopAnalysisChannel = readInt(midi, "analysis_channel", -1);
    }
    if (interopAnalysisChannel < 0) {
      interopAnalysisChannel = readInt(midi, "analysisChannel", -1);
    }
  }

  JSONObject channels = scope.getJSONObject("channels");
  if (channels != null) {
    if (interopMacroChannel < 0) {
      interopMacroChannel = readInt(channels, "macro", -1);
    }
    if (interopAnalysisChannel < 0) {
      interopAnalysisChannel = readInt(channels, "analysis", -1);
    }
  }

  if (interopMacroChannel < 0) {
    interopMacroChannel = readInt(scope, "macro_channel", -1);
  }
  if (interopMacroChannel < 0) {
    interopMacroChannel = readInt(scope, "macroChannel", -1);
  }
  if (interopAnalysisChannel < 0) {
    interopAnalysisChannel = readInt(scope, "analysis_channel", -1);
  }
  if (interopAnalysisChannel < 0) {
    interopAnalysisChannel = readInt(scope, "analysisChannel", -1);
  }

  JSONObject osc = scope.getJSONObject("osc");
  if (osc != null) {
    if (interopOscListenPort < 0) {
      interopOscListenPort = readInt(osc, "listen_port", -1);
    }
    if (interopOscListenPort < 0) {
      interopOscListenPort = readInt(osc, "listenPort", -1);
    }
    if (interopOscTargetHost.length() == 0) {
      interopOscTargetHost = readString(osc, "target_host");
    }
    if (interopOscTargetHost.length() == 0) {
      interopOscTargetHost = readString(osc, "targetHost");
    }
    if (interopOscTargetPort < 0) {
      interopOscTargetPort = readInt(osc, "target_port", -1);
    }
    if (interopOscTargetPort < 0) {
      interopOscTargetPort = readInt(osc, "targetPort", -1);
    }
  }

  if (interopOscListenPort < 0) {
    interopOscListenPort = readInt(scope, "osc_listen_port", -1);
  }
  if (interopOscListenPort < 0) {
    interopOscListenPort = readInt(scope, "oscListenPort", -1);
  }
  if (interopOscTargetHost.length() == 0) {
    interopOscTargetHost = readString(scope, "osc_target_host");
  }
  if (interopOscTargetHost.length() == 0) {
    interopOscTargetHost = readString(scope, "oscTargetHost");
  }
  if (interopOscTargetPort < 0) {
    interopOscTargetPort = readInt(scope, "osc_target_port", -1);
  }
  if (interopOscTargetPort < 0) {
    interopOscTargetPort = readInt(scope, "oscTargetPort", -1);
  }
}

void loadLegacyInteropSettings(JSONObject root) {
  Object sceneVerbs = root.get("scene_verbs");
  if (sceneVerbs instanceof JSONObject) {
    JSONObject verbs = (JSONObject) sceneVerbs;
    String[] keys = verbs.keys();
    if (keys != null) {
      for (int i = 0; i < keys.length; i++) {
        String name = keys[i];
        if (name == null) continue;
        int note = readInt(verbs, name, -1);
        registerSceneVerb(name, note);
      }
    }
  } else if (sceneVerbs instanceof JSONArray) {
    JSONArray verbs = (JSONArray) sceneVerbs;
    for (int i = 0; i < verbs.size(); i++) {
      JSONObject verb = verbs.getJSONObject(i);
      if (verb == null) continue;
      String name = readString(verb, "name");
      if (name.length() == 0) {
        name = readString(verb, "verb");
      }
      if (name.length() == 0) {
        name = readString(verb, "preset");
      }
      int note = readInt(verb, "note", -1);
      if (note < 0) {
        note = readInt(verb, "pitch", -1);
      }
      registerSceneVerb(name, note);
    }
  }

  interopMappingsObject = root.getJSONObject("mappings");
  if (interopMappingsObject == null) {
    interopMappingsArray = root.getJSONArray("mappings");
  }
}

void loadInteropProfiles(JSONObject profiles) {
  String selectedProfileId = selectInteropProfileId(profiles);
  if (selectedProfileId.length() == 0) {
    interopLoadError = "No usable profile found in interop contract.";
    return;
  }

  interopProfileId = selectedProfileId;
  JSONObject profile = profiles.getJSONObject(selectedProfileId);
  if (profile == null) {
    interopLoadError = "Selected interop profile is missing: " + selectedProfileId;
    return;
  }

  JSONArray pads = profile.getJSONArray("pads");
  if (pads == null) {
    interopLoadError = "Selected interop profile has no pads array: " + selectedProfileId;
    return;
  }

  interopMappingsArray = new JSONArray();
  for (int i = 0; i < pads.size(); i++) {
    JSONObject pad = pads.getJSONObject(i);
    if (pad == null) continue;
    loadInteropProfilePad(pad);
  }
}

String selectInteropProfileId(JSONObject profiles) {
  if (profiles == null) return "";
  if (interopProfileId.length() > 0 && profiles.hasKey(interopProfileId)) {
    return interopProfileId;
  }
  if (profiles.hasKey("msvp")) {
    return "msvp";
  }
  if (profiles.hasKey("default")) {
    return "default";
  }
  String[] keys = profiles.keys();
  if (keys == null || keys.length == 0) return "";
  return keys[0];
}

void loadInteropProfilePad(JSONObject pad) {
  if (pad == null) return;

  JSONObject midi = pad.getJSONObject("midi");
  if (midi == null) return;

  String midiType = readString(midi, "type");
  if (midiType.equals("cc")) {
    int cc = readInt(midi, "cc", -1);
    String lane = deriveInteropLane(pad);
    String target = deriveInteropTarget(pad);
    appendInteropMapping(lane, cc, target);
  } else if (midiType.equals("note")) {
    int note = readInt(midi, "note", -1);
    String preset = deriveInteropPresetName(pad);
    registerSceneVerb(preset, note);
  }
}

String deriveInteropLane(JSONObject pad) {
  String fromNotes = extractTaggedInteropValue(readString(pad, "notes"), "lane");
  if (fromNotes.length() > 0) return fromNotes;

  JSONObject osc = pad.getJSONObject("osc");
  String address = readString(osc, "address");
  if (address.startsWith("/msvp/macro/")) return "macro";
  if (address.startsWith("/msvp/analysis/")) return "analysis";

  String padId = readString(pad, "id");
  if (padId.startsWith("macro_")) return "macro";
  if (padId.startsWith("analysis_")) return "analysis";

  return "";
}

String deriveInteropTarget(JSONObject pad) {
  String fromNotes = extractTaggedInteropValue(readString(pad, "notes"), "target");
  if (fromNotes.length() > 0) return fromNotes;

  JSONObject osc = pad.getJSONObject("osc");
  String address = readString(osc, "address");
  String macroPrefix = "/msvp/macro/";
  if (address.startsWith(macroPrefix)) {
    return address.substring(macroPrefix.length());
  }
  String analysisPrefix = "/msvp/analysis/";
  if (address.startsWith(analysisPrefix)) {
    return address.substring(analysisPrefix.length());
  }

  String padId = readString(pad, "id");
  if (padId.startsWith("macro_")) {
    return padId.substring("macro_".length());
  }
  if (padId.startsWith("analysis_")) {
    return padId.substring("analysis_".length());
  }

  return "";
}

String deriveInteropPresetName(JSONObject pad) {
  String fromNotes = extractTaggedInteropValue(readString(pad, "notes"), "preset");
  if (fromNotes.length() > 0) return fromNotes;
  fromNotes = extractTaggedInteropValue(readString(pad, "notes"), "scene");
  if (fromNotes.length() > 0) return fromNotes;
  fromNotes = extractTaggedInteropValue(readString(pad, "notes"), "verb");
  if (fromNotes.length() > 0) return fromNotes;

  JSONObject osc = pad.getJSONObject("osc");
  String address = readString(osc, "address");
  String scenePrefix = "/video/scene/";
  if (address.startsWith(scenePrefix)) {
    return address.substring(scenePrefix.length());
  }

  String padId = readString(pad, "id");
  if (padId.startsWith("vid_scene_")) {
    return padId.substring("vid_scene_".length());
  }

  return "";
}

String extractTaggedInteropValue(String notes, String tag) {
  if (notes == null || tag == null) return "";
  String[] tokens = splitTokens(notes, " ,;\n\t");
  String normalizedTag = tag.trim().toLowerCase() + ":";
  for (int i = 0; i < tokens.length; i++) {
    String token = tokens[i];
    if (token == null) continue;
    String trimmed = token.trim();
    if (trimmed.length() == 0) continue;
    String lower = trimmed.toLowerCase();
    if (lower.startsWith(normalizedTag)) {
      return trimmed.substring(normalizedTag.length());
    }
  }
  return "";
}

void appendInteropMapping(String lane, int cc, String target) {
  if (lane == null || lane.length() == 0) return;
  if (target == null || target.length() == 0) return;
  if (cc < 0 || cc > 127) return;

  if (interopMappingsArray == null) {
    interopMappingsArray = new JSONArray();
  }

  JSONObject mapping = new JSONObject();
  mapping.setString("lane", lane);
  mapping.setInt("cc", cc);
  mapping.setString("target", target);
  interopMappingsArray.setJSONObject(interopMappingsArray.size(), mapping);
}

String readString(JSONObject obj, String key) {
  if (obj == null || key == null) return "";
  if (!obj.hasKey(key)) return "";
  String value = "";
  try {
    value = obj.getString(key);
  } catch (Throwable e) {
    value = "";
  }
  return value == null ? "" : value.trim();
}

boolean readBoolean(JSONObject obj, String key, boolean fallback) {
  if (obj == null || key == null) return fallback;
  if (!obj.hasKey(key)) return fallback;
  try {
    return obj.getBoolean(key);
  } catch (Throwable e) {
    try {
      String asString = obj.getString(key);
      String normalized = asString == null ? "" : asString.trim().toLowerCase();
      if (normalized.equals("true") || normalized.equals("1") || normalized.equals("yes") || normalized.equals("on")) {
        return true;
      }
      if (normalized.equals("false") || normalized.equals("0") || normalized.equals("no") || normalized.equals("off")) {
        return false;
      }
    } catch (Throwable inner) {
      return fallback;
    }
  }
  return fallback;
}

int readInt(JSONObject obj, String key, int fallback) {
  if (obj == null || key == null) return fallback;
  if (!obj.hasKey(key)) return fallback;
  try {
    return obj.getInt(key);
  } catch (Throwable e) {
    try {
      String asString = obj.getString(key);
      return Integer.parseInt(asString.trim());
    } catch (Throwable inner) {
      return fallback;
    }
  }
}

void registerSceneVerb(String name, int note) {
  if (name == null) return;
  String trimmed = name.trim();
  if (trimmed.length() == 0) return;
  if (note < 0) return;
  interopSceneVerbByNote.put(note, trimmed);
  interopSceneNoteByVerb.put(trimmed, note);
}

String formatSceneVerbBindings() {
  if (interopSceneVerbByNote.isEmpty()) return "none";
  IntList notes = new IntList();
  for (Integer note : interopSceneVerbByNote.keySet()) {
    notes.append(note.intValue());
  }
  notes.sort();
  String result = "";
  for (int i = 0; i < notes.size(); i++) {
    int note = notes.get(i);
    String verb = interopSceneVerbByNote.get(note);
    if (verb == null) continue;
    if (result.length() > 0) result += ", ";
    result += verb + ":" + note;
  }
  return result.length() == 0 ? "none" : result;
}

String formatChannelLabel(int channel) {
  return channel < 0 ? "unset" : str(channel);
}

void printInteropStatus(String selectedInputName) {
  String selectedLabel = (selectedInputName == null || selectedInputName.length() == 0)
    ? "none"
    : selectedInputName;
  println("Interop: " + (interopLoaded ? "loaded" : "missing") + " (" + interopConfigPath + ")");
  println("Interop profile: " + (interopProfileId.length() == 0 ? "none" : interopProfileId));
  println("Rig mode request: " + (interopRigTunedModeRequested ? "enabled" : "disabled"));
  println("MIDI input: " + selectedLabel);
  println("Channels: macro=" + formatChannelLabel(interopMacroChannel)
    + " analysis=" + formatChannelLabel(interopAnalysisChannel));
  println("Scene verbs (Ch10 notes): " + formatSceneVerbBindings());
}
