import Toybox.Test;

(:test)
function deuceAndCap(logger) {
    var e = new ScoreEngine(21, 30, 3);
    for (var i = 0; i < 20; i += 1) { e.point(0); e.point(1); }
    e.point(0);
    Test.assertEqual(e.state[4], 0); // 21-20 keeps playing
    e.point(0);
    Test.assertEqual(e.state[4], 1); // 22-20 ends game
    Test.assertEqual(e.state[2], 1);
    Test.assert(e.undo());
    Test.assertEqual(e.state[0], 21);
    Test.assertEqual(e.state[4], 0);
    Test.assertEqual(e.results.size(), 0);
    return true;
}

(:test)
function thirtyPointCap(logger) {
    var e = new ScoreEngine(21, 30, 1);
    for (var i = 0; i < 29; i += 1) { e.point(0); e.point(1); }
    e.point(1);
    Test.assertEqual(e.state[1], 30);
    Test.assertEqual(e.state[4], 2);
    Test.assert(!e.point(0));
    return true;
}

(:test)
function undoAcrossGameBoundary(logger) {
    var e = new ScoreEngine(21, 30, 3);
    for (var i = 0; i < 21; i += 1) { e.point(1); }
    Test.assert(e.nextGame());
    Test.assertEqual(e.state[5], 1);
    Test.assertEqual(e.state[7], -1);
    e.point(0);
    Test.assert(e.undo());
    Test.assertEqual(e.state[0], 0);
    Test.assert(e.undo());
    Test.assertEqual(e.state[1], 21);
    Test.assertEqual(e.state[4], 1);
    Test.assert(e.undo());
    Test.assertEqual(e.state[1], 20);
    Test.assertEqual(e.state[3], 0);
    return true;
}

(:test)
function matchAndRestore(logger) {
    var e = new ScoreEngine(21, 30, 3);
    for (var i = 0; i < 21; i += 1) { e.point(0); }
    e.nextGame();
    for (var j = 0; j < 21; j += 1) { e.point(0); }
    Test.assertEqual(e.state[4], 2);
    Test.assert(!e.nextGame());
    var r = new ScoreEngine(21, 30, 3);
    Test.assert(r.restore(e.pack()));
    Test.assertEqual(r.state[2], 2);
    Test.assert(r.undo());
    Test.assertEqual(r.state[0], 20);
    Test.assertEqual(r.state[2], 1);
    return true;
}

(:test)
function lastScorerArrow(logger) {
    var e = new ScoreEngine(21, 30, 3);
    Test.assertEqual(e.state[7], -1);
    e.setServer(1);
    Test.assertEqual(e.state[7], -1); // Initial server is not a scored rally.
    e.point(0);
    Test.assertEqual(e.state[7], 0);
    e.point(1);
    Test.assertEqual(e.state[7], 1);
    e.undo();
    Test.assertEqual(e.state[7], 0);
    e.undo();
    Test.assertEqual(e.state[7], -1);
    return true;
}

(:test)
function doublesServeSequence(logger) {
    var e = new ScoreEngine(21, 30, 3);
    Test.assert(e.setMatchMode(1));
    Test.assert(!e.point(0));
    Test.assert(e.configureService(0, 2)); // A1 R -> B1
    Test.assertEqual(e.serverPlayer(), 0);
    Test.assertEqual(e.receiverPlayer(), 2);
    e.point(0); // 1:0 A1 L -> B2
    Test.assertEqual(e.serverPlayer(), 0);
    Test.assertEqual(e.receiverPlayer(), 3);
    Test.assertEqual(e.serviceCourt(), 1);
    e.point(1); // 1:1 B2 L -> A1
    Test.assertEqual(e.serverPlayer(), 3);
    Test.assertEqual(e.receiverPlayer(), 0);
    e.point(1); // 1:2 B2 R -> A2
    Test.assertEqual(e.serverPlayer(), 3);
    Test.assertEqual(e.receiverPlayer(), 1);
    Test.assertEqual(e.serviceCourt(), 0);
    e.point(0); // 2:2 A2 R -> B2
    Test.assertEqual(e.serverPlayer(), 1);
    Test.assertEqual(e.receiverPlayer(), 3);
    Test.assert(e.undo());
    Test.assertEqual(e.serverPlayer(), 3);
    Test.assertEqual(e.receiverPlayer(), 1);
    return true;
}

(:test)
function doublesNewGameSetup(logger) {
    var e = new ScoreEngine(21, 30, 3);
    e.setMatchMode(1);
    e.configureService(0, 2);
    for (var i = 0; i < 21; i += 1) { e.point(0); }
    Test.assert(e.nextGame());
    Test.assert(!e.serveReady());
    Test.assert(!e.point(0));
    Test.assert(!e.configureService(2, 0)); // Losing team cannot serve first.
    Test.assert(e.configureService(1, 3)); // Winner may choose A2; receiver B2.
    Test.assertEqual(e.serverPlayer(), 1);
    Test.assertEqual(e.receiverPlayer(), 3);
    return true;
}
