# Contributing

[中文](../CONTRIBUTING.md)

Read the overview, architecture and validation report. Keep signing keys outside the repository. Check screen, buttons, API level and memory before adding another device.

## Changes and checks

1. Specify state, input, expected transition and persistence; distinguish rally, game, match and activity session.
2. Keep logic separate from UI/storage. Treat scoring lock/pause, BACK/undo and game checkpoints/final FIT as distinct operations.
3. Run the four Node checkers, then local SDK/native tests, official simulator and physical-device acceptance.
4. After editing Chinese text, verify font-glyph coverage. The optional generator requires Pillow, fontTools and Noto Sans CJK Bold; retain the font license.
5. Prefer primitives for courts/results. Do not repeatedly load fonts, allocate full-screen buffers or retain frame-image lists. Measure target-device peaks.

## Optional documentation tools

`node tools/check_serve_ui.cjs --preview` exports drawing commands. `python3 tools/render_preview.py` reconstructs illustrations using Pillow and system Noto CJK fonts. `python3 tools/build_guide.py --lang cn` or `--lang en` builds standalone guides. These are documentation tools, not a native Garmin renderer. Normal Garmin compilation does not need Python.

## Issues and releases

Provide device, firmware, SDK/extension versions, minimal steps, expected result and complete non-sensitive errors. Never attach keys, tokens, personal FIT or private logs.

Keep both language overviews, guides, VERSION, release notes and validation current. Run `python3 tools/package_release.py` for source ZIP, offline guides and checksums. Inspect the archive before publishing; it must not contain secrets, SDKs, compiled artifacts or personal paths. Describe current delivered behavior and actual validation only.
