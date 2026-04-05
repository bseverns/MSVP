#!/usr/bin/env python3
"""Validate MSVP's rig interop locally and against sibling live-rig repos."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        raise SystemExit(f"Missing file: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON/YAML in {path}: {exc}")


def add_mismatch(errors: list[str], scope: str, field: str, actual: Any, expected: Any) -> None:
    errors.append(f"{scope}: {field} is {actual!r}, expected {expected!r}")


def collect_pads(profile: dict[str, Any], scope: str) -> tuple[dict[str, dict[str, Any]], list[str]]:
    pads = profile.get("pads", [])
    if not isinstance(pads, list):
        return {}, [f"{scope}: pads must be a list"]

    pads_by_id: dict[str, dict[str, Any]] = {}
    errors: list[str] = []
    for pad in pads:
        pad_id = pad.get("id")
        if not isinstance(pad_id, str) or not pad_id:
            errors.append(f"{scope}: pad is missing a valid id")
            continue
        if pad_id in pads_by_id:
            errors.append(f"{scope}: duplicate pad id '{pad_id}'")
            continue
        pads_by_id[pad_id] = pad
    return pads_by_id, errors


def validate_lane_by_contract(
    errors: list[str],
    pads_by_id: dict[str, dict[str, Any]],
    scope_prefix: str,
    lane_name: str,
    lane_contract: dict[str, Any],
    *,
    require_osc_binding: bool,
) -> None:
    prefix = lane_contract["osc_equivalent_prefix"]
    expected_channel = lane_contract["channel"]

    for item in lane_contract["parameters"]:
        pad_id = item["pad_id"]
        pad = pads_by_id.get(pad_id)
        if pad is None:
            errors.append(f"{scope_prefix}: missing {lane_name} pad '{pad_id}'")
            continue

        midi = pad.get("midi", {})
        osc = pad.get("osc", {})
        scope = f"{scope_prefix}:{pad_id}"

        if midi.get("type") != "cc":
            add_mismatch(errors, scope, "midi.type", midi.get("type"), "cc")
        if midi.get("channel") != expected_channel:
            add_mismatch(errors, scope, "midi.channel", midi.get("channel"), expected_channel)
        if midi.get("cc") != item["cc"]:
            add_mismatch(errors, scope, "midi.cc", midi.get("cc"), item["cc"])
        if require_osc_binding and osc.get("address") != prefix + item["name"]:
            add_mismatch(errors, scope, "osc.address", osc.get("address"), prefix + item["name"])

    for pad_id, pad in pads_by_id.items():
        if not pad_id.startswith(lane_name + "_") and not pad_id.startswith("msvp_" + lane_name + "_"):
            continue
        if pad_id not in {item["pad_id"] for item in lane_contract["parameters"]}:
            errors.append(f"{scope_prefix}: unknown {lane_name} pad '{pad_id}'")


def validate_msvp(interop_path: Path, contract: dict[str, Any]) -> tuple[list[str], list[str]]:
    data = load_json(interop_path)
    if not isinstance(data, dict):
        return [f"{interop_path}: root must be an object"], []

    runtime = data.get("runtime", {})
    if not isinstance(runtime, dict):
        return [f"{interop_path}: runtime must be an object"], []
    midi_runtime = runtime.get("midi", {})
    if not isinstance(midi_runtime, dict):
        return [f"{interop_path}: runtime.midi must be an object"], []

    profiles = data.get("profiles", {})
    if not isinstance(profiles, dict):
        return [f"{interop_path}: missing profiles object"], []
    profile = profiles.get("msvp")
    if not isinstance(profile, dict):
        return [f"{interop_path}: missing profile 'msvp'"], []

    pads_by_id, profile_errors = collect_pads(profile, str(interop_path))
    errors = list(profile_errors)
    checks: list[str] = []

    scene_contract = contract["controls"]["scene_triggers"]
    macro_contract = contract["controls"]["macro_lane"]
    analysis_contract = contract["controls"]["analysis_lane"]

    if runtime.get("profile") != "msvp":
        add_mismatch(errors, str(interop_path), "runtime.profile", runtime.get("profile"), "msvp")
    if not isinstance(runtime.get("rigTunedMode"), bool):
        errors.append(f"{interop_path}: runtime.rigTunedMode must be boolean")
    if midi_runtime.get("macroChannel") != macro_contract["channel"]:
        add_mismatch(
            errors,
            str(interop_path),
            "runtime.midi.macroChannel",
            midi_runtime.get("macroChannel"),
            macro_contract["channel"],
        )
    if midi_runtime.get("analysisChannel") != analysis_contract["channel"]:
        add_mismatch(
            errors,
            str(interop_path),
            "runtime.midi.analysisChannel",
            midi_runtime.get("analysisChannel"),
            analysis_contract["channel"],
        )

    for scene in scene_contract["scenes"]:
        scene_id = scene["semantic_id"]
        pad = pads_by_id.get(scene_id)
        if pad is None:
            errors.append(f"{interop_path}: missing scene pad '{scene_id}'")
            continue

        midi = pad.get("midi", {})
        osc = pad.get("osc", {})
        group = pad.get("group", {})
        scope = f"{interop_path}:{scene_id}"

        if midi.get("type") != "note":
            add_mismatch(errors, scope, "midi.type", midi.get("type"), "note")
        if midi.get("channel") != scene_contract["msvp_receive_channel"]:
            add_mismatch(errors, scope, "midi.channel", midi.get("channel"), scene_contract["msvp_receive_channel"])
        if midi.get("note") != scene["midi_note"]:
            add_mismatch(errors, scope, "midi.note", midi.get("note"), scene["midi_note"])
        if osc.get("address") != scene["osc_address"]:
            add_mismatch(errors, scope, "osc.address", osc.get("address"), scene["osc_address"])
        if osc.get("onArgs") != [1] or osc.get("offArgs") != [0]:
            errors.append(f"{scope}: osc toggle payload must be [1]/[0]")
        if isinstance(group, dict):
            if group.get("id") != "msvp_scene":
                add_mismatch(errors, scope, "group.id", group.get("id"), "msvp_scene")
        else:
            errors.append(f"{scope}: group must be an object")

    for pad_id in sorted(pads_by_id):
        if pad_id.startswith("vid_scene_") and pad_id not in {scene["semantic_id"] for scene in scene_contract["scenes"]}:
            errors.append(f"{interop_path}: unknown semantic scene pad '{pad_id}'")

    validate_lane_by_contract(
        errors,
        pads_by_id,
        str(interop_path),
        "macro",
        macro_contract,
        require_osc_binding=True,
    )
    validate_lane_by_contract(
        errors,
        pads_by_id,
        str(interop_path),
        "analysis",
        analysis_contract,
        require_osc_binding=True,
    )

    if not errors:
        checks.append(
            f"{interop_path}: profile 'msvp' matches canonical scenes plus macro ch {macro_contract['channel']} and analysis ch {analysis_contract['channel']}"
        )
        checks.append(
            f"{interop_path}: endpoint exposes {len(macro_contract['parameters'])} macro and {len(analysis_contract['parameters'])} analysis controls with controller-aligned IDs"
        )

    return errors, checks


def validate_live_rig(live_rig_path: Path, contract: dict[str, Any]) -> tuple[list[str], list[str]]:
    data = load_json(live_rig_path)
    mappings = data.get("mappings")
    if not isinstance(mappings, list):
        return [f"{live_rig_path}: mappings must be a list"], []

    mappings_by_id = {mapping.get("id"): mapping for mapping in mappings if isinstance(mapping, dict)}
    errors: list[str] = []
    checks: list[str] = []
    scene_contract = contract["controls"]["scene_triggers"]

    for scene in scene_contract["scenes"]:
      mapping = mappings_by_id.get(scene["semantic_id"])
      if mapping is None:
          errors.append(f"{live_rig_path}: missing scene mapping '{scene['semantic_id']}'")
          continue
      midi = mapping.get("midi", {})
      osc = mapping.get("osc", {})
      scope = f"{live_rig_path}:{scene['semantic_id']}"
      if midi.get("type") != "note":
          add_mismatch(errors, scope, "midi.type", midi.get("type"), "note")
      if midi.get("channel") != scene_contract["msvp_receive_channel"]:
          add_mismatch(errors, scope, "midi.channel", midi.get("channel"), scene_contract["msvp_receive_channel"])
      if midi.get("note") != scene["midi_note"]:
          add_mismatch(errors, scope, "midi.note", midi.get("note"), scene["midi_note"])
      if osc.get("address") != scene["osc_address"]:
          add_mismatch(errors, scope, "osc.address", osc.get("address"), scene["osc_address"])

    if not errors:
        checks.append(f"{live_rig_path}: scene mappings match the canonical MSVP scene IDs, notes, and OSC addresses")
    return errors, checks


def validate_live_rig_control(control_path: Path, contract: dict[str, Any]) -> tuple[list[str], list[str]]:
    data = load_json(control_path)
    profiles = data.get("profiles")
    if not isinstance(profiles, dict):
        return [f"{control_path}: missing profiles object"], []

    controller = contract["controller_surface"]
    profile = profiles.get(controller["profile_id"])
    if not isinstance(profile, dict):
        return [f"{control_path}: missing profile '{controller['profile_id']}'"], []

    pads_by_id, pad_errors = collect_pads(profile, str(control_path))
    errors = list(pad_errors)
    checks: list[str] = []

    if profile.get("label") != controller["label"]:
        add_mismatch(errors, f"{control_path}:{controller['profile_id']}", "label", profile.get("label"), controller["label"])
    if profile.get("section") != controller["section"]:
        add_mismatch(errors, f"{control_path}:{controller['profile_id']}", "section", profile.get("section"), controller["section"])
    if profile.get("order") != controller["order"]:
        add_mismatch(errors, f"{control_path}:{controller['profile_id']}", "order", profile.get("order"), controller["order"])

    scene_contract = contract["controls"]["scene_triggers"]
    for scene in scene_contract["scenes"]:
        scene_id = scene["semantic_id"]
        pad = pads_by_id.get(scene_id)
        if pad is None:
            errors.append(f"{control_path}: missing scene pad '{scene_id}'")
            continue
        osc = pad.get("osc", {})
        if osc.get("address") != scene["osc_address"]:
            add_mismatch(errors, f"{control_path}:{scene_id}", "osc.address", osc.get("address"), scene["osc_address"])
        if "midi" in pad:
            errors.append(f"{control_path}:{scene_id}: controller profile should keep scene transport OSC-only")

    validate_lane_by_contract(
        errors,
        pads_by_id,
        str(control_path),
        "macro",
        contract["controls"]["macro_lane"],
        require_osc_binding=False,
    )
    validate_lane_by_contract(
        errors,
        pads_by_id,
        str(control_path),
        "analysis",
        contract["controls"]["analysis_lane"],
        require_osc_binding=False,
    )

    for item in contract["controls"]["macro_lane"]["parameters"] + contract["controls"]["analysis_lane"]["parameters"]:
        pad = pads_by_id.get(item["pad_id"])
        if pad is not None and "osc" in pad:
            errors.append(f"{control_path}:{item['pad_id']}: controller lane pads should not emit OSC mirrors")

    if not errors:
        checks.append(
            f"{control_path}: profile 'msvp' matches OSC scene cues plus macro ch {contract['controls']['macro_lane']['channel']} and analysis ch {contract['controls']['analysis_lane']['channel']}"
        )
        checks.append(f"{control_path}: controller keeps scenes OSC-only and exposes the canonical 7+7 shaping controls")
    return errors, checks


def parse_args() -> tuple[argparse.Namespace, Path, Path, Path]:
    repo_root = Path(__file__).resolve().parents[1]
    default_contract = repo_root / "contracts" / "msvp_live_rig_control.yaml"
    default_live_rig = repo_root.parent / "live-rig" / "mappings.json"
    default_live_rig_control = repo_root.parent / "live-rig-control" / "src" / "mappings.json"
    default_msvp = repo_root / "MidiVideoSyphonBeats" / "data" / "live_rig_interop.json"

    parser = argparse.ArgumentParser(
        description="Validate MSVP's rig interop and optionally check sibling live-rig repos against the shared contract."
    )
    parser.add_argument("--contract", type=Path, default=default_contract, help="Path to the canonical contract file.")
    parser.add_argument("--msvp-interop", type=Path, default=default_msvp, help="Path to MSVP's live_rig_interop.json.")
    parser.add_argument(
        "--live-rig-mappings",
        type=Path,
        default=None,
        help="Optional path to live-rig/mappings.json. Defaults to ../live-rig/mappings.json when available.",
    )
    parser.add_argument(
        "--live-rig-control-mappings",
        type=Path,
        default=None,
        help="Optional path to live-rig-control/src/mappings.json. Defaults to ../live-rig-control/src/mappings.json when available.",
    )
    parser.add_argument(
        "--local-only",
        action="store_true",
        help="Validate only MSVP's local interop file and skip sibling repo checks.",
    )
    return parser.parse_args(), default_live_rig, default_live_rig_control, default_msvp


def main() -> int:
    args, default_live_rig, default_live_rig_control, _default_msvp = parse_args()
    contract_root = load_json(args.contract)
    contract = contract_root.get("contract")
    if not isinstance(contract, dict):
        print(f"ERROR {args.contract}: missing top-level 'contract' object")
        return 1

    errors: list[str] = []
    checks: list[str] = [f"Contract {contract['name']} v{contract['version']}"]

    target_errors, target_checks = validate_msvp(args.msvp_interop, contract)
    errors.extend(target_errors)
    checks.extend(target_checks)

    if not args.local_only:
        live_rig_path = args.live_rig_mappings or default_live_rig
        if live_rig_path.exists():
            target_errors, target_checks = validate_live_rig(live_rig_path, contract)
            errors.extend(target_errors)
            checks.extend(target_checks)
        else:
            checks.append(f"{live_rig_path}: skipped (not found)")

        control_path = args.live_rig_control_mappings or default_live_rig_control
        if control_path.exists():
            target_errors, target_checks = validate_live_rig_control(control_path, contract)
            errors.extend(target_errors)
            checks.extend(target_checks)
        else:
            checks.append(f"{control_path}: skipped (not found)")

    if errors:
        print("FAIL")
        for item in checks:
            print(f"  {item}")
        for item in errors:
            print(f"  ERROR: {item}")
        return 1

    print("PASS")
    for item in checks:
        print(f"  {item}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
