import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.System;
import Toybox.Lang;

class ScoreView extends WatchUi.View {
    var app;
    var timer;

    function initialize(application) {
        View.initialize(); app = application; timer = new Timer.Timer();
    }
    function onShow() { timer.start(method(:tick), 1000, true); }
    function onHide() { timer.stop(); }
    function tick() {
        app.recorder.refresh(); app.refreshMetrics(); WatchUi.requestUpdate();
    }
    // Measure device font bounds so large digits fit their assigned row.
    function fitFont(dc as Graphics.Dc, text as Lang.String, preferred as Graphics.FontType,
                     maxWidth as Lang.Number, maxHeight as Lang.Number) as Graphics.FontType {
        var fonts = [] as Lang.Array<Graphics.FontType>;
        if (preferred == Graphics.FONT_NUMBER_HOT) {
            fonts = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE,
                Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]
                as Lang.Array<Graphics.FontType>;
        } else if (preferred == Graphics.FONT_LARGE) {
            fonts = [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL,
                Graphics.FONT_TINY, Graphics.FONT_XTINY] as Lang.Array<Graphics.FontType>;
        } else { fonts = [app.fonts.small] as Lang.Array<Graphics.FontType>; }
        for (var i = 0; i < fonts.size(); i += 1) {
            var font = fonts[i];
            if (dc.getFontHeight(font) <= maxHeight &&
                dc.getTextWidthInPixels(text, font) <= maxWidth) { return font; }
        }
        return preferred == Graphics.FONT_NUMBER_HOT || preferred == Graphics.FONT_LARGE ? Graphics.FONT_XTINY : app.fonts.small;
    }
    function text(dc as Graphics.Dc, x, y, value as Lang.String, color, font, width, height) {
        var selected = self.fitFont(dc, value, font, width, height);
        var dx = (dc.getWidth() - 280) / 2;
        var dy = (dc.getHeight() - 280) / 2;
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(x + dx, y + dy - dc.getFontHeight(selected) / 2,
            selected, value, Graphics.TEXT_JUSTIFY_CENTER);
    }
    function timeLabel() {
        var seconds = (app.recorder.elapsedMs / 1000).toNumber();
        var minutes = (seconds / 60).toNumber();
        return minutes.toString() + ":" + (seconds % 60).format("%02d");
    }
    function metricText(value) { return value == null ? "--" : value.toString(); }
    function recordingHeader(dc as Graphics.Dc) {
        var top = "仅计分";
        if (app.recorder.status == 0 && app.recordWanted) { top = "4开始记录"; }
        var color = Graphics.COLOR_LT_GRAY;
        if (app.recorder.status == 1) { top = "记录 " + self.timeLabel(); color = Graphics.COLOR_GREEN; }
        if (app.recorder.status == 2) { top = "暂停 " + self.timeLabel(); color = Graphics.COLOR_YELLOW; }
        if (app.recorder.status == 3) { top = "已存 " + self.timeLabel(); }
        if (app.paused) { top = "比赛已暂停"; color = Graphics.COLOR_YELLOW; }
        if (app.settling) { top = "结算待完成"; color = Graphics.COLOR_YELLOW; }
        if (app.locked) { top += " 锁"; }
        self.text(dc, 140, 22, top, color, Graphics.FONT_XTINY, 180, 24);
    }
    function scoringArrow(dc as Graphics.Dc, x) {
        var dx = (dc.getWidth() - 280) / 2;
        var dy = (dc.getHeight() - 280) / 2;
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
        dc.fillRectangle(x - 10 + dx, 80 + dy, 5, 5);
        for (var i = 0; i < 7; i += 1) {
            dc.drawLine(x - 6 + i + dx, 76 + i + dy, x - 6 + i + dx, 88 - i + dy);
        }
    }
    function onUpdate(dc as Graphics.Dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        app.recorder.refresh(); app.refreshMetrics();
        if (app.page == 1) { self.drawPerformance(dc); return; }
        if (app.page == 2) { self.drawClock(dc); return; }
        if (app.page == 3) { self.drawCourt(dc); return; }
        self.drawScore(dc);
    }
    function drawScore(dc as Graphics.Dc) {
        var e = app.engine; var s = e.state;
        var dx = (dc.getWidth() - 280) / 2;
        var dy = (dc.getHeight() - 280) / 2;
        self.recordingHeader(dc);
        self.text(dc, 140, 50, (e.isDoubles() ? "双打 " : "单打 ") + "第" + s[6].toString() +
            "局 局数" + s[2].toString() + "-" + s[3].toString(), Graphics.COLOR_WHITE, Graphics.FONT_XTINY, 222, 24);
        self.text(dc, 84, 82, "我方", Graphics.COLOR_GREEN, Graphics.FONT_TINY, 82, 24);
        self.text(dc, 196, 82, "对方", Graphics.COLOR_WHITE, Graphics.FONT_TINY, 82, 24);
        self.text(dc, 84, 136, s[0].toString(), Graphics.COLOR_GREEN, Graphics.FONT_NUMBER_HOT, 100, 78);
        self.text(dc, 196, 136, s[1].toString(), Graphics.COLOR_WHITE, Graphics.FONT_NUMBER_HOT, 100, 78);
        if (s[7] == 0) { self.scoringArrow(dc, 48); }
        if (s[7] == 1) { self.scoringArrow(dc, 160); }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawLine(140 + dx, 78 + dy, 140 + dx, 170 + dy);
        var message = app.notice;
        if (s[4] == 2) { message = s[2] > s[3] ? "我方获胜 按4查看" : "对方获胜 按4查看"; }
        else if (s[4] == 1) { message = "本局结束 按4继续"; }
        else if (!e.serveReady()) { message = "请设置接发球"; }
        else if (app.locked) { message = "请先解锁按键"; }
        else if (message.equals("")) { message = "2我方 3对方 5撤销"; }
        if (app.saveFailed) { message = "比分保存失败"; }
        if (e.serveReady() && s[4] == 0) {
            self.text(dc,140,181,badmintonPlayerName(e.serverPlayer()) + (e.serviceCourt() == 0 ? "右 发 " : "左 发 ") +
                badmintonPlayerName(e.receiverPlayer()) + "接",Graphics.COLOR_WHITE,Graphics.FONT_XTINY,206,22);
        }
        self.text(dc, 140, 205, message, app.saveFailed ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY,
            Graphics.FONT_XTINY, 238, 24);
        self.text(dc, 140, 230, "心率" + self.metricText(app.stats.heartRate) +
            " 热量" + self.metricText(app.stats.calories), Graphics.COLOR_WHITE, Graphics.FONT_XTINY, 212, 24);
        self.text(dc, 140, 254, s[4] == 0 ? "4开球 长按2菜单" :
            (s[4] == 1 ? "4下一局 5撤销" : "4查看结果 5撤销"), Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 145, 22);
    }
    function courtLines(dc as Graphics.Dc) {
        var dx = (dc.getWidth() - 280) / 2;
        var dy = (dc.getHeight() - 280) / 2;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawRectangle(84 + dx, 80 + dy, 112, 140);
        dc.drawLine(94 + dx, 80 + dy, 94 + dx, 220 + dy);
        dc.drawLine(186 + dx, 80 + dy, 186 + dx, 220 + dy);
        dc.drawLine(84 + dx, 90 + dy, 196 + dx, 90 + dy);
        dc.drawLine(84 + dx, 210 + dy, 196 + dx, 210 + dy);
        dc.drawLine(84 + dx, 134 + dy, 196 + dx, 134 + dy);
        dc.drawLine(84 + dx, 166 + dy, 196 + dx, 166 + dy);
        dc.drawLine(140 + dx, 80 + dy, 140 + dx, 134 + dy);
        dc.drawLine(140 + dx, 166 + dy, 140 + dx, 220 + dy);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawLine(80 + dx, 150 + dy, 200 + dx, 150 + dy);
        dc.drawLine(80 + dx, 151 + dy, 200 + dx, 151 + dy);
    }
    function courtPlayer(dc as Graphics.Dc, team, court, player, serving, doubles) {
        var x = badmintonCourtX(team, court) + (dc.getWidth() - 280) / 2;
        var y = badmintonCourtY(team) + (dc.getHeight() - 280) / 2;
        var radius = doubles ? 16 : 9;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(x, y, radius + 2);
        dc.setColor(serving ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        if (serving) { dc.fillCircle(x, y, radius); }
        else { dc.drawCircle(x, y, radius); dc.drawCircle(x, y, radius - 1); }
        if (doubles) {
            var label = badmintonPlayerName(player);
            var font = self.fitFont(dc, label, Graphics.FONT_XTINY, 27, 26);
            dc.setColor(serving ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y - dc.getFontHeight(font) / 2, font, label, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
    function drawCourt(dc as Graphics.Dc) {
        // Lightweight court: only lines, circles and short player IDs.
        self.courtLines(dc);
        self.recordingHeader(dc);
        var e = app.engine; var s = e.state;
        self.text(dc, 140, 50, "我方 " + s[0].toString() + " : " + s[1].toString() + " 对方",
            Graphics.COLOR_WHITE, Graphics.FONT_SMALL, 224, 24);
        self.text(dc, 47, 112, "对方", Graphics.COLOR_WHITE, Graphics.FONT_XTINY, 54, 24);
        self.text(dc, 47, 188, "我方", Graphics.COLOR_GREEN, Graphics.FONT_XTINY, 54, 24);
        if (e.isDoubles()) {
            for (var team = 0; team < 2; team += 1) {
                for (var court = 0; court < 2; court += 1) {
                    var player = e.playerAtCourt(team, court);
                    self.courtPlayer(dc, team, court, player, player == e.serverPlayer(), true);
                }
            }
        } else {
            var serviceCourt = e.serviceCourt();
            self.courtPlayer(dc, 0, serviceCourt, 0, s[5] == 0, false);
            self.courtPlayer(dc, 1, serviceCourt, 2, s[5] == 1, false);
        }
        var hint = "2/3加分 5返回";
        if (app.locked) { hint = "按键已锁定"; }
        else if (app.recorder.status == 2) { hint = "运动已暂停"; }
        if (app.saveFailed) { hint = "保存失败"; }
        self.text(dc, 140, 246, hint, Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 150, 22);
    }
    function drawPerformance(dc as Graphics.Dc) {
        self.recordingHeader(dc);
        self.text(dc, 140, 50, "运动数据", Graphics.COLOR_WHITE, Graphics.FONT_XTINY, 222, 24);
        self.text(dc, 140, 101, self.metricText(app.stats.heartRate), Graphics.COLOR_GREEN,
            app.stats.heartRate == null ? Graphics.FONT_LARGE : Graphics.FONT_NUMBER_HOT, 150, 64);
        self.text(dc, 140, 143, "心率 次/分", Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 220, 22);
        self.text(dc, 84, 170, "千卡", Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 100, 22);
        self.text(dc, 196, 170, "运动时长", Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 100, 22);
        self.text(dc, 84, 197, self.metricText(app.stats.calories), Graphics.COLOR_WHITE, Graphics.FONT_MEDIUM, 100, 30);
        self.text(dc, 196, 197, app.recorder.status == 0 ? "--" : self.timeLabel(),
            Graphics.COLOR_WHITE, Graphics.FONT_MEDIUM, 100, 30);
        self.text(dc, 140, 224, "平均" + self.metricText(app.stats.averageHeartRate) +
            " 最高" + self.metricText(app.stats.maxHeartRate), Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 204, 22);
        self.text(dc, 140, 248, "5比分 长按2菜单", Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 144, 22);
    }
    function drawClock(dc as Graphics.Dc) {
        self.recordingHeader(dc);
        self.text(dc, 140, 50, "当前时间", Graphics.COLOR_WHITE, Graphics.FONT_XTINY, 222, 24);
        var now = System.getClockTime();
        self.text(dc, 140, 114, badmintonClockText(now.hour, now.min, now.sec), Graphics.COLOR_WHITE,
            Graphics.FONT_LARGE, 238, 44);
        self.text(dc, 140, 152, "24小时制", Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 222, 24);
        self.text(dc, 140, 183, "时长" + (app.recorder.status == 0 ? "--" : self.timeLabel()),
            Graphics.COLOR_GREEN, Graphics.FONT_XTINY, 222, 24);
        var s = app.engine.state;
        self.text(dc, 140, 211, "我方 " + s[0].toString() + " : " + s[1].toString() + " 对方",
            Graphics.COLOR_WHITE, Graphics.FONT_XTINY, 212, 24);
        self.text(dc, 140, 245, "5比分 长按2菜单", Graphics.COLOR_LT_GRAY, Graphics.FONT_XTINY, 144, 22);
    }
}
