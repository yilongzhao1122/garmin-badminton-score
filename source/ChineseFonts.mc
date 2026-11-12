import Toybox.WatchUi;

// One cached 16px subset shared by all labels. Large score digits still use
// the native number font. No duplicate 20px atlas or full-screen artwork.
class ChineseFonts {
    var normal;
    var small;
    function initialize() {
        small = WatchUi.loadResource(Rez.Fonts.CnSmall) as WatchUi.FontResource;
        normal = small;
    }
}
