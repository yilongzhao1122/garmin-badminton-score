// Bounded, replace-by-game checkpoints. The scoring engine keeps its own
// mandatory match state even when the user declines a separate game checkpoint.
class GameCheckpoints {
    var choices;
    var snapshots;
    function initialize() { choices = [-1,-1,-1]; snapshots = [null,null,null]; }
    function pack() {
        return [1,[choices[0],choices[1],choices[2]],
            [snapshots[0],snapshots[1],snapshots[2]]];
    }
    function restore(data) {
        if (data == null || data.size() != 3 || data[0] != 1 ||
            data[1].size() != 3 || data[2].size() != 3) { return false; }
        for (var i = 0; i < 3; i += 1) {
            if (data[1][i] != -1 && data[1][i] != 0 && data[1][i] != 1) { return false; }
            if (data[1][i] == 1 && (data[2][i] == null || data[2][i].size() != 4 ||
                data[2][i][0] < 0 || data[2][i][1] < 0 || data[2][i][2] < 0)) { return false; }
        }
        choices = [data[1][0],data[1][1],data[1][2]];
        snapshots = [null,null,null];
        for (var j = 0; j < 3; j += 1) {
            if (choices[j] == 1) {
                snapshots[j] = [data[2][j][0],data[2][j][1],data[2][j][2],data[2][j][3] == true];
            }
        }
        return true;
    }
    function setGame(index, keep, engine, report) {
        if (index < 0 || index >= 3 || index >= engine.results.size()) { return false; }
        choices[index] = keep ? 1 : 0;
        snapshots[index] = keep ? [engine.results[index][0],engine.results[index][1],
            report.gameMs[index],report.known] : null;
        return true;
    }
    function includeCompleted(engine, report) {
        for (var i = 0; i < engine.results.size(); i += 1) { self.setGame(i,true,engine,report); }
    }
    function reconcile(engine) {
        for (var i = 0; i < 3; i += 1) {
            var invalid = i >= engine.results.size();
            if (!invalid && choices[i] == 1) {
                invalid = snapshots[i][0] != engine.results[i][0] || snapshots[i][1] != engine.results[i][1];
            }
            if (invalid) { choices[i] = -1; snapshots[i] = null; }
        }
    }
}
