import Toybox.Lang;
function badmintonClockText(hour as Lang.Number, minute as Lang.Number, second as Lang.Number) as Lang.String {
    return hour.format("%02d") + ":" + minute.format("%02d") + ":" + second.format("%02d");
}
