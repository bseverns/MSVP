#!/usr/bin/env python3
"""Validate the shipped MSVP rig interop contract."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


EXPECTED_SCENES = {
    "intro": {"note": 60, "address": "/video/scene/intro"},
    "crash": {"note": 61, "address": "/video/scene/crash"},
    "soft": {"note": 62, "address": "/video/scene/soft"},
}

EXPECTED_PARAMS = [
    "linesPerFrame",
    "maxLineSize",
    "opacityMin",
    "effectIntervalBeats",
    "effectDurationBeats",
    "bpmSmoothing",
    "effectBias",
]


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def require_dict(value: Any, label: str, errors: list[str]) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    fail(errors, f"{label} must be an object")
    return {}


def require_list(value: Any, label: str, errors: list[str]) -> list[Any]:
    if isinstance(value, list):
        return value
    fail(errors, f"{label} must be an array")
    return []


def normalize_scene_name(pad: dict[str, Any]) -> str:
    notes = str(pad.get("notes", "")).split()
    for token in notes:
        if token.startswith("preset:"):
            return token.split(":", 1)[1].strip().lower()
        if token.startswith("scene:"):
            return token.split(":", 1)[1].strip().lower()
    address = str(pad.get("osc", {}).get("address", ""))
    prefix = "/video/scene/"
    if address.startswith(prefix):
        return address[len(prefix) :].strip().lower()
    pad_id = str(pad.get("id", "")).lower()
    if pad_id.startswith("vid_scene_"):
        return pad_id[len("vid_scene_") :]
    return ""


def normalize_target(address: str, prefix: str) -> str:
    if address.startswith(prefix):
        return address[len(prefix) :]
    return ""


def validate_runtime(data: dict[str, Any], errors: list[str]) -> tuple[int | None, int | None]:
    runtime = require_dict(data.get("runtime"), "runtime", errors)
    midi = require_dict(runtime.get("midi"), "runtime.midi", errors)

    if "rigTunedMode" not in runtime:
        fail(errors, "runtime.rigTunedMode is required")
    elif not isinstance(runtime["rigTunedMode"], bool):
        fail(errors, "runtime.rigTunedMode must be boolean")

    preferred_input = midi.get("preferredInput")
    if not isinstance(preferred_input, str) or not preferred_input.strip():
        fail(errors, "runtime.midi.preferredInput must be a non-empty string")

    macro_channel = midi.get("macroChannel")
    analysis_channel = midi.get("analysisChannel")
    for key, value in (("macroChannel", macro_channel), ("analysisChannel", analysis_channel)):
        if not isinstance(value, int):
            fail(errors, f"runtime.midi.{key} must be an integer 1..16")
        elif value < 1 or value > 16:
            fail(errors, f"runtime.midi.{key} must be in 1..16")

    if isinstance(macro_channel, int) and isinstance(analysis_channel, int):
        if macro_channel == analysis_channel:
            fail(errors, "runtime.midi.macroChannel and analysisChannel should be distinct")

    return (
        macro_channel if isinstance(macro_channel, int) else None,
        analysis_channel if isinstance(analysis_channel, int) else None,
    )


def validate_profile(data: dict[str, Any], errors: list[str]) -> list[dict[str, Any]]:
    profiles = require_dict(data.get("profiles"), "profiles", errors)
    profile = require_dict(profiles.get("msvp"), "profiles.msvp", errors)
    pads = require_list(profile.get("pads"), "profiles.msvp.pads", errors)

    seen_ids: set[str] = set()
    for pad in pads:
        if not isinstance(pad, dict):
            fail(errors, "each pad must be an object")
            continue
        pad_id = pad.get("id")
        if not isinstance(pad_id, str) or not pad_id.strip():
            fail(errors, "each pad must have a non-empty id")
            continue
        if pad_id in seen_ids:
            fail(errors, f"duplicate pad id: {pad_id}")
        seen_ids.add(pad_id)

    return [pad for pad in pads if isinstance(pad, dict)]


def validate_scenes(pads: list[dict[str, Any]], macro_channel: int | None, errors: list[str]) -> None:
    scene_pads = [pad for pad in pads if str(pad.get("midi", {}).get("type", "")) == "note"]
    scenes_by_name = {normalize_scene_name(pad): pad for pad in scene_pads}

    for scene_name, expected in EXPECTED_SCENES.items():
        pad = scenes_by_name.get(scene_name)
        if not pad:
            fail(errors, f"missing scene pad for {scene_name}")
            continue

        midi = require_dict(pad.get("midi"), f"{pad.get('id')}.midi", errors)
        osc = require_dict(pad.get("osc"), f"{pad.get('id')}.osc", errors)

        if midi.get("channel") != macro_channel:
            fail(errors, f"{pad['id']} should use macro channel {macro_channel}")
        if midi.get("note") != expected["note"]:
            fail(errors, f"{pad['id']} should use note {expected['note']}")
        if osc.get("address") != expected["address"]:
            fail(errors, f"{pad['id']} should use OSC {expected['address']}")
        if osc.get("onArgs") != [1] or osc.get("offArgs") != [0]:
            fail(errors, f"{pad['id']} should declare explicit OSC on/off args [1]/[0]")


def validate_lane(
    pads: list[dict[str, Any]],
    lane: str,
    channel: int | None,
    prefix: str,
    errors: list[str],
) -> None:
    lane_pads = []
    for pad in pads:
        midi = pad.get("midi", {})
        osc = pad.get("osc", {})
        if midi.get("type") != "cc":
            continue
        address = str(osc.get("address", ""))
        if not address.startswith(prefix):
            continue
        lane_pads.append(pad)

    params_seen: dict[str, int] = {}
    ccs_seen: set[int] = set()

    for pad in lane_pads:
        midi = require_dict(pad.get("midi"), f"{pad.get('id')}.midi", errors)
        osc = require_dict(pad.get("osc"), f"{pad.get('id')}.osc", errors)
        cc = midi.get("cc")
        address = str(osc.get("address", ""))
        target = normalize_target(address, prefix)

        if midi.get("channel") != channel:
            fail(errors, f"{pad['id']} should use {lane} channel {channel}")
        if not isinstance(cc, int) or cc < 1 or cc > 7:
            fail(errors, f"{pad['id']} should use CC 1..7")
        elif cc in ccs_seen:
            fail(errors, f"{lane} lane reuses CC {cc}")
        else:
            ccs_seen.add(cc)

        if target not in EXPECTED_PARAMS:
            fail(errors, f"{pad['id']} has unsupported {lane} target {target!r}")
        elif target in params_seen:
            fail(errors, f"{lane} lane repeats target {target}")
        else:
            params_seen[target] = cc

        args = osc.get("args")
        if not isinstance(args, list) or len(args) != 1 or not isinstance(args[0], (int, float)):
            fail(errors, f"{pad['id']} should declare one numeric OSC arg placeholder")

    if len(lane_pads) != len(EXPECTED_PARAMS):
        fail(errors, f"{lane} lane should define {len(EXPECTED_PARAMS)} pads, found {len(lane_pads)}")

    missing_params = [param for param in EXPECTED_PARAMS if param not in params_seen]
    if missing_params:
        fail(errors, f"{lane} lane missing targets: {', '.join(missing_params)}")

    for index, param in enumerate(EXPECTED_PARAMS, start=1):
        if params_seen.get(param) != index:
            fail(errors, f"{lane} lane should map CC{index} to {param}")


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    default_path = repo_root / "MidiVideoSyphonBeats" / "data" / "live_rig_interop.json"
    path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else default_path

    if not path.exists():
        print(f"ERROR: contract file not found: {path}")
        return 1

    try:
        data = read_json(path)
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in {path}: {exc}")
        return 1

    errors: list[str] = []

    if not isinstance(data, dict):
        print(f"ERROR: root value in {path} must be an object")
        return 1

    macro_channel, analysis_channel = validate_runtime(data, errors)
    pads = validate_profile(data, errors)
    validate_scenes(pads, macro_channel, errors)
    validate_lane(pads, "macro", macro_channel, "/msvp/macro/", errors)
    validate_lane(pads, "analysis", analysis_channel, "/msvp/analysis/", errors)

    if errors:
        print(f"FAIL {path}")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"OK   {path}")
    print(f"- rigTunedMode: {data['runtime']['rigTunedMode']}")
    print(f"- preferredInput: {data['runtime']['midi']['preferredInput']}")
    print(f"- channels: macro={macro_channel} analysis={analysis_channel}")
    print(f"- scenes: {', '.join(EXPECTED_SCENES.keys())}")
    print(f"- macro params: {', '.join(EXPECTED_PARAMS)}")
    print(f"- analysis params: {', '.join(EXPECTED_PARAMS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
