import Toybox.Activity;
import Toybox.Lang;

// Only device-provided activity data. Keep the last summary after a successful
// save, reset it when a new activity/match starts; never fabricate zero values.
class PerformanceStats {
    var heartRate as Lang.Number or Null = null;
    var averageHeartRate as Lang.Number or Null = null;
    var maxHeartRate as Lang.Number or Null = null;
    var calories as Lang.Number or Null = null;

    function initialize() {}

    function reset() {
        self.heartRate = null;
        self.averageHeartRate = null;
        self.maxHeartRate = null;
        self.calories = null;
    }

    function capture(info as Activity.Info or Null) as Void {
        if (info == null) { self.heartRate = null; return; }
        self.heartRate = info.currentHeartRate;
        if (info.averageHeartRate != null) { self.averageHeartRate = info.averageHeartRate; }
        if (info.maxHeartRate != null) { self.maxHeartRate = info.maxHeartRate; }
        if (info.calories != null) { self.calories = info.calories; }
    }
}
