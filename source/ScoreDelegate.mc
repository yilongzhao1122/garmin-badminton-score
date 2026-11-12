import Toybox.System;
import Toybox.WatchUi;

class ScoreDelegate extends WatchUi.BehaviorDelegate {
    var app;
    var lastInput = -1000;
    function initialize(application) { BehaviorDelegate.initialize(); app = application; }
    function ready() {
        var now = System.getTimer();
        if (now >= lastInput && now - lastInput < 250) { return false; }
        lastInput = now; return true;
    }
    function onSelect() { if (self.ready() && app.page == 0) { app.primarySelect(); } return true; }
    function onPreviousPage() {
        if (self.ready() && (app.page == 0 || app.page == 3)) { app.award(0); }
        return true;
    }
    function onNextPage() {
        if (self.ready() && (app.page == 0 || app.page == 3)) { app.award(1); }
        return true;
    }
    function onBack() {
        if (self.ready()) { if (app.page != 0) { app.showPage(0); } else { app.undo(); } }
        return true;
    }
    function onMenu() { showScoreMenu(app); return true; }
}
