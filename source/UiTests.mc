import Toybox.Test;
import Toybox.WatchUi;

(:test)
function numericMenuIdRegression(logger) {
    var numeric = new WatchUi.MenuItem("A1", null, 0, {});
    var textual = new WatchUi.MenuItem("Cancel", null, "cancel", {});
    Test.assertEqual(badmintonMenuNumber(numeric), 0);
    Test.assertEqual(badmintonMenuNumber(textual), -99);
    return true;
}

(:test)
function clockTextRegression(logger) {
    Test.assertEqual(badmintonClockText(7, 5, 9), "07:05:09");
    Test.assertEqual(badmintonClockText(0, 0, 0), "00:00:00");
    Test.assertEqual(badmintonClockText(23, 59, 59), "23:59:59");
    return true;
}
