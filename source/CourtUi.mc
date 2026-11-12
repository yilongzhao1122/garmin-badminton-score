import Toybox.Lang;

// The display always shows opponents at the top and our side at the bottom.
// Court 0 = each team's own right facing the net; court 1 = its own left.
// Therefore an upper-side right court appears on the screen's LEFT.
function badmintonCourtColumn(team as Lang.Number, court as Lang.Number) as Lang.Number {
    if ((team != 0 && team != 1) || (court != 0 && court != 1)) { return -1; }
    return team == 0 ? 1 - court : court;
}

function badmintonCourtX(team as Lang.Number, court as Lang.Number) as Lang.Number {
    var column = badmintonCourtColumn(team, court);
    if (column < 0) { return -1; }
    return column == 0 ? 112 : 168;
}

function badmintonCourtY(team as Lang.Number) as Lang.Number {
    return team == 0 ? 188 : 112;
}
