import Toybox.WatchUi;
import Toybox.Lang;

// Legacy helper retained for its existing native regression test.
function badmintonMenuNumber(item as WatchUi.MenuItem) as Lang.Number {
    var raw = item.getId();
    if (raw instanceof Lang.Number) { return raw as Lang.Number; }
    return -99;
}
function badmintonPlayerName(player) {
    if (player == 0) { return "A1"; }
    if (player == 1) { return "A2"; }
    if (player == 2) { return "B1"; }
    return "B2";
}
function badmintonPlayerLabel(player) {
    if (player == 0) { return "A1 本人"; }
    if (player == 1) { return "A2 队友"; }
    if (player == 2) { return "B1 对方"; }
    return "B2 对方";
}
