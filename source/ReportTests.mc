import Toybox.Test;

(:test)
function reportGameBreaks(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport(); r.begin(1000);
    r.tick(6000,false,e); Test.assertEqual(r.gameMs[0],5000);
    for (var i = 0; i < 21; i += 1) { e.point(0); }
    r.tick(9000,false,e); Test.assertEqual(r.totalMs,8000); Test.assertEqual(r.gameMs[0],5000);
    e.nextGame(); r.gameRunning = false; r.tick(12000,false,e);
    Test.assertEqual(r.gameMs[1],0); r.begin(12000); r.tick(14000,false,e);
    Test.assertEqual(r.gameMs[1],2000); return true;
}
(:test)
function reportPause(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport(); r.begin(1000);
    r.tick(3000,false,e); r.tick(9000,true,e); r.tick(11000,false,e);
    Test.assertEqual(r.totalMs,4000); Test.assertEqual(r.gameMs[0],4000); return true;
}
(:test)
function reportRestoreGap(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport(); r.begin(1000); r.tick(5000,false,e);
    var next = new MatchReport(); next.restore(r.pack(),100000,true); next.tick(110000,false,e);
    Test.assertEqual(next.totalMs,4000); next.begin(110000); next.tick(112000,false,e);
    Test.assertEqual(next.totalMs,6000); return true;
}
(:test)
function reportLegacyUnknown(logger) {
    var r = new MatchReport(); r.restore(null,1000,true);
    Test.assertEqual(r.known,false); Test.assertEqual(r.totalMs,0); return true;
}
(:test)
function reportPartialRows(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport();
    Test.assertEqual(r.rows(e).size(),0); r.begin(1000); e.point(0);
    Test.assertEqual(r.rows(e).size(),1); Test.assertEqual(r.rows(e)[0][3],false);
    for (var i = 1; i < 21; i += 1) { e.point(0); }
    Test.assertEqual(r.rows(e).size(),1); Test.assertEqual(r.rows(e)[0][3],true); return true;
}
(:test)
function reportUndoBoundary(logger) {
    var e = new ScoreEngine(21,30,3); var r = new MatchReport();
    for (var i = 0; i < 21; i += 1) { e.point(0); }
    e.nextGame(); r.begin(1000); r.tick(5000,false,e);
    e.undo(); r.reconcile(e); Test.assertEqual(r.gameMs[1],0); return true;
}
