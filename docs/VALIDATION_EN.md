# Validation · v0.11.0

[中文](../VALIDATION.md) · [English](VALIDATION_EN.md)

| Layer | Result |
| --- | --- |
| Scoring/rotation/undo/migration | 21 passed |
| Recording lifecycle mocks | 10 passed |
| Metric snapshot mocks | 4 passed |
| Application/menu/storage-fault/render and review regressions | 161 passed |
| Official Monkey C compiler Debug / Release | SDK 9.3.0, passed using generated device descriptors |
| Run No Evil program compilation | Passed; tests not executed natively |
| Official device package, simulator, watch heap/FIT/Connect sync | Not executed |

196 Node checks pass, including 30 new regression scenarios. Existing tests were updated for the versioned snapshot and changed input/menu behavior.

Compiler checks use SDK 9.3.0 (2026-10-20) and fenix6xpro descriptors generated from metadata bundled in that SDK, with estimated memory limits and a temporary signing key. They do not use the official SDK Manager device package or prove watch heap safety. Dynamic-container inference warnings remain. Test PRGs and keys are excluded from distribution; use the original signing key for device/store updates.

Storage fault tests cover coherent restoration, pending settlement, no duplicate session save and failure before irreversible FIT operations. Other cases cover direct scoring startup, next-game timing, failure-menu refresh, undo at READY, score-only pause, live-HR clearing, cross-view input guards, service hints, winner-first/free-play rules and eight-match history.

Production recording still allocates zero developer fields. Court/result graphics remain primitives. Native tests, real sensors and Connect synchronization require separate execution on the target device. Documentation previews are reconstructed draw commands, not watch screenshots.
