import Toybox.Test;

(:test)
function courtPerspectiveRegression(logger) {
    Test.assertEqual(badmintonCourtColumn(0, 0), 1);
    Test.assertEqual(badmintonCourtColumn(0, 1), 0);
    Test.assertEqual(badmintonCourtColumn(1, 0), 0);
    Test.assertEqual(badmintonCourtColumn(1, 1), 1);
    Test.assertEqual(badmintonCourtColumn(2, 0), -1);
    Test.assertEqual(badmintonCourtY(0), 188);
    Test.assertEqual(badmintonCourtY(1), 112);
    return true;
}

(:test)
function singlesCourtRegression(logger) {
    var e = new ScoreEngine(21, 30, 3);
    Test.assertEqual(badmintonCourtX(0, e.serviceCourt()), 168);
    Test.assertEqual(badmintonCourtX(1, e.serviceCourt()), 112);
    e.point(1);
    Test.assertEqual(e.serverPlayer(), 2);
    Test.assertEqual(badmintonCourtX(1, e.serviceCourt()), 168);
    e.point(1);
    Test.assertEqual(badmintonCourtX(1, e.serviceCourt()), 112);
    return true;
}

(:test)
function doublesCourtRegression(logger) {
    var e = new ScoreEngine(21, 30, 3);
    e.setMatchMode(1); e.configureService(0, 2);
    e.point(0);
    Test.assertEqual(e.serverPlayer(), 0);
    Test.assertEqual(e.receiverPlayer(), 3);
    Test.assertEqual(badmintonCourtX(0, e.serviceCourt()), 112);
    e.point(1);
    Test.assertEqual(e.serverPlayer(), 3);
    Test.assertEqual(e.receiverPlayer(), 0);
    Test.assertEqual(badmintonCourtX(1, e.serviceCourt()), 168);
    e.undo();
    Test.assertEqual(e.serverPlayer(), 0);
    Test.assertEqual(e.playerAtCourt(0, 1), 0);
    return true;
}
