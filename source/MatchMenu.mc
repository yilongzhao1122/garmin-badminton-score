import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Lang;
import Toybox.System;

// One custom menu view owns its navigation frames. Child selection never
// pops its parent; BACK removes exactly one frame, then closes at the root.
function showScoreMenu(app) {
    var menu = new MatchMenu(app);
    WatchUi.pushView(menu, new MatchMenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
}
function showGameEndFlow(app) {
    var menu = new MatchMenu(app); menu.frames = []; menu.openGameEnd();
    WatchUi.pushView(menu, new MatchMenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
}
class MatchMenu extends WatchUi.View {
    var app;
    var frames;
    var timer;
    var resultFrame = 0;
    function initialize(application) {
        View.initialize(); app = application; frames = []; timer = new Timer.Timer();
        self.root();
    }
    function onShow() { self.restartTimer(); }
    function onHide() { timer.stop(); }
    function restartTimer() {
        timer.stop(); timer.start(method(:tick), self.frame()[3].equals("result") ? 400 : 1000, true);
    }
    function tick() {
        app.refreshMatch(); app.recorder.refresh();
        if (self.frame()[3].equals("result")) {
            resultFrame += 1;
            if (resultFrame >= 6) { self.openMatchSave(); }
        }
        WatchUi.requestUpdate();
    }
    function root() {
        frames = [];
        self.push("比赛菜单", [["新建比赛","new",null],["比赛设置","match",null],
            ["数据页面","pages",null],["运动记录","activity",null],["按键锁定","keys",null],["结束对局","finish",null],["退出应用","exit",null]], "root", null);
    }
    function push(title, rows, kind, context) {
        frames.add([title, rows, 0, kind, context]); WatchUi.requestUpdate();
    }
    function frame() { return frames[frames.size() - 1]; }
    function replace(title, rows, kind, context) {
        var selected = self.frame()[2] as Lang.Number;
        if (selected >= rows.size()) { selected = rows.size() - 1; }
        frames[frames.size() - 1] = [title, rows, selected, kind, context];
        WatchUi.requestUpdate();
    }
    function move(delta) {
        var f = self.frame(); var next = (f[2] as Lang.Number) + delta;
        var count = f[1].size();
        if (count > 0) {
            next = next % count;
            if (next < 0) { next += count; }
            f[2] = next;
        }
        WatchUi.requestUpdate();
    }
    function back() {
        if (self.frame()[3].equals("result")) { self.openMatchSave(); return; }
        if (self.frame()[3].equals("matchSave")) { app.showPage(0); self.close(); return; }
        if (frames.size() == 1) { self.close(); return; }
        var keep = [];
        for (var i = 0; i < frames.size() - 1; i += 1) { keep.add(frames[i]); }
        frames = keep; WatchUi.requestUpdate();
    }
    function close() { WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); }
    function message(title, detail) {
        self.push(title, [[detail,"none",null],["返回","back",null]], "message", null);
    }
    function copyPlan(p) { return [p[0],p[1],p[2],p[3],p[4],p[5]]; }
    function matchRows() {
        var rows = [];
        if (app.engine.state[4] == 1) { rows.add(["下一局","next",null]); }
        if (app.engine.state[4] == 2) { rows.add(["比赛结果","showResult",null]); }
        if (app.engine.state[4] == 0) { rows.add(["修改接发球","edit",null]); }
        rows.add(["各局比分","history",null]);
        if (app.lastMatch != null) { rows.add(["上场比赛","last",null]); }
        return rows;
    }
    function activityRows() {
        var rows = [];
        if (app.recorder.hasSession()) {
            rows.add(app.recorder.status == 1 ? ["暂停","recPause",null] : ["继续记录","recResume",null]);
            rows.add(["保存运动","recSave",null]);
            rows.add(["放弃记录","discard",null]);
        } else { rows.add(["记录运动","recStart",null]); }
        rows.add(["记录状态","status",null]);
        return rows;
    }
    function keysRows() { return [["解锁","unlock",null],["锁定","lock",null]]; }
    function recordingState() {
        if (app.recorder.status == 1) { return "记录中"; }
        if (app.recorder.status == 2) { return "已暂停"; }
        if (app.recorder.status == 3) { return "运动已保存"; }
        return app.recordWanted ? "待开始" : "仅计分";
    }
    function openGameEnd() {
        if (app.engine.state[4] == 2) {
            resultFrame = 0;
            self.push("比赛结果", [["","none",null]], "result", null);
            self.restartTimer();
        } else {
            self.push("是否保存本局？", [["是","roundKeep",true],["否","roundKeep",false]], "roundSave", null);
        }
    }
    function openMatchSave() {
        self.replace("是否保存比赛？", [["是","matchKeep",true],["否","matchKeep",false]], "matchSave", null);
        self.frame()[2] = 0; self.restartTimer();
    }
    function openRoundReceiver(server) {
        var other = server < 2 ? 2 : 0;
        var rows = [];
        if (app.engine.isDoubles()) {
            rows = [[badmintonPlayerLabel(other),"roundReceiver",other],
                [badmintonPlayerLabel(other + 1),"roundReceiver",other + 1]];
        } else { rows = [[other == 0 ? "我方" : "对方","roundReceiver",other]]; }
        self.push(app.engine.isDoubles() ? "接球人" : "接球方", rows, "roundReceiver", server);
    }
    function openServer(plan) {
        var rows = [];
        for (var player = 0; player < 4; player += 1) {
            if (plan[3] == 1 || player == 0 || player == 2) {
                rows.add([plan[3] == 1 ? badmintonPlayerLabel(player) : (player == 0 ? "我方" : "对方"), "newServer", player]);
            }
        }
        self.push("发球人", rows, "newServer", plan);
    }
    function openRecord(plan) {
        self.push("记录方式", [["记录运动","newRecord",true],["仅计分","newRecord",false]], "newRecord", plan);
    }
    function openEdit(firstSetup) {
        var rows = [];
        for (var player = 0; player < 4; player += 1) {
            var team = player < 2 ? 0 : 1;
            var allowed = !firstSetup || app.engine.state[6] == 1 || team == app.engine.state[5];
            if (allowed && (app.engine.isDoubles() || player == 0 || player == 2)) {
                rows.add([app.engine.isDoubles() ? badmintonPlayerLabel(player) : (player == 0 ? "我方" : "对方"), "editServer", player]);
            }
        }
        self.push("发球人", rows, "editServer", firstSetup);
    }
    function duration(ms) {
        var seconds = (ms / 1000).toNumber();
        return (seconds / 60).toNumber().toString() + ":" + (seconds % 60).format("%02d");
    }
    function games(pack, title, timing, checkpointData) {
        var engine = new ScoreEngine(pack[1],pack[2],pack[3]); engine.restore(pack);
        var report = new MatchReport();
        var saved = new GameCheckpoints(); saved.restore(checkpointData);
        report.restore(timing, System.getTimer(), engine.results.size() > 0 || engine.state[0] + engine.state[1] > 0);
        var results = report.rows(engine); var rows = [];
        if (results.size() == 0) { rows.add(["暂无对局","none",null]); }
        for (var i = 0; i < results.size(); i += 1) {
            rows.add(["第" + (i + 1).toString() + "局 " + results[i][0].toString() + ":" + results[i][1].toString(),"none",null]);
            var state = results[i][3] ? (saved.choices[i] == 1 ? "已保存 " :
                (saved.choices[i] == 0 ? "未单存 " : "已完 ")) : "未完 ";
            rows.add([state + (report.known ? self.duration(results[i][2] * 1000) : "用时未知"),"none",null]);
        }
        self.push(title, rows, "history", null);
    }
    function returnMatch() {
        while (frames.size() > 1 && !self.frame()[3].equals("match")) {
            var keep = [];
            for (var i = 0; i < frames.size() - 1; i += 1) { keep.add(frames[i]); }
            frames = keep;
        }
        if (self.frame()[3].equals("match")) { self.replace("比赛设置", self.matchRows(), "match", null); }
        WatchUi.requestUpdate();
    }
    function select() {
        var f = self.frame();
        if (f[3].equals("result")) { self.openMatchSave(); return; }
        var row = f[1][f[2]];
        var id = row[1] as Lang.String; var value = row[2]; var context = f[4];
        var plan = null; var start = 0;
        var number = -1;
        if (value instanceof Lang.Number) { number = value as Lang.Number; }
        if (id.equals("none")) { return; }
        if (id.equals("back")) { self.back(); return; }
        if (id.equals("roundKeep")) {
            if (!app.saveCompletedGame(value)) { self.message("保存失败", app.notice); return; }
            self.push("是否开始下一局？", [["是","roundNext",true],["否","roundNext",false]], "roundNext", null); return;
        }
        if (id.equals("roundNext")) {
            if (!value) { app.showPage(0); self.close(); return; }
            self.push("发球方", [["我方","roundTeam",0],["对方","roundTeam",1]], "roundTeam", null);
            self.frame()[2] = app.engine.state[5]; return;
        }
        if (id.equals("roundTeam")) {
            if (!app.engine.isDoubles()) { self.openRoundReceiver(number == 0 ? 0 : 2); }
            else {
                start = number == 0 ? 0 : 2;
                self.push("发球人", [[badmintonPlayerLabel(start),"roundServer",start],
                    [badmintonPlayerLabel(start + 1),"roundServer",start + 1]], "roundServer", null);
            }
            return;
        }
        if (id.equals("roundServer")) { self.openRoundReceiver(number); return; }
        if (id.equals("roundReceiver")) {
            if (app.prepareNextGame(context,number)) { self.close(); }
            else { self.message("无法继续",app.notice); }
            return;
        }
        if (id.equals("matchKeep")) {
            if (app.endCurrent(value)) { self.close(); }
            else { self.message("处理失败",app.notice); }
            return;
        }
        if (id.equals("new") || id.equals("finish")) {
            self.push("是否保存当前对局结果", [["是","settle",true],["否","settle",false]],
                "settle", id); return;
        }
        if (id.equals("settle")) {
            if (!app.endCurrent(value)) { self.message("处理失败", app.notice); return; }
            var newWizard = context.equals("new");
            if (newWizard) {
                self.root();
                self.push("新建比赛", [["单打","newMode",0],["双打","newMode",1]], "newMode", null);
            } else { self.close(); }
            return;
        }
        if (id.equals("newMode")) {
            self.push("每局分数", [["21分","newPoints",[21,30]],["15分","newPoints",[15,21]],
                ["11分","newPoints",[11,15]]], "newPoints", [21,30,3,number,0,2]); return;
        }
        if (id.equals("newPoints")) {
            plan = self.copyPlan(context); plan[0] = value[0]; plan[1] = value[1];
            self.push("比赛局制", [["三局两胜","newFormat",3],["单局","newFormat",1]], "newFormat", plan); return;
        }
        if (id.equals("newFormat")) {
            plan = self.copyPlan(context); plan[2] = number; self.openServer(plan); return;
        }
        if (id.equals("newServer")) {
            plan = self.copyPlan(context); plan[4] = number;
            if (plan[3] == 0) { plan[5] = number == 0 ? 2 : 0; self.openRecord(plan); }
            else {
                start = number < 2 ? 2 : 0;
                self.push("接球人", [[badmintonPlayerLabel(start),"newReceiver",start],
                    [badmintonPlayerLabel(start + 1),"newReceiver",start + 1]], "newReceiver", plan);
            }
            return;
        }
        if (id.equals("newReceiver")) {
            plan = self.copyPlan(context); plan[5] = number; self.openRecord(plan); return;
        }
        if (id.equals("newRecord")) {
            self.push("开始比赛？", [["开始","newApply",[self.copyPlan(context),value]],
                ["取消","cancelNew",null]], "newConfirm", null); return;
        }
        if (id.equals("cancelNew")) { self.root(); return; }
        if (id.equals("newApply")) {
            var p = value[0];
            if (app.newMatch(p[0],p[1],p[2],value[1],p[3],p[4],p[5])) { self.close(); }
            else { self.message("开始失败", app.notice); }
            return;
        }
        if (id.equals("match")) { self.push("比赛设置", self.matchRows(), "match", null); return; }
        if (id.equals("next")) {
            self.openGameEnd(); return;
        }
        if (id.equals("showResult")) { self.openGameEnd(); return; }
        if (id.equals("edit")) { self.openEdit(!app.engine.serveReady()); return; }
        if (id.equals("editServer")) {
            start = number < 2 ? 2 : 0;
            if (!app.engine.isDoubles()) {
                self.push("确认接发球？", [["确定","editApply",[number,start,context]],
                    ["取消","back",null]], "editConfirm", null);
            } else {
                self.push("接球人", [[badmintonPlayerLabel(start),"editReceiver",start],
                    [badmintonPlayerLabel(start + 1),"editReceiver",start + 1]], "editReceiver", [number,context]);
            }
            return;
        }
        if (id.equals("editReceiver")) {
            self.push("确认接发球？", [["确定","editApply",[context[0],number,context[1]]],
                ["取消","back",null]], "editConfirm", null); return;
        }
        if (id.equals("editApply")) {
            if (app.editServe(value[0],value[1],value[2])) { self.returnMatch(); }
            else { self.message("修改失败", app.notice); }
            return;
        }
        if (id.equals("history")) { app.refreshMatch(); self.games(app.engine.pack(), "各局比分", app.report.pack(),app.checkpoints.pack()); return; }
        if (id.equals("last")) {
            var state = app.lastMatch[0][4];
            self.push("上场比赛", [["我方 " + state[0].toString() + ":" + state[1].toString(),"none",null],
                [app.lastMatch[1] ? "运动已保存" : "无运动文件","none",null],
                [app.lastMatch.size() > 3 ? "用时 " + self.duration(app.lastMatch[2]) : "用时未知","none",null],
                [app.lastMatch.size() > 4 && app.lastMatch[4] ? "中途结束" : (state[4] == 2 ? "正常完赛" : "未完对局"),"none",null],
                ["各局比分","lastGames",null]], "last", null); return;
        }
        if (id.equals("lastGames")) { self.games(app.lastMatch[0], "上场各局", app.lastMatch.size() > 3 ? app.lastMatch[3] : null,
            app.lastMatch.size() > 5 ? app.lastMatch[5] : null); return; }
        if (id.equals("pages")) {
            self.push("数据页面", [["比分","page",0],["运动数据","page",1],["当前时间","page",2]], "pages", null); return;
        }
        if (id.equals("page")) { app.showPage(number); self.close(); return; }
        if (id.equals("activity")) { self.push("运动记录", self.activityRows(), "activity", null); return; }
        if (id.equals("status")) {
            var seconds = (app.recorder.elapsedMs / 1000).toNumber();
            var label = (seconds / 60).toNumber().toString() + ":" + (seconds % 60).format("%02d");
            var rows = [[self.recordingState(),"none",null],[label,"none",null]];
            if (app.matchFitSaved && app.recorder.status != 3) { rows.add(["之前运动已存","none",null]); }
            if (!app.recorder.lastError.equals("")) { rows.add([app.recorder.lastError,"none",null]); }
            self.push("记录状态", rows, "status", null); return;
        }
        if (id.equals("discard")) {
            self.push("放弃当前记录？", [["取消","back",null],["放弃记录","recDiscard",null]], "discard", null); return;
        }
        if (id.equals("recStart") || id.equals("recPause") || id.equals("recResume") || id.equals("recSave") || id.equals("recDiscard")) {
            if (!app.recordingAction(id)) { self.message("记录错误", app.recorder.lastError); return; }
            if (id.equals("recDiscard")) { self.back(); }
            self.replace("运动记录", self.activityRows(), "activity", null); return;
        }
        if (id.equals("keys")) { self.push("按键锁定", self.keysRows(), "keys", null); return; }
        if (id.equals("lock") || id.equals("unlock")) {
            app.setLocked(id.equals("lock")); self.replace("按键锁定", self.keysRows(), "keys", null); return;
        }
        if (id.equals("exit")) {
            self.push("退出应用", [["保存退出","endConfirm",null],["放弃退出","dropConfirm",null],
                ["返回比赛","returnPlay",null]], "exit", null); return;
        }
        if (id.equals("returnPlay")) { app.showPage(0); self.close(); return; }
        if (id.equals("dropConfirm")) {
            var pending = app.recorder.hasSession();
            self.push(pending ? "放弃本次运动？" : (app.matchFitSaved ? "运动已经保存" : "无待存运动"),
                [["取消","back",null],[pending ? "确认放弃" : "结束比赛","dropApply",null]], "dropConfirm", null); return;
        }
        if (id.equals("dropApply")) {
            if (!app.discardAndExit()) { self.message("放弃失败", app.notice); }
            return;
        }
        if (id.equals("endConfirm")) {
            var fit = app.recorder.hasSession() || app.recorder.status == 3 || app.matchFitSaved;
            self.push(fit ? "结束本场？" : "尚未记录", [["取消","back",null],
                [fit ? "保存退出" : "结束计分","endApply",null]], "endConfirm", null); return;
        }
        if (id.equals("endApply")) {
            if (!app.saveAndExit()) { self.message("保存失败", app.notice); }
            return;
        }
    }
    function drawTextFit(dc as Graphics.Dc, x, y, label, color, width) {
        var font = app.fonts.normal;
        if (dc.getTextWidthInPixels(label, font) > width || dc.getFontHeight(font) > 28) { font = app.fonts.small; }
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(x, y - dc.getFontHeight(font) / 2, font, label, Graphics.TEXT_JUSTIFY_CENTER);
    }
    function drawResult(dc as Graphics.Dc) {
        var dx = (dc.getWidth() - 280) / 2; var dy = (dc.getHeight() - 280) / 2;
        var won = app.engine.state[2] > app.engine.state[3];
        var color = won ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW;
        self.drawTextFit(dc,140 + dx,46 + dy,won ? "恭喜获胜" : "继续加油",color,180);
        self.drawTextFit(dc,140 + dx,76 + dy,app.engine.bestOf == 1 ? "单局完赛" : "三局两胜",Graphics.COLOR_WHITE,180);
        dc.setColor(color,Graphics.COLOR_BLACK);
        if (won) {
            dc.drawLine(113 + dx,103 + dy,167 + dx,103 + dy);
            dc.drawLine(113 + dx,103 + dy,122 + dx,140 + dy);
            dc.drawLine(167 + dx,103 + dy,158 + dx,140 + dy);
            dc.drawLine(122 + dx,140 + dy,158 + dx,140 + dy);
            dc.drawLine(140 + dx,140 + dy,140 + dx,164 + dy);
            dc.drawLine(121 + dx,166 + dy,159 + dx,166 + dy);
            dc.drawLine(113 + dx,110 + dy,101 + dx,110 + dy);
            dc.drawLine(101 + dx,110 + dy,110 + dx,132 + dy);
            dc.drawLine(110 + dx,132 + dy,120 + dx,132 + dy);
            dc.drawLine(167 + dx,110 + dy,179 + dx,110 + dy);
            dc.drawLine(179 + dx,110 + dy,170 + dx,132 + dy);
            dc.drawLine(170 + dx,132 + dy,160 + dx,132 + dy);
        } else {
            dc.drawLine(140 + dx,104 + dy,140 + dx,165 + dy);
            dc.drawLine(117 + dx,127 + dy,140 + dx,104 + dy);
            dc.drawLine(163 + dx,127 + dy,140 + dx,104 + dy);
            dc.drawLine(124 + dx,165 + dy,156 + dx,165 + dy);
        }
        // Six small line-drawn frames, no bitmaps/GIF or retained frame list.
        for (var i = 0; i < 2; i += 1) {
            var x = (i == 0 ? 84 : 196) + dx;
            var y = 111 + (resultFrame % 2) * 16 + i * 26 + dy;
            dc.drawLine(x - 4,y,x + 4,y); dc.drawLine(x,y - 4,x,y + 4);
        }
        self.drawTextFit(dc,140 + dx,198 + dy,"局数 " + app.engine.state[2].toString() + ":" +
            app.engine.state[3].toString(),Graphics.COLOR_WHITE,180);
        self.drawTextFit(dc,140 + dx,225 + dy,won ? "下一场再战" : "再接再厉",color,170);
        self.drawTextFit(dc,140 + dx,251 + dy,"4继续 稍后保存",Graphics.COLOR_LT_GRAY,150);
    }
    function onUpdate(dc as Graphics.Dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        if (self.frame()[3].equals("result")) { self.drawResult(dc); return; }
        var dx = (dc.getWidth() - 280) / 2; var dy = (dc.getHeight() - 280) / 2;
        var f = self.frame(); var title = f[0];
        if (f[3].equals("keys")) { title = app.locked ? "按键已锁定" : "按键已解锁"; }
        if (f[3].equals("activity")) { title = self.recordingState(); }
        var counterY = 54;
        if (f[3].equals("settle")) {
            // Split the requested long question inside the round top edge.
            self.drawTextFit(dc, 140 + dx, 28 + dy, "是否保存当前", Graphics.COLOR_WHITE, 150);
            self.drawTextFit(dc, 140 + dx, 54 + dy, "对局结果", Graphics.COLOR_WHITE, 150);
            counterY = 80;
        } else { self.drawTextFit(dc, 140 + dx, 28 + dy, title, Graphics.COLOR_WHITE, 180); }
        self.drawTextFit(dc, 140 + dx, counterY + dy, ((f[2] as Lang.Number) + 1).toString() + "/" + f[1].size().toString(), Graphics.COLOR_LT_GRAY, 110);
        for (var offset = -1; offset <= 1; offset += 1) {
            var count = f[1].size();
            if (count == 0) { continue; }
            var index = ((f[2] as Lang.Number) + offset + count) % count;
            // With one/two entries, avoid drawing duplicate neighbors.
            if ((count > 1 || offset == 0) && !(count == 2 && offset == -1)) {
                var y = 140 + offset * 50;
                if (offset == 0) {
                    dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
                    dc.fillRectangle(27 + dx, y - 15 + dy, 3, 30);
                }
                self.drawTextFit(dc, 140 + dx, y + dy, f[1][index][0],
                    offset == 0 ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, 214);
            }
        }
        self.drawTextFit(dc, 140 + dx, 234 + dy, "2/3选择 4确定", Graphics.COLOR_LT_GRAY, 170);
        self.drawTextFit(dc, 140 + dx, 258 + dy, "5返回", Graphics.COLOR_LT_GRAY, 100);
    }
}
class MatchMenuDelegate extends WatchUi.BehaviorDelegate {
    var menu;
    function initialize(view) { BehaviorDelegate.initialize(); menu = view; }
    function onPreviousPage() { menu.move(-1); return true; }
    function onNextPage() { menu.move(1); return true; }
    function onSelect() { menu.select(); return true; }
    function onBack() { menu.back(); return true; }
    function onMenu() { return true; }
}
