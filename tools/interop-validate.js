#!/usr/bin/env node
'use strict';

var fs = require('fs');
var path = require('path');

function usage() {
  console.log('Usage: node tools/interop-validate.js --file interop.json [--schema interop.schema.json]');
}

function readJson(filePath) {
  var text = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(text);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isIntInRange(value, min, max) {
  return Number.isInteger(value) && value >= min && value <= max;
}

function isOscArg(value) {
  return value === null || typeof value === 'number' || typeof value === 'string' || typeof value === 'boolean';
}

function validateOsc(osc, ctx, errors, warnings, requireOnOff) {
  if (!isObject(osc)) {
    errors.push(ctx + '.osc must be an object');
    return;
  }
  if (typeof osc.address !== 'string' || osc.address.trim() === '') {
    errors.push(ctx + '.osc.address must be a non-empty string');
  }
  var hasArgs = false;
  ['onArgs', 'offArgs', 'args'].forEach(function (key) {
    if (osc[key] === undefined) return;
    hasArgs = true;
    if (!Array.isArray(osc[key])) {
      errors.push(ctx + '.osc.' + key + ' must be an array');
      return;
    }
    for (var i = 0; i < osc[key].length; i++) {
      if (!isOscArg(osc[key][i])) {
        errors.push(ctx + '.osc.' + key + '[' + i + '] must be a scalar (number/string/boolean/null)');
        break;
      }
    }
  });
  if (!hasArgs) {
    errors.push(ctx + '.osc must include args or onArgs');
  }
  if (requireOnOff) {
    if (!Array.isArray(osc.onArgs) || !Array.isArray(osc.offArgs)) {
      errors.push(ctx + '.osc must include onArgs and offArgs for toggle mappings');
    }
  }
  if (osc.args !== undefined && osc.onArgs === undefined && requireOnOff) {
    warnings.push(ctx + '.osc.args is allowed but toggles should use onArgs/offArgs');
  }
}

function validateMidi(midi, ctx, errors) {
  if (!isObject(midi)) {
    errors.push(ctx + '.midi must be an object');
    return;
  }
  if (typeof midi.type !== 'string' || (midi.type !== 'note' && midi.type !== 'cc')) {
    errors.push(ctx + '.midi.type must be "note" or "cc"');
  }
  if (!isIntInRange(midi.channel, 1, 16)) {
    errors.push(ctx + '.midi.channel must be an integer 1-16');
  }
  if (midi.type === 'note' && !isIntInRange(midi.note, 0, 127)) {
    errors.push(ctx + '.midi.note must be an integer 0-127');
  }
  if (midi.type === 'cc' && !isIntInRange(midi.cc, 0, 127)) {
    errors.push(ctx + '.midi.cc must be an integer 0-127');
  }
  ['onVelocity', 'offVelocity', 'onValue', 'offValue'].forEach(function (key) {
    if (midi[key] === undefined) return;
    if (!isIntInRange(midi[key], 0, 127)) {
      errors.push(ctx + '.midi.' + key + ' must be an integer 0-127');
    }
  });
}

function validateState(state, ctx, errors) {
  if (!isObject(state)) {
    errors.push(ctx + '.state must be an object');
    return;
  }
  if (state.query !== undefined) {
    if (!isObject(state.query)) {
      errors.push(ctx + '.state.query must be an object');
    } else {
      if (typeof state.query.address !== 'string' || state.query.address.trim() === '') {
        errors.push(ctx + '.state.query.address must be a non-empty string');
      }
      if (state.query.args !== undefined) {
        if (!Array.isArray(state.query.args)) {
          errors.push(ctx + '.state.query.args must be an array');
        } else {
          for (var i = 0; i < state.query.args.length; i++) {
            if (!isOscArg(state.query.args[i])) {
              errors.push(ctx + '.state.query.args[' + i + '] must be a scalar (number/string/boolean/null)');
              break;
            }
          }
        }
      }
    }
  }
  if (state.publish !== undefined) {
    if (!isObject(state.publish)) {
      errors.push(ctx + '.state.publish must be an object');
    } else {
      if (typeof state.publish.address !== 'string' || state.publish.address.trim() === '') {
        errors.push(ctx + '.state.publish.address must be a non-empty string');
      }
      if (state.publish.args !== undefined) {
        if (!Array.isArray(state.publish.args)) {
          errors.push(ctx + '.state.publish.args must be an array');
        } else {
          for (var j = 0; j < state.publish.args.length; j++) {
            if (!isOscArg(state.publish.args[j])) {
              errors.push(ctx + '.state.publish.args[' + j + '] must be a scalar (number/string/boolean/null)');
              break;
            }
          }
        }
      }
    }
  }
}

function validateGroup(group, ctx, errors) {
  if (typeof group === 'string') {
    if (group.trim() === '') {
      errors.push(ctx + '.group must be a non-empty string');
    }
    return;
  }
  if (!isObject(group)) {
    errors.push(ctx + '.group must be a string or object');
    return;
  }
  if (typeof group.id !== 'string' || group.id.trim() === '') {
    errors.push(ctx + '.group.id must be a non-empty string');
  }
  if (group.mode !== undefined && group.mode !== 'exclusive') {
    errors.push(ctx + '.group.mode must be "exclusive" when provided');
  }
  if (group.exclusive !== undefined && typeof group.exclusive !== 'boolean') {
    errors.push(ctx + '.group.exclusive must be a boolean');
  }
}

function determineToggle(pad) {
  if (pad.mode === 'toggle') return true;
  if (pad.mode === 'momentary') return false;
  if (pad.toggle === true) return true;
  if (pad.toggle === false) return false;
  return false;
}

function validatePad(pad, ctx, errors, warnings) {
  if (!isObject(pad)) {
    errors.push(ctx + ' must be an object');
    return;
  }
  if (typeof pad.id !== 'string' || pad.id.trim() === '') {
    errors.push(ctx + '.id must be a non-empty string');
  }
  if (pad.row !== undefined && (!Number.isInteger(pad.row) || pad.row < 0)) {
    errors.push(ctx + '.row must be an integer >= 0');
  }
  if (pad.col !== undefined && (!Number.isInteger(pad.col) || pad.col < 0)) {
    errors.push(ctx + '.col must be an integer >= 0');
  }
  if (pad.toggle !== undefined && typeof pad.toggle !== 'boolean') {
    errors.push(ctx + '.toggle must be a boolean');
  }
  if (pad.mode !== undefined && pad.mode !== 'toggle' && pad.mode !== 'momentary') {
    errors.push(ctx + '.mode must be "toggle" or "momentary"');
  }
  if (!pad.midi && !pad.osc) {
    errors.push(ctx + ' must include midi and/or osc');
  }
  if (pad.group !== undefined) {
    validateGroup(pad.group, ctx, errors);
  }
  var isToggle = determineToggle(pad);
  if (pad.osc) {
    validateOsc(pad.osc, ctx, errors, warnings, isToggle);
  }
  if (pad.midi) {
    validateMidi(pad.midi, ctx, errors);
  }
  if (pad.state) {
    validateState(pad.state, ctx, errors);
  }
}

function validateProfile(profile, ctx, errors, warnings) {
  if (!isObject(profile)) {
    errors.push(ctx + ' must be an object');
    return;
  }
  if (profile.gridSize !== undefined) {
    if (!Array.isArray(profile.gridSize) || profile.gridSize.length !== 2) {
      errors.push(ctx + '.gridSize must be an array of two integers');
    } else {
      for (var i = 0; i < profile.gridSize.length; i++) {
        if (!Number.isInteger(profile.gridSize[i]) || profile.gridSize[i] < 1) {
          errors.push(ctx + '.gridSize[' + i + '] must be an integer >= 1');
        }
      }
    }
  }
  if (!Array.isArray(profile.pads)) {
    errors.push(ctx + '.pads must be an array');
    return;
  }
  for (var j = 0; j < profile.pads.length; j++) {
    validatePad(profile.pads[j], ctx + '.pads[' + j + ']', errors, warnings);
  }
}

function validateRuntime(runtime, ctx, errors) {
  if (!isObject(runtime)) {
    errors.push(ctx + ' must be an object');
    return;
  }

  ['rigTunedMode', 'rig_tuned_mode'].forEach(function (key) {
    if (runtime[key] !== undefined && typeof runtime[key] !== 'boolean') {
      errors.push(ctx + '.' + key + ' must be a boolean');
    }
  });

  ['profile', 'profileId'].forEach(function (key) {
    if (runtime[key] !== undefined && (typeof runtime[key] !== 'string' || runtime[key].trim() === '')) {
      errors.push(ctx + '.' + key + ' must be a non-empty string');
    }
  });

  if (runtime.channels !== undefined) {
    if (!isObject(runtime.channels)) {
      errors.push(ctx + '.channels must be an object');
    } else {
      ['macro', 'analysis'].forEach(function (key) {
        if (runtime.channels[key] !== undefined && !isIntInRange(runtime.channels[key], 1, 16)) {
          errors.push(ctx + '.channels.' + key + ' must be an integer 1-16');
        }
      });
    }
  }

  if (runtime.midi !== undefined) {
    if (!isObject(runtime.midi)) {
      errors.push(ctx + '.midi must be an object');
    } else {
      ['preferredInput', 'preferred_input', 'preferredMidiInput', 'preferred_midi_input'].forEach(function (key) {
        if (runtime.midi[key] !== undefined && (typeof runtime.midi[key] !== 'string' || runtime.midi[key].trim() === '')) {
          errors.push(ctx + '.midi.' + key + ' must be a non-empty string');
        }
      });
      ['macroChannel', 'macro_channel', 'analysisChannel', 'analysis_channel'].forEach(function (key) {
        if (runtime.midi[key] !== undefined && !isIntInRange(runtime.midi[key], 1, 16)) {
          errors.push(ctx + '.midi.' + key + ' must be an integer 1-16');
        }
      });
    }
  }

  if (runtime.osc !== undefined) {
    if (!isObject(runtime.osc)) {
      errors.push(ctx + '.osc must be an object');
    } else {
      ['listenPort', 'listen_port', 'targetPort', 'target_port'].forEach(function (key) {
        if (runtime.osc[key] !== undefined && !isIntInRange(runtime.osc[key], 1, 65535)) {
          errors.push(ctx + '.osc.' + key + ' must be an integer 1-65535');
        }
      });
      ['targetHost', 'target_host'].forEach(function (key) {
        if (runtime.osc[key] !== undefined && (typeof runtime.osc[key] !== 'string' || runtime.osc[key].trim() === '')) {
          errors.push(ctx + '.osc.' + key + ' must be a non-empty string');
        }
      });
    }
  }
}

function validateInterop(doc, schema, errors, warnings) {
  if (!isObject(doc)) {
    errors.push('root must be an object');
    return;
  }
  if (doc.interopVersion !== undefined && typeof doc.interopVersion !== 'string') {
    errors.push('interopVersion must be a string');
  }
  if (doc.runtime !== undefined) {
    validateRuntime(doc.runtime, 'runtime', errors);
  }
  if (!isObject(doc.profiles)) {
    errors.push('profiles must be an object');
    return;
  }
  var keys = Object.keys(doc.profiles);
  if (keys.length === 0) {
    errors.push('profiles must include at least one profile');
    return;
  }
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i];
    validateProfile(doc.profiles[key], 'profiles.' + key, errors, warnings);
  }
}

var args = process.argv.slice(2);
var filePath = null;
var schemaPath = path.resolve(__dirname, '..', 'interop.schema.json');

for (var i = 0; i < args.length; i++) {
  var arg = args[i];
  if (arg === '--help' || arg === '-h') {
    usage();
    process.exit(0);
  }
  if (arg === '--schema') {
    schemaPath = args[++i];
    continue;
  }
  if (arg === '--file') {
    filePath = args[++i];
    continue;
  }
  if (arg.charAt(0) === '-') {
    console.error('Unknown option: ' + arg);
    usage();
    process.exit(1);
  }
  if (!filePath) {
    filePath = arg;
  }
}

if (!filePath) {
  usage();
  process.exit(1);
}

var schema = null;
try {
  schema = readJson(schemaPath);
} catch (err) {
  console.error('Failed to read schema: ' + schemaPath);
  console.error(err.message);
  process.exit(1);
}

var doc = null;
try {
  doc = readJson(filePath);
} catch (err) {
  console.error('Failed to read mappings file: ' + filePath);
  console.error(err.message);
  process.exit(1);
}

var errors = [];
var warnings = [];
validateInterop(doc, schema, errors, warnings);

if (warnings.length) {
  console.warn('Warnings:');
  warnings.forEach(function (message) {
    console.warn('  - ' + message);
  });
}

if (errors.length) {
  console.error('Validation failed:');
  errors.forEach(function (message) {
    console.error('  - ' + message);
  });
  process.exit(1);
}

var padCount = 0;
if (doc && doc.profiles && isObject(doc.profiles)) {
  Object.keys(doc.profiles).forEach(function (key) {
    var profile = doc.profiles[key];
    if (profile && Array.isArray(profile.pads)) {
      padCount += profile.pads.length;
    }
  });
}
console.log('OK: ' + padCount + ' pad(s) validated');
