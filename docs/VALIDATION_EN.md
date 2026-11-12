# Validation scope · v0.10.0

[中文](../VALIDATION.md)

Target: `fenix6xpro`. Only checks actually executed are marked as passed.

| Layer | Status |
| --- | --- |
| Scoring, service rotation, undo and archive compatibility | 21 checks passed |
| Activity-controller lifecycle with mock sessions | 10 checks passed |
| Heart-rate/calorie snapshots with mock data | 4 checks passed |
| Raw declarations, application, menus, game-end flow, FIT interfaces and drawing mocks | 131 checks passed |
| Garmin Run No Evil | 25 functions supplied; not executed in release preparation |
| Garmin SDK compilation / official simulator | Not executed in release preparation |
| Physical-device memory/sensors, real FIT save and Connect sync | Not executed in release preparation |

The166 Node checks adapt the same MC source and use mock APIs. They cannot prove native compilation, all runtime typing, safe heap peaks or actual FIT content.

```sh
node tools/check_engine.cjs
node tools/check_recording.cjs
node tools/check_performance.cjs
node tools/check_serve_ui.cjs
```

## Coverage

- Singles/doubles scoring, service parity, independent rotation reference checks and undo.
- Default-Yes questions, No preserving the terminal score, repeated entry and idempotent checkpoint saving.
- Staged receiver confirmation before next-game commit; grouped undo at 0:0.
- Single-game and best-of-three completion,21:20 continuation, save/discard returning to ready.
- State retained on failure and retry without duplicate FIT saving.
- Separate lock/pause, nested BACK navigation and menu wrapping.
- Default production backend with no custom FIT field allocation.
- At most six result-effect frames, fewer than 50 mocked drawing calls per frame, no background-image loads.

## Native acceptance

Compile with the official SDK, run native tests, inspect physical-button behavior, timers, Chinese glyphs and peak memory in the official simulator, then exercise a full match, save/discard, sensors and phone sync on the actual target. Record SDK, firmware, steps and outcomes.

Preview images are reconstructed on a computer from drawing commands; number fonts are approximate. They are not Garmin screenshots or evidence of native acceptance. Resource file size is not a runtime heap measurement.

Additional mocked checks cover startup 19/16, invalid defaults, live updates preserving match/session, no font reload, consistent 19px menus, wrapping and circular glyph bounds. Real phone transport and store review were not executed.
