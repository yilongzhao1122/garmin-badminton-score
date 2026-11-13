import Toybox.System;
import Toybox.WatchUi;

class ScoreDelegate extends WatchUi.BehaviorDelegate {
    var app;
    function initialize(application) { BehaviorDelegate.initialize(); app = application; }
    function ready() { return app.acceptInput(); }
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
    function onMenu() { if (self.ready()) { showScoreMenu(app); } return true; }
}
