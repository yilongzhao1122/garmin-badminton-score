// Match timing is independent of FIT recording. No score/rotation rules here.
// Game timers exclude between-game breaks; match time includes those breaks.
// Both exclude an explicit activity pause. Restoring never counts app downtime.
class MatchReport {
    var started = false;
    var running = false;
    var gameRunning = false;
    var totalMs = 0;
    var gameMs;
    var lastTick = 0;
    var known = true;

    function initialize() { gameMs = [0, 0, 0]; }
    function begin(now) {
        started = true; running = true; gameRunning = true; lastTick = now;
    }
    function tick(now, paused, engine) {
        if (running && now >= lastTick && !paused && engine.state[4] != 2) {
            var delta = now - lastTick;
            totalMs += delta;
            var index = engine.state[6] - 1;
            if (gameRunning && engine.state[4] == 0 && index >= 0 && index < 3) { gameMs[index] += delta; }
        }
        lastTick = now;
    }
    function reconcile(engine) {
        // Undo across NEXT GAME removes the abandoned next-game timer.
        for (var i = engine.state[6]; i < 3; i += 1) { gameMs[i] = 0; }
    }
    function pack() { return [1, started, totalMs, [gameMs[0],gameMs[1],gameMs[2]], known]; }
    function restore(data, now, legacyActive) {
        lastTick = now; running = false;
        if (data == null) { started = legacyActive; known = !legacyActive; return; }
        if (data.size() != 5 || data[0] != 1 || data[2] < 0 || data[3].size() != 3) {
            started = legacyActive; known = false; return;
        }
        for (var i = 0; i < 3; i += 1) {
            if (data[3][i] < 0) { started = legacyActive; known = false; return; }
        }
        started = data[1] == true; totalMs = data[2];
        gameMs = [data[3][0],data[3][1],data[3][2]]; known = data[4] == true;
    }
    function rows(engine) {
        var rows = [];
        for (var i = 0; i < engine.results.size(); i += 1) {
            rows.add([engine.results[i][0],engine.results[i][1],(gameMs[i] / 1000).toNumber(),true]);
        }
        if (engine.state[4] == 0 && (gameRunning || gameMs[engine.state[6] - 1] > 0 || engine.state[0] + engine.state[1] > 0)) {
            var index = engine.state[6] - 1;
            rows.add([engine.state[0],engine.state[1],(gameMs[index] / 1000).toNumber(),false]);
        }
        return rows;
    }
}
