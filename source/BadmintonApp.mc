import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Attention;
import Toybox.Time;

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
    var paused = false;
    var settling = false;
    // 0 free first server; 1 previous winner serves.
    var ruleMode = 0;
    var archives;
    var matchDate = 0;
    var inputAt = -1000;
    var blockedUntil = 0;

    function initialize() {
        AppBase.initialize();
        engine = new ScoreEngine(21, 30, 3);
        recorder = new RecordingController(new GarminRecordingBackend());
        stats = new PerformanceStats();
        fonts = new ChineseFonts();
        report = new MatchReport();
        checkpoints = new GameCheckpoints();
        archives = []; matchDate = Time.now().value();
    }
    function onStart(state) {
        self.readSettings();
        try {
            var snapshot = Storage.getValue("match-state-v2");
            if (snapshot != null) {
                if (snapshot.size() != 3 || snapshot[0] != 2 || snapshot[2].size() > 8) {
                    notice = "恢复失败"; return;
                }
                archives = snapshot[2]; lastMatch = archives.size() > 0 ? archives[0] : null;
                var current = snapshot[1];
                if (current == null) { notice = "4开球 长按2菜单"; return; }
                if (current.size() != 9 || !engine.restore(current[0])) { notice = "恢复失败"; return; }
                recordWanted = current[1] == true; matchFitSaved = current[2] == true;
                report.restore(current[3], System.getTimer(), true);
                checkpoints.restore(current[4]); checkpoints.reconcile(engine);
                paused = current[5] == true; settling = current[6] == true;
                ruleMode = current[7] == 1 ? 1 : 0; matchDate = current[8];
                notice = settling ? "结算待完成 请重试" : "已恢复比分 按4继续";
            } else {
                // One-time migration. New snapshots are authoritative even when
                // active=null; old keys can never resurrect a finished match.
                lastMatch = Storage.getValue("last-match");
                if (lastMatch != null) { archives = [lastMatch]; }
                var saved = Storage.getValue("match-v1");
                if (saved != null && engine.restore(saved)) {
                    var wanted = Storage.getValue("record-wanted");
                    recordWanted = wanted == null || wanted == true;
                    matchFitSaved = Storage.getValue("match-fit-saved") == true;
                    report.restore(Storage.getValue("match-report"), System.getTimer(),
                        engine.state[0] + engine.state[1] > 0 || engine.results.size() > 0);
                    checkpoints.restore(Storage.getValue("game-saves")); checkpoints.reconcile(engine);
                    notice = "已恢复比分 按4继续";
                } else { notice = "4开球 长按2菜单"; }
                self.save();
            }
            locked = false;
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
    function activeState(e, r, c, wanted, fitSaved) {
        return [e.pack(), wanted, fitSaved, r.pack(), c.pack(), paused, settling, ruleMode, matchDate];
    }
    function persist(active, history) {
        try {
            // Score, timing, checkpoint choices, intent and archives in ONE
            // Storage value. Never publish a mixture of generations.
            Storage.setValue("match-state-v2", [2, active, history]);
            saveFailed = false; return true;
        } catch (e) { saveFailed = true; return false; }
    }
    function save() {
        if (closed) { return false; }
        return self.persist(self.activeState(engine, report, checkpoints, recordWanted, matchFitSaved), archives);
    }
    function blockInput() { blockedUntil = System.getTimer() + 350; }
    function acceptInput() {
        var now = System.getTimer();
        if (now < blockedUntil || (now >= inputAt && now - inputAt < 250)) { return false; }
        inputAt = now; return true;
    }
    function canPlay() {
        if (settling) { notice = "结算待完成 请重试"; return false; }
        if (locked) { notice = "请先解锁按键"; return false; }
        if (recorder.status == 2) { notice = "请先继续记录"; return false; }
        if (paused) { notice = "请先继续比赛"; return false; }
        return true;
    }
    function ensureStarted() {
        if (!self.canPlay()) { return false; }
        if (engine.state[4] != 0) { notice = "本局结束 按4继续"; return false; }
        if (!engine.serveReady()) { notice = "请设置接发球"; return false; }
        if (recordWanted && !recorder.hasSession()) {
            if (!recorder.start()) { notice = recorder.lastError; self.save(); return false; }
            stats.reset();
        }
        if (!report.running || !report.gameRunning) { report.begin(System.getTimer()); }
        return true;
    }
    function setMatchPaused(value) {
        self.refreshMatch();
        if (settling) { notice = "结算待完成 请重试"; return false; }
        if (value && recorder.status == 1 && !recorder.pause()) { notice = recorder.lastError; return false; }
        if (!value && recorder.status == 2 && !recorder.resume()) { notice = recorder.lastError; return false; }
        paused = value; notice = value ? "比赛已暂停" : "比赛已继续";
        self.save(); WatchUi.requestUpdate(); return true;
    }
    function buzz(longBuzz) {
        if (Attention has :vibrate) {
            try { Attention.vibrate([new Attention.VibeProfile(longBuzz ? 70 : 50, longBuzz ? 220 : 45)]); }
            catch (e) {}
        }
    }
    function award(team) {
        self.refreshMatch();
        if ((team == 0 || team == 1) && self.ensureStarted() && engine.point(team)) {
            self.updateFitScore();
            var threshold = engine.target == 21 ? 11 : (engine.target == 15 ? 8 : 0);
            notice = "";
            if (threshold > 0 && engine.state[team] == threshold && engine.state[1-team] < threshold) {
                notice = engine.state[6] == 3 ? "间歇并交换场地" : "局中间歇";
            }
            if (engine.state[4] != 0) { report.gameRunning = false; }
            page = 0; self.save(); self.buzz(engine.state[4] != 0 || !notice.equals(""));
            WatchUi.requestUpdate(); return true;
        }
        WatchUi.requestUpdate(); return false;
    }
    function undo() {
        self.refreshMatch();
        var oldGame = engine.state[6]; var oldPhase = engine.state[4];
        var wasGameRunning = report.gameRunning;
        if (settling) { notice = "结算待完成 请重试"; }
        else if (locked) { notice = "请先解锁按键"; }
        else if (engine.undo()) {
            checkpoints.reconcile(engine);
            report.reconcile(engine);
            report.gameRunning = report.running && engine.state[4] == 0 &&
                oldGame == engine.state[6] && (wasGameRunning || oldPhase != 0);
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
        if (!self.persist(self.activeState(engine,report,proposed,recordWanted,matchFitSaved),archives)) {
            notice = "本局保存失败"; return false;
        }
        checkpoints = proposed; notice = keep ? "本局已保存" : "本局未单存";
        return true;
    }
    function prepareNextGame(server, receiver) {
        self.refreshMatch();
        if (settling || locked || engine.state[4] != 1) { notice = "尚不能开始下一局"; return false; }
        if (server < 0 || server > 3 || receiver < 0 || receiver > 3 ||
            (server < 2) == (receiver < 2) ||
            (!engine.isDoubles() && (server == 1 || server == 3 || receiver == 1 || receiver == 3))) {
            notice = "接发球无效"; return false;
        }
        if (ruleMode == 1 && (server < 2 ? 0 : 1) != engine.state[5]) {
            notice = "上局胜方先发球"; return false;
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
        var nextReport = new MatchReport();
        nextReport.restore(report.pack(), System.getTimer(), report.started);
        nextReport.running = report.running; nextReport.gameRunning = false; nextReport.reconcile(candidate);
        if (!self.persist(self.activeState(candidate,nextReport,checkpoints,recordWanted,matchFitSaved),archives)) {
            notice = "下一局保存失败"; return false;
        }
        engine = candidate; report = nextReport;
        page = 0; saveFailed = false; notice = "下一局准备 按4开球";
        WatchUi.requestUpdate(); return true;
    }
    function startRally() {
        self.refreshMatch();
        if (page == 0 && self.ensureStarted()) {
            self.updateFitScore(); notice = ""; page = 3;
            self.save(); WatchUi.requestUpdate(); return true;
        }
        WatchUi.requestUpdate(); return false;
    }
    function newMatch(points, ceiling, games, withRecording, mode, server, receiver) {
        if (settling || recorder.hasSession()) { notice = "请先结束当前对局"; return false; }
        var proposed = new ScoreEngine(points, ceiling, games);
        if (!proposed.setMatchMode(mode) ||
            (mode == 1 && !proposed.configureService(server, receiver))) { notice = "接发球无效"; return false; }
        if (mode == 0) { proposed.setServer(server < 2 ? 0 : 1); }
        // A configured match stays ready. START begins its first activity.
        var nextReport = new MatchReport(); var nextCheckpoints = new GameCheckpoints();
        var date = Time.now().value();
        var current = [proposed.pack(),withRecording,false,nextReport.pack(),nextCheckpoints.pack(),false,false,ruleMode,date];
        if (!self.persist(current,archives)) { notice = "新建保存失败"; return false; }
        recorder.scoreOnly();
        engine = proposed; recordWanted = withRecording; closed = false; matchFitSaved = false;
        report = nextReport; checkpoints = nextCheckpoints;
        paused = false; settling = false; matchDate = date;
        stats.reset(); page = 0; locked = false; notice = "准备比赛 按4开始";
        WatchUi.requestUpdate(); return true;
    }
    function editServe(server, receiver, firstSetup) {
        if (settling || locked) { notice = "请先结束或解锁"; return false; }
        if (ruleMode == 1 && engine.state[6] > 1 && engine.state[0] + engine.state[1] == 0 &&
            (server < 2 ? 0 : 1) != engine.state[5]) { notice = "上局胜方先发球"; return false; }
        var ok = firstSetup ? engine.configureService(server, receiver) : engine.editService(server, receiver);
        notice = ok ? "接发球已更新" : "无法修改接发球";
        if (ok) { page = 0; self.save(); }
        WatchUi.requestUpdate(); return ok;
    }
    function nextGame() {
        self.refreshMatch();
        if (settling || locked) { notice = "请先结束或解锁"; return false; }
        if (!engine.nextGame()) { notice = "尚不能开始下一局"; return false; }
        report.gameRunning = false;
        page = 0; notice = engine.serveReady() ? "下一局已准备" : "请设置接发球";
        self.save(); WatchUi.requestUpdate(); return true;
    }
    function recordingAction(action) {
        var ok = false; self.refreshMetrics();
        if (settling) { notice = "结算待完成 请重试"; return false; }
        if (action.equals("recStart")) {
            ok = recorder.start();
            if (ok) { stats.reset(); recordWanted = true; self.updateFitScore(); }
        }
        if (action.equals("recPause")) { ok = recorder.pause(); }
        if (action.equals("recResume")) { ok = recorder.resume(); }
        if (action.equals("recSave")) { ok = self.finishRecording(false); if (ok) { recordWanted = false; } }
        if (action.equals("recDiscard")) { ok = recorder.discard(); if (ok) { recordWanted = false; stats.reset(); } }
        if (ok && action.equals("recPause")) { paused = true; }
        if (ok && action.equals("recResume")) { paused = false; }
        if (ok && recorder.status == 3) { matchFitSaved = true; stats.capture(null); }
        notice = ok ? (recorder.status == 3 ? "运动已保存" : "") : recorder.lastError;
        self.save(); WatchUi.requestUpdate(); return ok;
    }
    function saveAndExit() { return self.completeMatch(true, true, true); }
    function discardAndExit() { return self.completeMatch(true, false, true); }
    function endCurrent(keepResult) { return self.completeMatch(keepResult, keepResult, false); }
    function completeMatch(keepScores, keepFit, exitApp) {
        if (closed) { return true; }
        self.refreshMetrics();
        var hadMatch = self.hasCurrentMatch();
        // Persist settlement intent BEFORE an irreversible FIT operation.
        // If FIT succeeds but storage fails, play stays frozen for retry.
        settling = true;
        if (!self.save()) { notice = "比分保存失败"; return false; }
        if (keepFit) {
            if (!self.finishRecording(true)) { notice = recorder.lastError; self.save(); return false; }
            if (recorder.status == 3) { matchFitSaved = true; }
        } else if (!recorder.discard()) { notice = recorder.lastError; self.save(); return false; }
        stats.capture(null);
        var history = [] as Lang.Array;
        if (keepScores && hadMatch) {
            var packed = engine.pack() as Lang.Array; packed[6] = [] as Lang.Array;
            var allGames = new GameCheckpoints(); allGames.restore(checkpoints.pack()); allGames.includeCompleted(engine,report);
            history.add([packed, matchFitSaved, report.totalMs, report.pack(), engine.state[4] != 2,
                allGames.pack(), matchDate, ruleMode]);
        }
        for (var i = 0; i < archives.size() && history.size() < 8; i += 1) { history.add(archives[i]); }
        var fresh = new ScoreEngine(engine.target, engine.cap, engine.bestOf);
        fresh.setMatchMode(engine.isDoubles() ? 1 : 0);
        if (fresh.isDoubles()) { fresh.configureService(0,2); }
        var nextReport = new MatchReport(); var nextCheckpoints = new GameCheckpoints();
        var current = exitApp ? null : [fresh.pack(),recordWanted,false,nextReport.pack(),nextCheckpoints.pack(),false,false,ruleMode,Time.now().value()];
        if (!self.persist(current,history)) {
            // Best effort persists the saved-FIT flag, never another FIT call.
            self.save(); saveFailed = true; notice = "结算待完成 请重试";
            WatchUi.requestUpdate(); return false;
        }
        archives = history; lastMatch = history.size() > 0 ? history[0] : null;
        engine = fresh; report = nextReport; checkpoints = nextCheckpoints;
        if (!exitApp) { recorder.scoreOnly(); }
        stats.reset(); matchFitSaved = false;
        paused = false; settling = false; locked = false; page = 0;
        matchDate = Time.now().value(); closed = exitApp;
        notice = "准备比赛 按4开始"; WatchUi.requestUpdate();
        if (exitApp) { System.exit(); }
        return true;
    }
    function hasCurrentMatch() {
        return report.started || recorder.hasSession() || matchFitSaved ||
            engine.state[0] + engine.state[1] > 0 || engine.results.size() > 0;
    }
    function refreshMatch() {
        report.tick(System.getTimer(), paused || settling || recorder.status == 2, engine);
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
    function showPage(target) {
        if (target < 0 || target > 2) { return; }
        page = target; WatchUi.requestUpdate();
    }
    function refreshMetrics() {
        self.refreshMatch();
        if (!recorder.hasSession() || recorder.status != 1) { stats.capture(null); return; }
        try { stats.capture(recorder.backend.info()); } catch (e) { stats.capture(null); }
    }
}
