// -*- coding: utf-8, tab-width: 2 -*-

import fs from 'node:fs';
import readline from 'node:readline';

function oppoOarseJson(x) { try { return JSON.parse(x); } catch { ; } }
function ifObj(x, d) { return ((x && typeof x) === 'object' ? x : d); }
function isStr(x, no) { return (((typeof x) === 'string') || no); }


const EX = {

  cliMain() {
    const stdin = readline.createInterface({ input: process.stdin });
    stdin.on('line', EX.eachLine);
    stdin.on('close', EX.cleanup);
  },

  cleanup() {
    EX.switchFragmentsChannel('');
  },

  prevRec: false,
  fragKeyPrefix: 'choices.0.delta.',
  previouslyGluedFragKey: '',

  gluedFragmentsLog: (function maybeOpen() {
    const destFn = process.env.SSE_GLUED_FRAGMENTS_LOG;
    if (!destFn) { return false; }
    const stm = fs.createWriteStream(destFn, { encoding: 'utf8', flags: 'a' });
    stm.write('\uFEFF\n');
    return stm;
  }()),

  eachLine(orig) {
    let ln = orig.replace(/\r$/, '');
    if (!ln) { return; }
    const splat = ln.split(/^(\w+:\s*)|^(\W)(?=")/);
    const pre = splat[1] || '';
    // const stringTag = splat[2];
    if (pre) { ln = splat[3]; }
    try {
      ln = JSON.parse(ln);
    } catch {
      return console.log(orig);
    }
    if (!ifObj(ln)) { return console.log(orig); }

    ln = EX.flattenDict(ln);
    EX.maybePopAddFrag(ln, 'content');
    EX.maybePopAddFrag(ln, 'reasoning');
    const upd = {};
    Object.entries(ln).forEach(function copy([k, v]) {
      if (v !== EX.prevRec[k]) { upd[k] = v; }
    });
    EX.prevRec = ln;

    const keyCount = Object.keys(upd).length;
    if (keyCount === 0) {
      ln = '{=}';
    } else {
      ln = JSON.stringify(upd, null, 2);
      ln = ln.replace(/,\n/g, '\n');
      if (keyCount === 1) { ln = ln.replace(/\n */g, ' '); }
      ln = ln.slice(0, 1) + '±' + ln.slice(1, -1) + '±' + ln.slice(-1);
    }
    console.log(pre + ln);
  },

  flattenDict(orig) {
    if (!ifObj(orig)) { return orig; }
    const flat = {};
    (function add(o, p) {
      Object.entries(o).forEach(function copy([k, v]) {
        if (isStr(v) && v.startsWith('{"')) {
          const j = oppoOarseJson(v);
          if (j) { return add(j, p + k + '›'); }
        }
        if (ifObj(v)) { return add(v, p + k + '.'); }
        flat[p + k] = v;
      });
    }(orig, ''));
    return flat;
  },

  maybePopAddFrag(ln, fragKey) {
    const k = EX.fragKeyPrefix + fragKey;
    const v = ln[k];
    if (!v) { return; }
    delete ln[k]; // eslint-disable-line no-param-reassign
    EX.switchFragmentsChannel(fragKey);
    console.log('+' + JSON.stringify(v));
    if (EX.gluedFragmentsLog) { EX.gluedFragmentsLog.write(v); }
  },

  switchFragmentsChannel(crnt) {
    const prev = EX.previouslyGluedFragKey;
    if (crnt === prev) { return; }
    EX.previouslyGluedFragKey = crnt;
    console.log('+:' + (prev || 'NONE') + ':' + crnt);
    const glued = EX.gluedFragmentsLog;
    if (!glued) { return; }
    if (prev) { glued.write('\n</details><!-- /frag:' + prev + ' -->\n'); }
    if (crnt) {
      glued.write('<details class="frag ' + crnt + '"><summary>'
        + crnt + '</summary>\n');
    }
  },


};


EX.cliMain();
