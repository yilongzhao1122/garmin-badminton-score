import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.System;

// Stable default: ordinary FIT recording only. Some createField() failures
// are fatal VM errors, so a try/catch is not a safe runtime feature probe.
const ENABLE_MATCH_FIT_EXPORT = false;

class GarminRecordingBackend {
    var matchFields = null;
    var fitEnabled = ENABLE_MATCH_FIT_EXPORT;
    var lastExportError = "";
    function initialize() {}

    function now() { return System.getTimer(); }

    function createSession() {
        matchFields = null; lastExportError = "";
        // The public API available on this target does not expose a badminton
        // enum. Use GENERIC honestly, with a Badminton activity name.
        // Sport naming alone does not add native training-effect algorithms.
        var session = ActivityRecording.createSession({
            :name => "羽毛球",
            :sport => Activity.SPORT_GENERIC,
            :subSport => Activity.SUB_SPORT_GENERIC
        });
        if (session == null) { return null; }
        // No developer-field allocation at all in the stable configuration.
        if (fitEnabled) {
            try { matchFields = new MatchFitFields(session); }
            catch (e) {
                // A catchable extension error must not discard the ordinary
                // session. Fatal VM errors cannot be caught here.
                matchFields = null; lastExportError = "比分扩展不可用";
            }
        }
        return session;
    }

    function updateScore(engine) { if (matchFields != null) { matchFields.updateScore(engine); } }
    function writeSummary(engine, report, ended) {
        if (matchFields != null) { matchFields.writeSummary(engine, report, ended); }
    }

    function info() { return Activity.getActivityInfo(); }
}
