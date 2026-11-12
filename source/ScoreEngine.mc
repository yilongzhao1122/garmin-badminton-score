// The watch and regression tests use this same scoring implementation.
// State: points A/B, games A/B, phase (0 play, 1 game over, 2 match over),
// serving team, game number, last scorer, mode (0 singles / 1 doubles),
// right-court player A (0/1), right-court player B (2/3), serve setup ready.
// Player IDs: 0=A1 (wearer), 1=A2 (partner), 2=B1, 3=B2.
class ScoreEngine {
    var target;
    var cap;
    var bestOf;
    var state;
    var results;
    var history;

    function initialize(targetPoints, capPoints, matchGames) {
        self.target = targetPoints;
        self.cap = capPoints;
        self.bestOf = matchGames;
        self.state = [0, 0, 0, 0, 0, 0, 1, -1, 0, 0, 2, 1];
        self.results = [];
        self.history = [];
    }

    function copyState(s) {
        return [s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7],
                s[8], s[9], s[10], s[11]];
    }

    function isDoubles() { return self.state[8] == 1; }
    function serveReady() { return self.state[11] == 1; }

    // Set mode on a fresh match, never infer a doubles lineup from old scores.
    function setMatchMode(mode) {
        if ((mode != 0 && mode != 1) || self.history.size() != 0 ||
            self.results.size() != 0 || self.state[0] != 0 ||
            self.state[1] != 0 || self.state[6] != 1) { return false; }
        self.state[8] = mode;
        self.state[11] = mode == 1 ? 0 : 1;
        return true;
    }

    function partnerOf(player) {
        return player < 2 ? 1 - player : 5 - player;
    }

    // R/L means each player's own right/left while facing the net.
    // Both the server and diagonal receiver occupy their own R or own L.
    function serviceCourt() { return self.state[self.state[5]] % 2; }

    function playerAtCourt(team, court) {
        if (!self.isDoubles()) { return team == 0 ? 0 : 2; }
        var rightPlayer = team == 0 ? self.state[9] : self.state[10];
        return court == 0 ? rightPlayer : self.partnerOf(rightPlayer);
    }

    function serverPlayer() {
        if (!self.serveReady()) { return -1; }
        return self.playerAtCourt(self.state[5], self.serviceCourt());
    }

    function receiverPlayer() {
        if (!self.serveReady()) { return -1; }
        return self.playerAtCourt(1 - self.state[5], self.serviceCourt());
    }

    function configureService(server, receiver) {
        if (!self.isDoubles() || self.state[4] != 0 ||
            self.state[0] != 0 || self.state[1] != 0 ||
            (server != 0 && server != 1 && server != 2 && server != 3) ||
            (receiver != 0 && receiver != 1 && receiver != 2 && receiver != 3)) { return false; }
        var team = server < 2 ? 0 : 1;
        var receiverTeam = receiver < 2 ? 0 : 1;
        if (team == receiverTeam) { return false; }
        // After game 1, the previous game winner must serve first (BWF 7.6).
        if (self.state[6] > 1 && team != self.state[5]) { return false; }
        var rightA = team == 0 ? server : receiver;
        var rightB = team == 1 ? server : receiver;
        if (self.serveReady() && self.state[5] == team &&
            self.state[9] == rightA && self.state[10] == rightB) { return true; }
        self.remember();
        self.state[5] = team;
        self.state[9] = rightA;
        self.state[10] = rightB;
        self.state[11] = 1;
        return true;
    }

    // Explicit correction of the CURRENT rally. The score, games and last
    // scoring arrow remain unchanged. Subsequent rotation uses this lineup.
    function editService(server, receiver) {
        if (self.state[4] != 0 || server < 0 || server > 3 || receiver < 0 || receiver > 3) { return false; }
        var team = server < 2 ? 0 : 1;
        if ((receiver < 2 ? 0 : 1) == team) { return false; }
        if (!self.isDoubles() && ((server != 0 && server != 2) || (receiver != 0 && receiver != 2))) { return false; }
        var rightA = self.state[9];
        var rightB = self.state[10];
        if (self.isDoubles()) {
            var court = self.state[team] % 2;
            var rightServer = court == 0 ? server : self.partnerOf(server);
            var rightReceiver = court == 0 ? receiver : self.partnerOf(receiver);
            rightA = team == 0 ? rightServer : rightReceiver;
            rightB = team == 1 ? rightServer : rightReceiver;
        }
        if (self.serveReady() && self.state[5] == team && self.state[9] == rightA && self.state[10] == rightB) { return true; }
        self.remember();
        self.state[5] = team;
        self.state[9] = rightA;
        self.state[10] = rightB;
        self.state[11] = 1;
        return true;
    }

    // Explicit correction of remembered positions; the existing score stands.
    function swapCourts(team) {
        if (!self.isDoubles() || !self.serveReady() || self.state[4] != 0 ||
            (team != 0 && team != 1)) { return false; }
        self.remember();
        var index = team == 0 ? 9 : 10;
        self.state[index] = self.partnerOf(self.state[index]);
        return true;
    }

    function remember() {
        // 64 actions keep storage and heap bounded. Include next-game and
        // server-selection actions so undo works across a game boundary.
        var keep = [];
        var start = 0;
        if (self.history.size() >= 64) {
            start = self.history.size() - 63;
        }
        for (var i = start; i < self.history.size(); i += 1) {
            keep.add(self.history[i]);
        }
        keep.add([self.copyState(self.state), self.results.size()]);
        self.history = keep;
    }

    function point(team) {
        if ((team != 0 && team != 1) || self.state[4] != 0 || !self.serveReady()) {
            return false;
        }
        self.remember();
        // A serving-side win keeps the same server, swapping only that side's
        // service courts. A receiving-side win changes service without a swap.
        if (self.isDoubles() && team == self.state[5]) {
            var rightIndex = team == 0 ? 9 : 10;
            self.state[rightIndex] = self.partnerOf(self.state[rightIndex]);
        }
        self.state[team] += 1;
        self.state[5] = team;
        self.state[7] = team;
        var other = 1 - team;
        var won = self.state[team] >= self.cap ||
            (self.state[team] >= self.target &&
             self.state[team] - self.state[other] >= 2);
        if (won) {
            self.state[2 + team] += 1;
            self.results.add([self.state[0], self.state[1]]);
            self.state[4] = 1;
            if (self.state[2 + team] * 2 > self.bestOf) {
                self.state[4] = 2;
            }
        }
        return true;
    }

    function nextGame() {
        if (self.state[4] != 1) {
            return false;
        }
        self.remember();
        self.state[0] = 0;
        self.state[1] = 0;
        self.state[4] = 0;
        self.state[6] += 1;
        self.state[7] = -1;
        self.state[11] = self.isDoubles() ? 0 : 1;
        // Last rally winner serves first in the following game.
        return true;
    }

    function setServer(team) {
        if (self.isDoubles() || (team != 0 && team != 1) || self.state[4] != 0 ||
            self.state[0] != 0 || self.state[1] != 0 ||
            self.state[5] == team) {
            return false;
        }
        self.remember();
        self.state[5] = team;
        return true;
    }

    function undo() {
        var n = self.history.size();
        if (n == 0) {
            return false;
        }
        var snapshot = self.history[n - 1];
        self.state = self.copyState(snapshot[0]);
        var trimmed = [];
        for (var i = 0; i < snapshot[1]; i += 1) {
            trimmed.add(self.results[i]);
        }
        self.results = trimmed;
        var previous = [];
        for (var j = 0; j < n - 1; j += 1) {
            previous.add(self.history[j]);
        }
        self.history = previous;
        return true;
    }

    // Packed primitives only, to keep persistence small and portable.
    function pack() {
        return [3, self.target, self.cap, self.bestOf,
                self.copyState(self.state), self.results, self.history];
    }

    function upgradeState(s, version) {
        if (version == 3) { return self.copyState(s); }
        var scorer = version == 1 ? (s[0] + s[1] > 0 ? s[5] : -1) : s[7];
        // Legacy games have no four-player lineup: migrate honestly to singles.
        return [s[0], s[1], s[2], s[3], s[4], s[5], s[6], scorer, 0, 0, 2, 1];
    }

    function validState(s, ceiling, games) {
        if (s.size() != 12 || s[0] < 0 || s[1] < 0 || s[0] > ceiling ||
            s[1] > ceiling || s[2] < 0 || s[3] < 0 ||
            s[2] + s[3] > games || s[4] < 0 || s[4] > 2 ||
            (s[5] != 0 && s[5] != 1) || s[6] < 1 || s[6] > games ||
            s[7] < -1 || s[7] > 1 || (s[8] != 0 && s[8] != 1) ||
            (s[9] != 0 && s[9] != 1) || (s[10] != 2 && s[10] != 3) ||
            (s[11] != 0 && s[11] != 1)) { return false; }
        if (s[8] == 0 && s[11] != 1) { return false; }
        if (s[11] == 0 && s[0] + s[1] != 0) { return false; }
        return true;
    }

    function restore(data) {
        if (data == null || data.size() != 7 ||
            (data[0] != 1 && data[0] != 2 && data[0] != 3)) { return false; }
        if (!((data[1] == 21 && data[2] == 30) ||
              (data[1] == 15 && data[2] == 21) ||
              (data[1] == 11 && data[2] == 15))) { return false; }
        if (data[3] != 1 && data[3] != 3) { return false; }
        var expectedSize = data[0] == 1 ? 7 : (data[0] == 2 ? 8 : 12);
        if (data[4].size() != expectedSize || data[5].size() > data[3] ||
            data[6].size() > 64) { return false; }
        var nextState = self.upgradeState(data[4], data[0]);
        if (!self.validState(nextState, data[2], data[3]) ||
            nextState[2] + nextState[3] != data[5].size()) { return false; }
        var nextResults = [];
        for (var i = 0; i < data[5].size(); i += 1) {
            var result = data[5][i];
            if (result.size() != 2 || result[0] < 0 || result[1] < 0 ||
                result[0] > data[2] || result[1] > data[2]) { return false; }
            nextResults.add([result[0], result[1]]);
        }
        var nextHistory = [];
        for (var j = 0; j < data[6].size(); j += 1) {
            var snapshot = data[6][j];
            if (snapshot.size() != 2 || snapshot[0].size() != expectedSize ||
                snapshot[1] < 0 || snapshot[1] > nextResults.size()) { return false; }
            var historicalState = self.upgradeState(snapshot[0], data[0]);
            if (!self.validState(historicalState, data[2], data[3]) ||
                historicalState[2] + historicalState[3] != snapshot[1]) { return false; }
            nextHistory.add([historicalState, snapshot[1]]);
        }
        self.target = data[1];
        self.cap = data[2];
        self.bestOf = data[3];
        self.state = nextState;
        self.results = nextResults;
        self.history = nextHistory;
        return true;
    }
}
