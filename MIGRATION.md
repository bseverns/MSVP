# Interop Mappings Migration (live-rig-control)

This repo now ships the `live-rig-control` interop contract in
`interop.schema.json`. Existing mappings can remain largely unchanged, but
**toggles must declare explicit on/off payloads**.

## What changed

- Root is a set of `profiles`, each with `pads`.
- `interopVersion` is a string identifier (optional but recommended).
- Toggle semantics are explicit:
  - `toggle: true` or `mode: "toggle"`.
- OSC toggles **must** define both `onArgs` and `offArgs`.
- MIDI toggles should declare explicit on/off values:
  - Notes: `onVelocity` / `offVelocity`
  - CCs: `onValue` / `offValue`
- Exclusive groups use `group` as a string or object:
  - `{ "id": "scene", "mode": "exclusive" }`
- Optional state round-trip:
  - `state.query` and `state.publish` (OSC address + args)

## Minimal upgrade for legacy toggles

If you previously sent only `args: [1]` for toggles, migrate to explicit
on/off args:

```json
// Before
{
  "id": "feed-enable",
  "toggle": true,
  "osc": { "address": "/nw_wrld/feed/enable", "args": [1] }
}

// After
{
  "id": "feed-enable",
  "toggle": true,
  "osc": { "address": "/nw_wrld/feed/enable", "onArgs": [1], "offArgs": [0] }
}
```

## Add the interop version and profiles container

Make sure your root object includes `interopVersion` and `profiles`:

```json
{
  "interopVersion": "1.0.0",
  "profiles": {
    "default": {
      "pads": [ ... ]
    }
  }
}
```

## Legacy MIDI toggles

If a MIDI toggle only sent a single value, add an explicit `off` value:

```json
// Before
{ "midi": { "type": "cc", "channel": 10, "cc": 12, "onValue": 127 } }

// After
{ "midi": { "type": "cc", "channel": 10, "cc": 12, "onValue": 127, "offValue": 0 } }
```

## Validate after migration

```sh
node tools/interop-validate.js --file interop.json
```
