// Interop contract loader for rig-tuned integration.

boolean interopLoaded = false;
String interopConfigPath = "live_rig_interop.json";
String interopPreferredInputName = "";
int interopMacroChannel = -1;
int interopAnalysisChannel = -1;
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

  interopPreferredInputName = readString(root, "preferred_midi_input");
  if (interopPreferredInputName.length() == 0) {
    JSONObject midi = root.getJSONObject("midi");
    if (midi != null) {
      interopPreferredInputName = readString(midi, "preferred_input");
      if (interopPreferredInputName.length() == 0) {
        interopPreferredInputName = readString(midi, "preferred_midi_input");
      }
    }
  }

  JSONObject channels = root.getJSONObject("channels");
  if (channels != null) {
    interopMacroChannel = readInt(channels, "macro", -1);
    interopAnalysisChannel = readInt(channels, "analysis", -1);
  }
  if (interopMacroChannel < 0) {
    interopMacroChannel = readInt(root, "macro_channel", -1);
  }
  if (interopAnalysisChannel < 0) {
    interopAnalysisChannel = readInt(root, "analysis_channel", -1);
  }

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

  JSONObject osc = root.getJSONObject("osc");
  if (osc != null) {
    interopOscListenPort = readInt(osc, "listen_port", -1);
    if (interopOscListenPort < 0) {
      interopOscListenPort = readInt(osc, "listenPort", -1);
    }
    interopOscTargetHost = readString(osc, "target_host");
    if (interopOscTargetHost.length() == 0) {
      interopOscTargetHost = readString(osc, "targetHost");
    }
    interopOscTargetPort = readInt(osc, "target_port", -1);
    if (interopOscTargetPort < 0) {
      interopOscTargetPort = readInt(osc, "targetPort", -1);
    }
  }

  if (interopOscListenPort < 0) {
    interopOscListenPort = readInt(root, "osc_listen_port", -1);
  }
  if (interopOscTargetHost.length() == 0) {
    interopOscTargetHost = readString(root, "osc_target_host");
  }
  if (interopOscTargetPort < 0) {
    interopOscTargetPort = readInt(root, "osc_target_port", -1);
  }
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
  println("MIDI input: " + selectedLabel);
  println("Channels: macro=" + formatChannelLabel(interopMacroChannel)
    + " analysis=" + formatChannelLabel(interopAnalysisChannel));
  println("Scene verbs (Ch10 notes): " + formatSceneVerbBindings());
}
