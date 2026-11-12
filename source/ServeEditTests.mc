import Toybox.Test;

(:test)
function editDoublesMidGame(logger) {
    var e = new ScoreEngine(21,30,3); e.setMatchMode(1); e.configureService(0,2);
    e.point(0); e.point(0); e.point(1);
    Test.assertEqual(e.editService(2,0), true);
    Test.assertEqual(e.state[0], 2); Test.assertEqual(e.state[1], 1);
    Test.assertEqual(e.serverPlayer(), 2); Test.assertEqual(e.receiverPlayer(), 0);
    Test.assertEqual(e.serviceCourt(), 1);
    Test.assertEqual(e.playerAtCourt(1,0), 3); Test.assertEqual(e.playerAtCourt(0,0), 1);
    Test.assertEqual(e.state[7], 1);
    e.undo(); Test.assertEqual(e.serverPlayer(), 3); Test.assertEqual(e.state[0], 2);
    return true;
}

(:test)
function editSinglesMidGame(logger) {
    var e = new ScoreEngine(21,30,3); e.point(0);
    Test.assertEqual(e.editService(2,0), true);
    Test.assertEqual(e.state[0], 1); Test.assertEqual(e.state[1], 0);
    Test.assertEqual(e.serverPlayer(), 2); Test.assertEqual(e.serviceCourt(), 0);
    Test.assertEqual(e.editService(1,2), false); Test.assertEqual(e.editService(0,0), false);
    return true;
}

(:test)
function editServeRestore(logger) {
    var e = new ScoreEngine(21,30,3); e.setMatchMode(1); e.configureService(0,2); e.point(0);
    e.editService(1,3);
    var restored = new ScoreEngine(21,30,3);
    Test.assertEqual(restored.restore(e.pack()), true);
    Test.assertEqual(restored.serverPlayer(), 1); Test.assertEqual(restored.receiverPlayer(), 3);
    restored.point(0); Test.assertEqual(restored.serverPlayer(), 1);
    Test.assertEqual(restored.serviceCourt(), 0);
    return true;
}
