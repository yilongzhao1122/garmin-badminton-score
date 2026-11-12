# Build and installation

[中文](INSTALL_CN.md) · [User guide](USER_GUIDE_EN.md)

This is a Connect IQ **watch application**, targeting Fēnix 6X Pro / Solar (`fenix6xpro`,280×280). Other devices require separate adaptation and validation. The watch menus are Chinese; the English guide includes a label glossary.

## Prepare the toolchain

1. Install [Visual Studio Code](https://code.visualstudio.com/).
2. Follow [Garmin's official setup](https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/) for the Monkey C extension and required Java environment.
3. Install [SDK Manager](https://developer.garmin.com/connect-iq/sdk/), download an SDK and select it as current.
4. Download the `fenix6xpro` device definition from Devices.
5. In VS Code, press Ctrl+Shift+P and run `Monkey C: Verify Installation`.

SDK version is different from the device API level. The manifest minimum is3.2.0; use APIs supported by the actual target. The SDK and device definition do not belong inside the project directory.

## Open, sign and simulate

1. Extract the source ZIP or clone the repository. Open its root folder, directly containing manifest.xml and monkey.jungle.
2. Configure your own Developer Key in the Monkey C extension. For a first project, use the extension's key-generation command. Store it outside the repository, back it up and keep the same key for updates.
3. Open source/BadmintonApp.mc → Ctrl+F5 → fenix6xpro. A `.mc` file is source text; opening it alone does not launch the app.
4. Click the simulator's side buttons. UP adds your point, DOWN adds the opponent's; START shows the court; BACK returns; holdUP for menus.
5. Run `Monkey C: Run Tests` for the 25 supplied native-format functions. Test next-game choices, service setup, save/discard, lock/unlock and BACK navigation.

Extension command names can vary slightly; search for Monkey C in the command palette. Simulator sensor values and activity sessions are not physical-watch evidence.

## Install on the watch

1. Use `Monkey C: Build for Device`, targeting fenix6xpro. Use a real-device build, not a `_sim` target output.
2. Locate the resulting PRG using the build log; the usual output is bin.
3. Connect a data-capableUSB cable and finish any current activity on the watch.
4. Copy the PRG into the watch's `GARMIN/APPS` directory. Use a consistent appID, signing key and filename for updates.
5. Safely eject and disconnect. Open 羽毛球计分 in the watch activity list; check its Add option if needed.

This source distribution has no precompiled PRG,IQ,SDK or signing key. The Chinese bitmap font is supplied; Python is unnecessary for normal compilation.

## Save and synchronize

Enable recording, pressSTART, wait for valid heart-rate sampling, finish and chooseYes to save. Synchronize the paired Garmin Connect phone app and inspect All Activities. The generic sport type may appear as Other.

The phone does not install this source code. Detailed scores/game times are local to the watch app; custom FIT fields are disabled by default. Choosing No discards only the currently unsaved activity, not previously saved ones.

| Symptom | Check |
| --- | --- |
| SDK/compiler missing | Select a current SDK and reload VS Code after correcting settings |
| No device target | Download fenix6xpro and check manifest.xml |
| Device-list download fails | Check network/account/SDK Manager; source changes cannot fix the service |
| Heart rate is -- | Enable recording on the real watch, check fit and wait for a sample |
| Scoring is blocked | Check scoring lock, current page and whether the game has ended |
| No detailed scores in Connect | They remain in the app; ordinary FIT synchronization is separate |
| Compile/runtime failure | Report full non-sensitive error, stack, device and SDK versions |

See [Validation](VALIDATION_EN.md). Never attach signing keys or personal FIT files to public issues.
