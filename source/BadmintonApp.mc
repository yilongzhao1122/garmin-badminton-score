import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Attention;

class BadmintonApp extends Application.AppBase {
    var engine;
    var locked = false;
    var saveFailed = false;
    var notice = "";
    var recorder;
    var stats;
    var page = 0;
    var recordWanted = true;
    var closed = false;
    var lastMatch = null;
    var matchFitSaved = false;
    var fonts;
    var report;
    var checkpoints;

    function initialize() {
        AppBase.initialize();
        engine = new ScoreEngine(21, 30, 3);
        recorder = new RecordingController(new GarminRecordingBackend());
        stats = new PerformanceStats();
        fonts = new ChineseFonts();
        report = new MatchReport();
        checkpoints = new GameCheckpoints();
    }
    function onStart(state) {
        self.readSettings();
        try {
            lastMatch = Storage.getValue("last-match");
            var saved = Storage.getValue("match-v1");
            if (saved != null && engine.restore(saved)) {
                notice = "已恢复比分";
                // Lock belongs to this running session, never a permanent trap.
                locked = false;
                var wanted = Storage.getValue("record-wanted");
                recordWanted = wanted == null || wanted == true;
                matchFitSaved = Storage.getValue("match-fit-saved") == true;
                report.restore(Storage.getValue("match-report"), System.getTimer(),
                    engine.state[0] + engine.state[1] > 0 || engine.results.size() > 0);
                checkpoints.restore(Storage.getValue("game-saves")); checkpoints.reconcile(engine);
            } else { notice = "4开球 长按2菜单"; }
        } catch (e) { notice = "恢复失败"; }
    }
    function readSettings() {
        var size = 19;
        try {
            var value = Properties.getValue("MenuFontSize");
            if (value instanceof Lang.Number && (value == 16 || value == 19)) { size = value; }
        } catch (e) {}
        fonts.setMenuSize(size);
    }
    function onSettingsChanged() {
        self.readSettings();
        WatchUi.requestUpdate();
    }
    function onStop(state) {
        // Do not recreate the deleted active match after a deliberate finish.
        if (closed) { return; }
        self.refreshMetrics();
        if (recorder.hasSession() && self.finishRecording(false)) { matchFitSaved = true; }
        self.save();
    }
    function getInitialView() { return [new ScoreView(self), new ScoreDelegate(self)]; }
    function save() {
        if (closed) { return; }
        try {
            Storage.setValue("match-v1", engine.pack());
            Storage.setValue("record-wanted", recordWanted);
            Storage.setValue("match-fit-saved", matchFitSaved);
            Storage.setValue("match-report", report.pack());
            Storage.setValue("game-saves", checkpoints.pack());
            saveFailed = false;
        } catch (e) { saveFailed = true; }
    }
    function buzz(longBuzz) {
        if (Attention has :vibrate) {
            try { Attention.vibrate([new Attention.VibeProfile(longBuzz ? 70 : 50, longBuzz ? 220 : 45)]); }
            catch (e) {}
        }
    }
    function award(team) {
        self.refreshMatch();
        if (locked) { notice = "请先解锁按键"; }
        else if (recorder.status == 2) { notice = "请先继续记录"; }
        else if (!engine.serveReady()) { notice = "请设置接发球"; }
        else if (engine.point(team)) {
            if (!report.running) { report.begin(System.getTimer()); }
            self.updateFitScore();
            page = 0; notice = ""; self.save(); self.buzz(engine.state[4] != 0);
            WatchUi.requestUpdate(); return true;
        } else { notice = "本局结束 按4继续"; }
        WatchUi.requestUpdate(); return false;
    }
    function undo() {
        self.refreshMatch();
        if (locked) { notice = "请先解锁按键"; }
        else if (engine.undo()) {
            checkpoints.reconcile(engine);
            report.reconcile(engine); report.gameRunning = report.running && engine.state[4] == 0;
            self.updateFitScore(); notice = "已撤销"; self.save(); self.buzz(false);
        }
        else { notice = "暂无可撤销操作"; }
        WatchUi.requestUpdate();
    }
    function setLocked(value) {
        locked = value;
        notice = locked ? "请先解锁按键" : (recorder.status == 2 ? "请先继续记录" : "已解锁");
        WatchUi.requestUpdate();
    }
    function primarySelect() {
        if (page != 0) { return false; }
        if (locked) { notice = "请先解锁按键"; WatchUi.requestUpdate(); return false; }
        if (engine.state[4] == 0) { return self.startRally(); }
        showGameEndFlow(self); return true;
    }
    function saveCompletedGame(keep) {
        if (engine.state[4] == 0) { notice = "本局尚未结束"; return false; }
        self.refreshMatch();
        var proposed = new GameCheckpoints(); proposed.restore(checkpoints.pack());
        if (!proposed.setGame(engine.state[6] - 1,keep,engine,report)) { return false; }
        try { Storage.setValue("game-saves", proposed.pack()); }
        catch (e) { notice = "本局保存失败"; return false; }
        checkpoints = proposed; notice = keep ? "本局已保存" : "本局未单存";
        return true;
    }
    function prepareNextGame(server, receiver) {
        self.refreshMatch();
        if (locked || engine.state[4] != 1) { notice = "尚不能开始下一局"; return false; }
        if (server < 0 || server > 3 || receiver < 0 || receiver > 3 ||
            (server < 2) == (receiver < 2) ||
            (!engine.isDoubles() && (server == 1 || server == 3 || receiver == 1 || receiver == 3))) {
            notice = "接发球无效"; return false;
        }
        // Stage ALL choices on a candidate. BACK/NO never increments game no.
        var candidate = new ScoreEngine(engine.target,engine.cap,engine.bestOf);
        // Copy only current state/results. Reuse immutable undo snapshots rather
        // than deep-copying up to 64 old states during a menu transition.
        var base = engine.pack(); base[6] = [];
        if (!candidate.restore(base) || !candidate.nextGame()) { return false; }
        var groupedHistory = [];
        var first = engine.history.size() >= 64 ? engine.history.size() - 63 : 0;
        for (var i = first; i < engine.history.size(); i += 1) { groupedHistory.add(engine.history[i]); }
        groupedHistory.add(candidate.history[0]);
        if (candidate.isDoubles()) {
            var standardServer = candidate.state[5] == 0 ? 0 : 2;
            if (!candidate.configureService(standardServer,standardServer == 0 ? 2 : 0) ||
                !candidate.editService(server,receiver)) { notice = "接发球无效"; return false; }
        } else { candidate.setServer(server < 2 ? 0 : 1); }
        // One undo restores the previous terminal scoreboard and lineup.
        candidate.history = groupedHistory;
        try { Storage.setValue("match-v1", candidate.pack()); }
        catch (e) { notice = "下一局保存失败"; return false; }
        engine = candidate; report.gameRunning = false; report.reconcile(engine);
        page = 0; saveFailed = false; notice = "下一局准备 按4开球";
        WatchUi.requestUpdate(); return true;
    }
    function startRally() {
        self.refreshMatch();
        if (page != 0) { return false; }
        if (locked) { notice = "请先解锁按键"; }
        else if (recorder.status == 2) { notice = "请先继续记录"; }
        else if (engine.state[4] != 0) { notice = "本局结束 按4继续"; }
        else if (!engine.serveReady()) { notice = "请设置接发球"; }
        else {
            // Default: start recording at the first real rally, not retrospectively
            // at exit. An explicit Score only match never auto-starts a session.
            if (recordWanted && !recorder.hasSession() && recorder.status != 3) {
                if (!recorder.start()) { notice = recorder.lastError; WatchUi.requestUpdate(); return false; }
                stats.reset();
            }
            report.begin(System.getTimer()); self.updateFitScore();
            notice = ""; page = 3; self.save(); WatchUi.requestUpdate(); return true;
        }
        WatchUi.requestUpdate(); return false;
    }
    function newMatch(points, ceiling, games, withRecording, mode, server, receiver) {
        if (recorder.hasSession()) { notice = "请先保存运动"; return false; }
        var proposed = new ScoreEngine(points, ceiling, games);
        if (!proposed.setMatchMode(mode) ||
            (mode == 1 && !proposed.configureService(server, receiver))) { notice = "接发球无效"; return false; }
        if (mode == 0) { proposed.setServer(server < 2 ? 0 : 1); }
        // A configured match stays ready. START begins its first activity.
        recorder.scoreOnly();
        engine = proposed; recordWanted = withRecording; closed = false; matchFitSaved = false;
        report = new MatchReport();
        checkpoints = new GameCheckpoints();
        stats.reset(); page = 0; locked = false; notice = "准备比赛 按4开始";
        self.save(); WatchUi.requestUpdate(); return true;
    }
    function editServe(server, receiver, firstSetup) {
        if (locked) { notice = "请先解锁按键"; return false; }
        var ok = firstSetup ? engine.configureService(server, receiver) : engine.editService(server, receiver);
        notice = ok ? "接发球已更新" : "无法修改接发球";
        if (ok) { page = 0; self.save(); }
        WatchUi.requestUpdate(); return ok;
    }
    function nextGame() {
        self.refreshMatch();
        if (locked) { notice = "请先解锁按键"; return false; }
        if (!engine.nextGame()) { notice = "尚不能开始下一局"; return false; }
        report.gameRunning = false;
        page = 0; notice = engine.serveReady() ? "下一局已准备" : "请设置接发球";
        self.save(); WatchUi.requestUpdate(); return true;
    }
    function recordingAction(action) {
        var ok = false; self.refreshMetrics();
        if (action.equals("recStart")) {
            ok = recorder.start();
            if (ok) { stats.reset(); recordWanted = true; if (!report.running) { report.begin(System.getTimer()); } self.updateFitScore(); }
        }
        if (action.equals("recPause")) { ok = recorder.pause(); }
        if (action.equals("recResume")) { ok = recorder.resume(); }
        if (action.equals("recSave")) { ok = self.finishRecording(false); if (ok) { recordWanted = false; } }
        if (action.equals("recDiscard")) { ok = recorder.discard(); if (ok) { recordWanted = false; } }
        if (ok && recorder.status == 3) { matchFitSaved = true; }
        notice = ok ? (recorder.status == 3 ? "运动已保存" : "") : recorder.lastError;
        self.save(); WatchUi.requestUpdate(); return ok;
    }
    function saveAndExit() {
        if (closed) { return true; }
        self.refreshMetrics();
        if (!self.finishRecording(true)) { notice = recorder.lastError; WatchUi.requestUpdate(); return false; }
        if (recorder.status == 3) { matchFitSaved = true; }
        return self.commitExit();
    }
    function discardAndExit() {
        if (closed) { return true; }
        // Discard only the current unsaved session. Earlier saved FIT files
        // remain untouched and their match flag is retained.
        if (!recorder.discard()) { notice = recorder.lastError; WatchUi.requestUpdate(); return false; }
        recordWanted = false;
        return self.commitExit();
    }
    function commitExit() {
        // Caller has saved/discarded the current activity. Archive only scores here.
        // Last-match archive, then delete active score. If storage fails,
        // stay in app for retry; status 3 prevents a duplicate FIT save on retry.
        try {
            var packed = engine.pack(); packed[6] = [];
            if (self.hasCurrentMatch()) {
                var allGames = new GameCheckpoints(); allGames.restore(checkpoints.pack()); allGames.includeCompleted(engine,report);
                lastMatch = [packed, matchFitSaved, report.totalMs, report.pack(), engine.state[4] != 2, allGames.pack()];
                Storage.setValue("last-match", lastMatch);
            }
            Storage.deleteValue("match-v1");
            Storage.deleteValue("record-wanted");
            Storage.deleteValue("match-fit-saved");
            Storage.deleteValue("match-report");
            Storage.deleteValue("game-saves");
            saveFailed = false; closed = true;
        } catch (e) {
            // Recreate a resumable active score if part of the storage commit failed.
            closed = false; self.save(); saveFailed = true;
            notice = "比分保存失败"; WatchUi.requestUpdate(); return false;
        }
        System.exit(); return true;
    }
    function hasCurrentMatch() {
        return report.started || recorder.hasSession() || matchFitSaved ||
            engine.state[0] + engine.state[1] > 0 || engine.results.size() > 0;
    }
    function refreshMatch() {
        report.tick(System.getTimer(), recorder.status == 2, engine);
    }
    function updateFitScore() {
        if (!recorder.hasSession()) { return; }
        try { recorder.backend.updateScore(engine); }
        catch (e) { notice = "比分写入失败"; }
    }
    function finishRecording(ended) {
        if (recorder.hasSession() && recorder.started) {
            try { recorder.backend.writeSummary(engine, report, ended); }
            catch (e) { recorder.lastError = "比分写入失败"; return false; }
        }
        return recorder.finish();
    }
    // Finish the current match and remain inside the app. YES archives both
    // score and any pending FIT; NO discards only pending FIT and no new score.
    // Store errors preserve the current score for retry. A saved FIT is never
    // written twice, and an older saved FIT cannot be deleted by NO.
    function endCurrent(keepResult) {
        self.refreshMetrics();
        var hadMatch = self.hasCurrentMatch();
        if (keepResult) {
            if (!self.finishRecording(true)) { notice = recorder.lastError; return false; }
            if (recorder.status == 3) { matchFitSaved = true; }
        } else if (!recorder.discard()) { notice = recorder.lastError; return false; }
        var fresh = new ScoreEngine(engine.target, engine.cap, engine.bestOf);
        fresh.setMatchMode(engine.isDoubles() ? 1 : 0);
        if (fresh.isDoubles()) { fresh.configureService(0, 2); }
        var nextReport = new MatchReport();
        var nextCheckpoints = new GameCheckpoints();
        var archive = lastMatch;
        try {
            if (keepResult && hadMatch) {
                var packed = engine.pack(); packed[6] = [];
                var allGames = new GameCheckpoints(); allGames.restore(checkpoints.pack()); allGames.includeCompleted(engine,report);
                archive = [packed,matchFitSaved,report.totalMs,report.pack(),engine.state[4] != 2,allGames.pack()];
                Storage.setValue("last-match", archive);
            }
            Storage.setValue("match-v1", fresh.pack());
            Storage.setValue("record-wanted", recordWanted);
            Storage.setValue("match-fit-saved", false);
            Storage.setValue("match-report", nextReport.pack());
            Storage.setValue("game-saves", nextCheckpoints.pack());
        } catch (e) {
            self.save(); saveFailed = true; notice = "比分保存失败";
            WatchUi.requestUpdate(); return false;
        }
        engine = fresh; report = nextReport; checkpoints = nextCheckpoints; lastMatch = archive;
        recorder.scoreOnly(); matchFitSaved = false; stats.reset();
        closed = false; locked = false; page = 0; saveFailed = false;
        notice = "准备比赛 按4开始"; WatchUi.requestUpdate(); return true;
    }
    function showPage(target) {
        if (target < 0 || target > 2) { return; }
        page = target; WatchUi.requestUpdate();
    }
    function refreshMetrics() {
        self.refreshMatch();
        if (!recorder.hasSession()) { return; }
        try { stats.capture(recorder.backend.info()); } catch (e) { stats.capture(null); }
    }
}
