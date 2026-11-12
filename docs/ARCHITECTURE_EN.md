# Architecture

[中文](ARCHITECTURE.md)

| Module | Responsibility |
| --- | --- |
| ScoreEngine | Scores, game wins, match result, service rotation,64-action undo and packed state |
| BadmintonApp | Lifecycle, pages, match flow and persistence coordination |
| ScoreDelegate | Five-button input and scoring debounce |
| ScoreView / CourtUi / ServeUi | Score layout, court and service guidance |
| MatchMenu | Nested Chinese selection, wrapping navigation, game-end questions and lightweight result effects |
| RecordingController | Start, pause, resume, save, discard and failure handling |
| GarminRecordingBackend | Native ActivityRecording and activity-information adapter |
| MatchReport / GameCheckpoints | Game durations, match summary and at most three checkpoints |
| PerformanceStats / DataPagesUi | Heart rate, calories, duration and clock |
| ChineseFonts | Cached single 16 px bitmap font |
| MatchFitFields | Optional custom FIT exporter, disabled in the public default |

## State and persistence

Score state and activity sessions are independent. Next-game choices are staged and committed together on receiver confirmation; BACK cannot leave a half-completed transition. Repeated checkpoint saves replace the same game entry. Staging shares immutable bounded undo snapshots instead of copying the whole history.

Current state is cleared only after successful handling. If native FIT saving succeeds but local archiving fails, retry only completes the archive. A saved match becomes the last archive, then the app returns to ready. Ordinary system exit and explicitly ending a match use different handling.

## Resources and time

Only resources is the runtime resource path in monkey.jungle. Documentation/design previews are not watch backgrounds. BadmintonCN is a licensed subset; score digits use measured device fonts.

Game duration excludes between-game setup and manual pause. Match duration includes game breaks but excludes pause. Native activity duration may also include waiting at the final confirmation. Unknown timing stays unknown.
