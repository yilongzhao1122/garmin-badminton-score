#!/usr/bin/env node
'use strict';
// Limited syntax adapter for the SAME Monkey C engine, not a reimplementation.
// Does not check Garmin compiler/API compatibility. No external dependencies.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.join(__dirname, '..');
const original = fs.readFileSync(path.join(root, 'source/ScoreEngine.mc'), 'utf8');
const converted = original
  .replace(/\bself\./g, 'this.')
  .replace(/\bfunction\s+initialize\s*\(/, 'constructor(')
  .replace(/\bfunction\s+(\w+)\s*\(/g, '$1(')
  .replace(/^    var (\w+);$/gm, '    $1;')
  .replace(/\.size\(\)/g, '.length')
  .replace(/\.add\(/g, '.push(');
const context = vm.createContext({Test: {
  assert: value => assert.ok(value),
  assertEqual: (actual, expected) => assert.strictEqual(actual, expected)
}});
vm.runInContext(converted + '\nthis.Engine = ScoreEngine;', context);
const Engine = context.Engine;
const tests = fs.readFileSync(path.join(root, 'source/ScoreTests.mc'), 'utf8')
  .replace(/^import .*;$/gm, '')
  .replace(/\(:test\)/g, '')
  .replace(/\.size\(\)/g, '.length');
vm.runInContext(tests, context);
let passed = 0;
function test(name, run) {
  run();
  passed++;
  process.stdout.write('PASS ' + name + '\n');
}
const json = x => JSON.stringify(x);
const clone = x => JSON.parse(json(x));
const stateAndResults = e => json([e.state, e.results]);
for (const name of ['deuceAndCap', 'thirtyPointCap', 'undoAcrossGameBoundary', 'matchAndRestore', 'lastScorerArrow', 'doublesServeSequence', 'doublesNewGameSetup']) {
  test('same Monkey C test: ' + name, () => assert.equal(context[name]({}), true));
}
test('all possible terminal score pairs, both winners, all presets', () => {
  let pairs = 0;
  for (const [target, cap] of [[21, 30], [15, 21], [11, 15]]) {
    for (let winning = target; winning <= cap; winning++) {
      for (let losing = 0; losing < winning; losing++) {
        const terminal = winning === target ? losing <= target - 2 :
          winning === cap ? losing === winning - 2 || losing === winning - 1 :
          losing === winning - 2;
        if (!terminal) continue;
        for (const winner of [0, 1]) {
          const e = new Engine(target, cap, 1);
          for (let k = 0; k < losing; k++) { assert(e.point(0)); assert(e.point(1)); }
          while (e.state[winner] < winning) assert(e.point(winner));
          assert.equal(e.state[4], 2);
          assert.equal(e.state[winner], winning);
          assert.equal(e.state[1 - winner], losing);
          assert.equal(e.state[2 + winner], 1);
          assert.equal(e.point(0), false);
          assert.equal(e.point(1), false);
          pairs++;
        }
      }
    }
  }
  assert(pairs > 100);
  process.stdout.write('  ' + pairs + ' terminal outcomes checked\n');
});
test('each deuce tie and one-point lead stays live until cap', () => {
  for (const [target, cap] of [[21, 30], [15, 21], [11, 15]]) {
    const e = new Engine(target, cap, 3);
    for (let k = 0; k < cap - 1; k++) {
      e.point(0);
      assert.equal(e.state[4], 0);
      e.point(1);
      assert.equal(e.state[4], 0);
    }
  }
});
test('empty undo and invalid point/server actions do not mutate state', () => {
  const e = new Engine(21, 30, 3);
  const before = json(e.pack());
  assert.equal(e.undo(), false);
  assert.equal(e.point(-1), false);
  assert.equal(e.point(2), false);
  assert.equal(e.nextGame(), false);
  assert.equal(e.setServer(2), false);
  assert.equal(e.setServer(0), false);
  assert.equal(json(e.pack()), before);
  assert(e.setServer(1));
  assert.equal(e.state[5], 1);
  assert(e.undo());
  assert.equal(json(e.pack()), before);
});
test('200 deterministic random matches: save/restore and undo identity', () => {
  let seed = 20261111;
  const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  for (let match = 0; match < 200; match++) {
    let e = new Engine(21, 30, 3);
    const beforeActions = [];
    while (e.state[4] !== 2) {
      beforeActions.push(stateAndResults(e));
      if (e.state[4] === 1) {
        const server = e.state[5];
        assert(e.nextGame());
        assert.equal(e.state[5], server);
        assert.equal(e.state[0] + e.state[1], 0);
      } else {
        const team = random() < 0.5 ? 0 : 1;
        assert(e.point(team));
        assert.equal(e.state[5], team);
        assert(e.state[0] >= 0 && e.state[0] <= 30);
        assert(e.state[1] >= 0 && e.state[1] <= 30);
      }
      assert(e.history.length <= 64);
      const persisted = clone(e.pack());
      const r = new Engine(21, 30, 3);
      assert(r.restore(persisted));
      assert.equal(json(r.pack()), json(e.pack()));
      const undoProbe = new Engine(21, 30, 3);
      assert(undoProbe.restore(clone(e.pack())));
      assert(undoProbe.undo());
      assert.equal(stateAndResults(undoProbe), beforeActions[beforeActions.length - 1]);
      e = r;
    }
    assert(e.results.length === 2 || e.results.length === 3);
    assert(e.state[2] === 2 || e.state[3] === 2);
    for (let n = 0; n < Math.min(64, beforeActions.length); n++) {
      assert(e.undo());
      assert.equal(stateAndResults(e), beforeActions[beforeActions.length - 1 - n]);
    }
    assert.equal(e.undo(), false);
  }
});
test('unsupported or malformed saved state is rejected', () => {
  const e = new Engine(21, 30, 3);
  assert.equal(e.restore(null), false);
  assert.equal(e.restore([]), false);
  const unsupported = clone(e.pack()); unsupported[0] = 100;
  assert.equal(e.restore(unsupported), false);
  const badPoints = clone(e.pack()); badPoints[4][0] = 31;
  assert.equal(e.restore(badPoints), false);
  const tooMuchHistory = clone(e.pack()); tooMuchHistory[6] = Array(65).fill([]);
  assert.equal(e.restore(tooMuchHistory), false);
});
test('compact score archives preserve undo and arrow state', () => {
  const legacy = [1, 21, 30, 3, [1, 1, 0, 0, 0, 1, 1], [],
    [[[0, 0, 0, 0, 0, 0, 1], 0], [[1, 0, 0, 0, 0, 0, 1], 0]]];
  const e = new Engine(21, 30, 3);
  assert(e.restore(clone(legacy)));
  assert.equal(e.state[7], 1);
  assert(e.undo()); assert.equal(e.state[7], 0);
  assert(e.undo()); assert.equal(e.state[7], -1);
  assert.equal(e.pack()[0], 3);
});
test('singles court uses the serving side score, for both teams', () => {
  const e = new Engine(21, 30, 3);
  assert.equal(e.serviceCourt(), 0);
  e.setServer(1); assert.equal(e.serverPlayer(), 2); assert.equal(e.serviceCourt(), 0);
  e.point(1); assert.equal(e.serviceCourt(), 1);
  e.point(0); assert.equal(e.serverPlayer(), 0); assert.equal(e.serviceCourt(), 1);
  e.point(0); assert.equal(e.serviceCourt(), 0);
});
test('doubles fixture tracks receiver changes, takeovers and undo', () => {
  const e = new Engine(21, 30, 3); e.setMatchMode(1); e.configureService(0, 2);
  const sequence = [
    [0, 0, 3, 1], // A1 left -> B2
    [1, 3, 0, 1], // B2 left -> A1
    [1, 3, 1, 0], // B2 right -> A2
    [0, 1, 3, 0], // A2 right -> B2
    [0, 1, 2, 1], // A2 left -> B1
    [1, 2, 1, 1]  // B1 left -> A2
  ];
  for (const [team, server, receiver, court] of sequence) {
    const before = stateAndResults(e); assert(e.point(team));
    assert.equal(e.serverPlayer(), server); assert.equal(e.receiverPlayer(), receiver);
    assert.equal(e.serviceCourt(), court);
    const probe = new Engine(21, 30, 3); assert(probe.restore(clone(e.pack())));
    assert(probe.undo()); assert.equal(stateAndResults(probe), before);
  }
});
test('800 random doubles games match the independent BWF four-player service cycle', () => {
  let seed = 30657, rallies = 0;
  const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  const partner = player => player ^ 1;
  for (let initialServer = 0; initialServer < 4; initialServer++) {
    const receiverStart = initialServer < 2 ? 2 : 0;
    for (let initialReceiver = receiverStart; initialReceiver < receiverStart + 2; initialReceiver++) {
      for (let repeat = 0; repeat < 100; repeat++) {
        let e = new Engine(21, 30, 1); e.setMatchMode(1);
        assert(e.configureService(initialServer, initialReceiver));
        const cycle = [initialServer, partner(initialReceiver), partner(initialServer), initialReceiver];
        let turn = 0;
        const oracle = () => {
          const server = cycle[turn % 4];
          const team = server < 2 ? 0 : 1;
          const court = e.state[team] % 2;
          const nextOpponentServer = cycle[(turn + 1) % 4];
          const opponentNextCourt = (e.state[1 - team] + 1) % 2;
          const receiver = court === opponentNextCourt ? nextOpponentServer : partner(nextOpponentServer);
          assert.equal(e.serverPlayer(), server);
          assert.equal(e.receiverPlayer(), receiver);
          assert.equal(e.serviceCourt(), court);
          assert.equal(e.state[5], team);
        };
        oracle();
        while (e.state[4] === 0) {
          const team = random() < 0.5 ? 0 : 1;
          const previousTeam = e.state[5];
          const before = stateAndResults(e);
          assert(e.point(team)); rallies++;
          if (team !== previousTeam) turn++;
          oracle();
          const r = new Engine(21, 30, 3); assert(r.restore(clone(e.pack())));
          const probe = new Engine(21, 30, 3); assert(probe.restore(clone(e.pack())));
          assert(probe.undo()); assert.equal(stateAndResults(probe), before);
          e = r;
        }
      }
    }
  }
  process.stdout.write('  ' + rallies + ' rallies checked against the independent cycle\n');
});
test('each new doubles game requires a setup; winner may choose either player', () => {
  const e = new Engine(21, 30, 3); e.setMatchMode(1); e.configureService(2, 0);
  for (let n = 0; n < 21; n++) e.point(1);
  assert(e.nextGame()); assert.equal(e.serveReady(), false);
  const pending = json(e.pack()); assert.equal(e.point(1), false);
  assert.equal(e.configureService(0, 2), false); assert.equal(json(e.pack()), pending);
  assert(e.configureService(3, 1)); assert.equal(e.serverPlayer(), 3); assert.equal(e.receiverPlayer(), 1);
  assert(e.undo()); assert.equal(e.serveReady(), false);
  assert(e.undo()); assert.equal(e.state[4], 1); assert.equal(e.serveReady(), true);
});
test('court correction keeps score and is reversible with lineup and arrow restored', () => {
  const e = new Engine(21, 30, 3); e.setMatchMode(1); e.configureService(0, 2); e.point(0);
  const before = stateAndResults(e), points = json(e.state.slice(0, 8));
  const server = e.serverPlayer(), receiver = e.receiverPlayer();
  assert(e.swapCourts(0)); assert.equal(e.serverPlayer(), server ^ 1);
  assert.equal(json(e.state.slice(0, 8)), points); assert(e.undo());
  assert.equal(stateAndResults(e), before);
  assert(e.swapCourts(1)); assert.equal(e.receiverPlayer(), receiver ^ 1); assert(e.undo());
  assert.equal(stateAndResults(e), before);
});
test('invalid and mid-game service setup cannot change a live match', () => {
  const e = new Engine(21, 30, 3); e.setMatchMode(1);
  assert.equal(e.configureService(0, 1), false);
  assert.equal(e.configureService(1.5, 2), false);
  assert(e.configureService(0, 2)); e.point(1);
  const before = json(e.pack());
  assert.equal(e.configureService(0, 2), false); assert.equal(e.setServer(0), false);
  assert.equal(e.setMatchMode(0), false); assert.equal(json(e.pack()), before);
});
test('compact archives restore singles without inventing a doubles lineup', () => {
  const legacy = [2, 21, 30, 3, [1, 0, 0, 0, 0, 0, 1, 0], [],
    [[[0, 0, 0, 0, 0, 0, 1, -1], 0]]];
  const e = new Engine(21, 30, 3); assert(e.restore(clone(legacy)));
  assert.equal(e.isDoubles(), false); assert.equal(e.serviceCourt(), 1); assert(e.undo());
  assert.equal(e.state[7], -1);
});
test('malformed lineup/history is rejected without partially changing the match', () => {
  const e = new Engine(21, 30, 3); e.point(0); const before = json(e.pack());
  const bad = clone(e.pack()); bad[4][10] = 0;
  assert.equal(e.restore(bad), false); assert.equal(json(e.pack()), before);
  const badHistory = clone(e.pack()); badHistory[6][0][0][8] = 2;
  assert.equal(e.restore(badHistory), false); assert.equal(json(e.pack()), before);
});
process.stdout.write('\n' + passed + ' compatibility checks passed. Garmin SDK compilation and device tests NOT RUN.\n');
