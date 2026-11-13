# v0.11.0 review decisions

The available cross-chat retrieval returned six defects and six design suggestions for v0.10.0 / f8c71ce, rather than a verbatim transcript. Each retrieved item was checked against the code.

| Item | Implemented result |
| --- | --- |
| Scoring bypasses game/recording start | Shared ensureStarted entry for START and direct scoring; failed recording start blocks the point. |
| Mixed score/time persistence generations | Single versioned snapshot commits scores, timing, preferences, checkpoints and history together. |
| Play continues after FIT succeeds and archive fails | Persisted settlement intent; frozen play/timing while pending; retries do not save the session again. |
| Stale recording actions after errors | Activity ancestors refresh on BACK using real session status. |
| Undoing service edits starts a ready game timer | Preserve game readiness; undoing a winning point reopens only that same game's timer. |
| Old live HR displayed after stopping | Clear live HR; retain saved summary; clear all metrics on discard. |
| Rules presets | Points/cap/format, interval and deciding-game change reminders, explicit future 15-point effective date. |
| Next-game first server | Winner-first mode plus explicit free-play mode. |
| Score-only pause | Root pause/resume freezes both clocks and scoring; links to activity when present. |
| Cross-screen double confirmation | Shared debounce and 350 ms transition guard, including returning to scoring. |
| Service shown on scoreboard | Actual server, left/right court and receiver with fixed player IDs. |
| Bounded match history | Eight compact matches, result/games first, date/mode/rules/time/game scores retained. |

The eight-match limit keeps the feature bounded on an older watch. Existing rotation, scoring boundaries, 64-step undo, staged next-game setup, Chinese font settings and primitive animation are preserved. Detailed FIT fields remain disabled. See [validation](VALIDATION_EN.md).
