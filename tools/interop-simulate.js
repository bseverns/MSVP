#!/usr/bin/env node
'use strict';

var fs = require('fs');

function usage() {
  console.log('Usage: node tools/interop-simulate.js --file interop.json --id mappingId [--state on|off|press]');
}

function readJson(filePath) {
  var text = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(text);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function formatOscArgs(args) {
  if (!Array.isArray(args) || args.length === 0) return '(no args)';
  return JSON.stringify(args);
}

function formatMidi(pad, value) {
  var midi = pad.midi;
  var channel = midi.channel;
  if (midi.type === 'cc') {
    return 'MIDI CC ch=' + channel + ' cc=' + midi.cc + ' value=' + value;
  }
  return 'MIDI NOTE ch=' + channel + ' note=' + midi.note + ' velocity=' + value;
}

function listPads(doc) {
  var pads = [];
  if (!doc || !isObject(doc.profiles)) return pads;
  Object.keys(doc.profiles).forEach(function (key) {
    var profile = doc.profiles[key];
    if (profile && Array.isArray(profile.pads)) {
      profile.pads.forEach(function (pad) {
        pads.push({ profileId: key, profile: profile, pad: pad });
      });
    }
  });
  return pads;
}

function findPad(doc, id) {
  var pads = listPads(doc);
  for (var i = 0; i < pads.length; i++) {
    if (pads[i].pad && pads[i].pad.id === id) return pads[i];
  }
  for (var j = 0; j < pads.length; j++) {
    if (pads[j].pad && pads[j].pad.osc && pads[j].pad.osc.address === id) return pads[j];
  }
  return null;
}

function resolveBehavior(pad) {
  if (pad.mode === 'toggle') return 'toggle';
  if (pad.mode === 'momentary') return 'momentary';
  if (pad.toggle === true) return 'toggle';
  return 'momentary';
}

var args = process.argv.slice(2);
var filePath = null;
var mappingId = null;
var state = 'press';

for (var i = 0; i < args.length; i++) {
  var arg = args[i];
  if (arg === '--help' || arg === '-h') {
    usage();
    process.exit(0);
  }
  if (arg === '--file') {
    filePath = args[++i];
    continue;
  }
  if (arg === '--id') {
    mappingId = args[++i];
    continue;
  }
  if (arg === '--state') {
    state = args[++i];
    continue;
  }
  if (arg.charAt(0) === '-') {
    console.error('Unknown option: ' + arg);
    usage();
    process.exit(1);
  }
  if (!filePath) {
    filePath = arg;
    continue;
  }
  if (!mappingId) {
    mappingId = arg;
    continue;
  }
}

if (!filePath || !mappingId) {
  usage();
  process.exit(1);
}

var doc = null;
try {
  doc = readJson(filePath);
} catch (err) {
  console.error('Failed to read interop file: ' + filePath);
  console.error(err.message);
  process.exit(1);
}

if (!isObject(doc) || !isObject(doc.profiles)) {
  console.error('Invalid interop file: missing profiles object');
  process.exit(1);
}

var found = findPad(doc, mappingId);
if (!found) {
  console.error('Pad not found: ' + mappingId);
  console.error('Tip: IDs available:');
  listPads(doc).forEach(function (entry) {
    if (entry && entry.pad && entry.pad.id) console.error('  - ' + entry.pad.id);
  });
  process.exit(1);
}

var mapping = found.pad;
var behavior = resolveBehavior(mapping);
var normalizedState = state;
if (normalizedState !== 'on' && normalizedState !== 'off' && normalizedState !== 'press') {
  console.error('Invalid state: ' + normalizedState);
  console.error('Use --state on|off|press');
  process.exit(1);
}
if (behavior === 'toggle' && normalizedState === 'press') {
  normalizedState = 'on';
}
if (behavior === 'momentary') {
  normalizedState = 'press';
}

console.log('Mapping: ' + mapping.id + ' (' + behavior + ')');
if (mapping.group) {
  var groupId = null;
  var groupMode = null;
  if (typeof mapping.group === 'string') {
    groupId = mapping.group;
  } else if (mapping.group && mapping.group.id) {
    groupId = mapping.group.id;
    if (mapping.group.mode) groupMode = mapping.group.mode;
    if (mapping.group.exclusive === true) groupMode = 'exclusive';
  }
  if (groupId) {
    var label = groupMode === 'exclusive' ? ' (exclusive)' : '';
    console.log('Group: ' + groupId + label);
  }
  if (groupMode === 'exclusive') {
    console.log('Note: exclusive group implies other pads in this group should turn off.');
  }
}

if (mapping.osc) {
  var osc = mapping.osc;
  var oscArgs = null;
  if (behavior === 'toggle') {
    oscArgs = normalizedState === 'on' ? osc.onArgs : osc.offArgs;
  } else {
    oscArgs = osc.onArgs || osc.args;
  }
  console.log('OSC: ' + osc.address + ' ' + formatOscArgs(oscArgs));
}

if (mapping.midi) {
  var midi = mapping.midi;
  var value = null;
  if (behavior === 'toggle') {
    if (midi.type === 'note') {
      value = normalizedState === 'on' ? midi.onVelocity : midi.offVelocity;
    } else {
      value = normalizedState === 'on' ? midi.onValue : midi.offValue;
    }
  } else {
    if (midi.type === 'note') {
      value = midi.onVelocity;
    } else {
      value = midi.onValue;
    }
  }
  if (value === undefined || value === null) value = 127;
  console.log(formatMidi(mapping, value));
}
