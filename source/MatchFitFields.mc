import Toybox.FitContributor;

// Stable field IDs also appear in resources/contributions/fitcontributions.xml.
// Optional compact exporter: 13 SESSION fields, 25 bytes, no chart fields.
// Disabled by default in GarminRecordingBackend. Field count AND byte limits
// depend on the device/profile. Never probe a limit by allocating until failure.
// No personal shot attribution: score buttons identify the winning TEAM only.
class MatchFitFields {
    var fields;
    function initialize(session) {
        fields = [];
        var names = ["match_mode","point_target","games_a","games_b","match_seconds","match_state",
            "game1_a","game1_b","game1_seconds","game2_a","game2_b","game2_seconds",
            "game3_a","game3_b","game3_seconds","games_played","timing_complete"];
        for (var i = 4; i < names.size(); i += 1) {
            var duration = i == 4 || i == 8 || i == 11 || i == 14;
            fields.add(session.createField(names[i], i,
                duration ? FitContributor.DATA_TYPE_UINT32 : FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => duration ? "s" : ""}));
        }
    }
    function updateScore(engine) {}
    function writeSummary(engine, report, ended) {
        var rows = report.rows(engine);
        var values = [engine.isDoubles() ? 2 : 1,engine.target,engine.state[2],engine.state[3],
            (report.totalMs / 1000).toNumber(),engine.state[4] == 2 ? 1 : (ended ? 2 : 0),
            0,0,0,0,0,0,0,0,0,rows.size(),report.known ? 1 : 0];
        for (var i = 0; i < rows.size() && i < 3; i += 1) {
            values[6 + i * 3] = rows[i][0]; values[7 + i * 3] = rows[i][1]; values[8 + i * 3] = rows[i][2];
        }
        for (var j = 0; j < fields.size(); j += 1) { fields[j].setData(values[j + 4]); }
    }
}
