#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(path.join(__dirname, '../source/RecordingController.mc'), 'utf8')
  .replace(/\bself\./g, 'this.')
  .replace(/\bfunction\s+initialize\s*\(/, 'constructor(')
  .replace(/\bfunction\s+(\w+)\s*\(/g, '$1(')
  .replace(/^    var (\w+)(\s*=\s*[^;]+)?;$/gm, '    $1$2;');
const Controller = vm.runInNewContext(source + '\nRecordingController;');
function fixture() {
  const session = {
    active: false, starts: 0, stops: 0, saves: 0, discards: 0,
    failStart: false, failStop: false, failSave: false, failDiscard: false,
    isRecording() { return this.active; },
    start() { this.starts++; if (this.failStart) return false; this.active = true; return true; },
    stop() { this.stops++; if (this.failStop) return false; this.active = false; return true; },
    save() { this.saves++; return !this.failSave; },
    discard() { this.discards++; return !this.failDiscard; }
  };
  const backend = {time: 100, creates: 0, createSession() { this.creates++; return session; }, now() { return this.time; }};
  return {session, backend, recorder: new Controller(backend)};
}
let passed = 0;
function test(name, fn) { fn(); passed++; process.stdout.write('PASS ' + name + '\n'); }
test('pause excludes break time; resume and save retain one session', () => {
  const {session:s, backend:b, recorder:r} = fixture();
  assert(r.start()); b.time += 10000; assert(r.pause());
  assert.equal(r.elapsedMs, 10000); b.time += 120000; r.refresh();
  assert.equal(r.elapsedMs, 10000); assert(r.resume()); b.time += 5000;
  assert(r.finish()); assert.equal(r.elapsedMs, 15000);
  assert.equal(b.creates, 1); assert.equal(s.saves, 1); assert.equal(r.status, 3);
  assert(r.finish()); assert.equal(s.saves, 1); // no duplicate FIT
});
test('failed save keeps session paused for retry; never reports saved', () => {
  const {session:s, recorder:r} = fixture(); assert(r.start()); s.failSave = true;
  assert.equal(r.finish(), false); assert(r.hasSession()); assert.equal(r.status, 2);
  assert.equal(r.lastError, '运动保存失败'); s.failSave = false;
  assert(r.finish()); assert.equal(r.hasSession(), false); assert.equal(r.status, 3);
});
test('stop failure does not save or discard a live session', () => {
  const {session:s, recorder:r} = fixture(); assert(r.start()); s.failStop = true;
  assert.equal(r.finish(), false); assert.equal(r.status, 1); assert.equal(s.saves, 0);
  assert.equal(r.discard(), false); assert.equal(s.discards, 0);
});
test('duplicate start and score-only reset cannot overwrite active recording', () => {
  const {backend:b, recorder:r} = fixture(); assert(r.start());
  assert.equal(r.start(), false); assert.equal(r.scoreOnly(), false); assert.equal(b.creates, 1);
});
test('failed initial start retains session for resume or discard', () => {
  const {session:s, recorder:r} = fixture(); s.failStart = true;
  assert.equal(r.start(), false); assert.equal(r.status, 2); assert(r.hasSession());
  s.failStart = false; assert(r.resume()); assert.equal(r.status, 1); assert(r.discard());
  assert.equal(r.status, 0); assert.equal(r.elapsedMs, 0);
});
test('failed discard retains paused recording', () => {
  const {session:s, recorder:r} = fixture(); assert(r.start()); s.failDiscard = true;
  assert.equal(r.discard(), false); assert(r.hasSession()); assert.equal(r.status, 2);
});
test('backend creation exception is visible and can be retried', () => {
  const {backend:b, session:s, recorder:r} = fixture();
  b.createSession = () => { throw Error('unavailable'); };
  assert.equal(r.start(), false); assert.equal(r.hasSession(), false); assert.equal(r.status, 0);
  assert.equal(r.lastError, '运动开始异常'); b.createSession = () => s; assert(r.start());
});
test('save exception retains session and never claims success', () => {
  const {session:s, recorder:r} = fixture(); assert(r.start());
  s.save = () => { throw Error('disk'); }; assert.equal(r.finish(), false);
  assert(r.hasSession()); assert.equal(r.status, 2); assert.equal(r.lastError, '运动保存异常');
});
test('never-started session cannot report FIT saved', () => {
  const {session:s, recorder:r}=fixture();s.failStart=true;assert.equal(r.start(),false);
  assert.equal(r.finish(),false);assert.equal(r.lastError,'尚未记录');assert.equal(s.saves,0);
  s.failStart=false;assert(r.resume());assert(r.finish());assert.equal(s.saves,1);
});
test('externally stopped session can still be saved without redundant stop failure',()=>{
  const {session:s,recorder:r}=fixture();assert(r.start());s.active=false;s.failStop=true;
  assert(r.finish());assert.equal(s.stops,0);assert.equal(s.saves,1);
});
process.stdout.write('\n' + passed + ' recording lifecycle checks passed with mock sessions; Garmin API/sensors/sync NOT TESTED.\n');
