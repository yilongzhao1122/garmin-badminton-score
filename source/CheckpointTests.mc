import Toybox.Test;

(:test)
function checkpointReplaces(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport(); var c = new GameCheckpoints();
    for (var i = 0; i < 21; i += 1) { e.point(0); }
    r.gameMs[0] = 12000;
    Test.assertEqual(c.setGame(0,true,e,r),true); c.setGame(0,true,e,r);
    Test.assertEqual(c.snapshots.size(),3); Test.assertEqual(c.snapshots[0][0],21);
    Test.assertEqual(c.snapshots[0][2],12000); return true;
}
(:test)
function checkpointDecline(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport(); var c = new GameCheckpoints();
    for (var i = 0; i < 21; i += 1) { e.point(1); }
    c.setGame(0,false,e,r); Test.assertEqual(c.choices[0],0);
    Test.assertEqual(c.snapshots[0] == null,true); Test.assertEqual(e.state[1],21);
    Test.assertEqual(e.state[3],1); return true;
}
(:test)
function checkpointUndoInvalidates(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport(); var c = new GameCheckpoints();
    for (var i = 0; i < 21; i += 1) { e.point(0); }
    c.setGame(0,true,e,r); e.undo(); c.reconcile(e);
    Test.assertEqual(c.choices[0],-1); Test.assertEqual(c.snapshots[0] == null,true); return true;
}
(:test)
function checkpointRestore(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport(); var c = new GameCheckpoints();
    for (var i = 0; i < 21; i += 1) { e.point(0); }
    c.setGame(0,true,e,r); var next = new GameCheckpoints();
    Test.assertEqual(next.restore(c.pack()),true); next.snapshots[0][0] = 0;
    Test.assertEqual(c.snapshots[0][0],21); Test.assertEqual(next.restore(null),false); return true;
}
