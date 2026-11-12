import Toybox.WatchUi;

// Cached 16px score/court labels and a dedicated 19px menu subset.
// Switching the phone preference reuses these objects; no per-frame loads.
class ChineseFonts {
    var normal;
    var small;
    var menuLarge;
    var menuSize = 19;
    function initialize() {
        small = WatchUi.loadResource(Rez.Fonts.CnSmall) as WatchUi.FontResource;
        menuLarge = WatchUi.loadResource(Rez.Fonts.CnMenu) as WatchUi.FontResource;
        normal = menuLarge;
    }
    function setMenuSize(value) {
        menuSize = value == 16 ? 16 : 19;
        normal = menuSize == 16 ? small : menuLarge;
    }
}
