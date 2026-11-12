// Device-independent recording lifecycle. Backend/session APIs are injected so
// start, pause, resume and failed-save handling can be checked without a watch.
// Status: 0 score only, 1 recording, 2 paused, 3 successfully saved.
class RecordingController {
    var backend;
    var session;
    var status;
    var elapsedMs;
    var lastTick;
    var lastError;
    var started = false;

    function initialize(recordingBackend) {
        self.backend = recordingBackend;
        self.session = null;
        self.status = 0;
        self.elapsedMs = 0;
        self.lastTick = 0;
        self.lastError = "";
    }

    function hasSession() { return self.session != null; }

    function refresh() {
        if (self.status == 1) {
            var now = self.backend.now();
            if (now >= self.lastTick) { self.elapsedMs += now - self.lastTick; }
            self.lastTick = now;
        }
    }

    function start() {
        if (self.session != null) { return false; }
        self.lastError = "";
        try {
            self.session = self.backend.createSession();
            if (self.session == null) { self.lastError = "无法创建运动"; return false; }
            self.status = 2;
            self.started = false;
            self.elapsedMs = 0;
            if (self.session.isRecording()) {
                // Do not issue a second start on an existing recording.
                self.lastError = "运动已经记录";
                self.status = 1;
                self.started = true;
                self.lastTick = self.backend.now();
                return true;
            }
            if (!self.session.start()) { self.lastError = "运动开始失败"; return false; }
            self.status = 1;
            self.started = true;
            self.lastTick = self.backend.now();
            return true;
        } catch (e) {
            self.lastError = "运动开始异常";
            return false;
        }
    }

    function pause() {
        if (self.status != 1 || self.session == null) { return false; }
        self.refresh();
        try {
            if (self.session.isRecording() && !self.session.stop()) { self.lastError = "暂停失败"; return false; }
            self.status = 2;
            self.lastError = "";
            return true;
        } catch (e) { self.lastError = "暂停异常"; return false; }
    }

    function resume() {
        if (self.status != 2 || self.session == null) { return false; }
        try {
            if (!self.session.start()) { self.lastError = "继续失败"; return false; }
            self.status = 1;
            self.started = true;
            self.lastTick = self.backend.now();
            self.lastError = "";
            return true;
        } catch (e) { self.lastError = "继续异常"; return false; }
    }

    function finish() {
        if (self.session == null) { return true; }
        if (!self.started) { self.lastError = "尚未记录"; return false; }
        if (self.status == 1 && !self.pause()) { return false; }
        try {
            if (!self.session.save()) {
                // Keep the session available for a retry. Never show SAVED
                // or allow exit merely because stop() succeeded.
                self.lastError = "运动保存失败";
                return false;
            }
            self.session = null;
            self.status = 3;
            self.lastError = "";
            return true;
        } catch (e) { self.lastError = "运动保存异常"; return false; }
    }

    function discard() {
        if (self.session == null) { return true; }
        if (self.status == 1 && !self.pause()) { return false; }
        try {
            if (!self.session.discard()) { self.lastError = "放弃失败"; return false; }
            self.session = null;
            self.status = 0;
            self.started = false;
            self.elapsedMs = 0;
            self.lastError = "";
            return true;
        } catch (e) { self.lastError = "放弃异常"; return false; }
    }

    function scoreOnly() {
        if (self.session != null) { return false; }
        self.status = 0;
        self.started = false;
        self.elapsedMs = 0;
        self.lastError = "";
        return true;
    }
}
