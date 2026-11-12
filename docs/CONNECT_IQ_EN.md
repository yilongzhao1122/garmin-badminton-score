# Connect IQ submission and phone settings

[中文](CONNECT_IQ_CN.md) · [User guide](USER_GUIDE_EN.md)

## Settings versus application updates

An App Settings change sends a value such asMenuFontSize=19 to code already installed on the watch. It does not edit Monkey C source or generate a new font. New functionality still requires a developer-built update, but a store-installed app can receive that update through Garmin synchronization rather than USB sideloading.

This project is a device/watch application, not a Watch Face. `.prg` is the device-side build file; `.iq` is the store submission package. A GitHub source Release does not itself publish to Garmin.

## Implementation

- resources/settings/properties.xml: numeric MenuFontSize with default 19.
- resources/settings/settings.xml: phone list with19px and16px choices.
- resources/strings/settings.xml and resources-zhs/strings/settings.xml: English/Simplified Chinese form labels.
- BadmintonApp: read Application.Properties at startup, reload in onSettingsChanged, request redraw.
- ChineseFonts: reuse cached 16px labels and19px menus; no per-frame font loading.

All menu titles, rows, counters and hints use the selected size; long text wraps to at most two lines. Score/court/player fonts retain their sizes. Phone changes never reset scores, change the current format, or stop/save/discard the activity. Other match options remain available in the watch menus.

## Test locally

Run the project in the official simulator. Use File → Edit Persistent Storage → Edit Application.Properties data, or the corresponding SDK menu, to setMenuFontSize to 16/19. Verify live redraw, startup persistence, unchanged match/session and native memory. A Trigger App Settings event alone does not define or change property values.

Adapted-source/mocked-API checks were executed. Native compilation, real phone transport, peak device heap and Garmin review were not performed in release preparation.

## Build and submit

1. Open the completev0.10.0 project in VS Code. Keep your existing Developer Key outside the repository and back it up.
2. Verify watch-app type, unchanged appID andfenix6xpro target. Do not claim other devices without testing.
3. Run SDK compilation, native tests, simulator and target-watch acceptance, including activity saving, menus, font bounds and memory.
4. Run **Monkey C: Export Project** and follow its wizard to produce an IQ using your own key and supported products/languages. If prompted, use version0.10.0. Renaming a PRG or ZIP does not create an IQ.
5. Visit [Garmin Submit an App](https://developer.garmin.com/connect-iq/submit-an-app/), sign in and complete the developer requirements. The account owner should read/accept any required agreement.
6. Upload theIQ. After validation, supply the device-app category, bilingual name/descriptions, support details and requested data-handling information. Follow current upload-form image requirements.
7. Use actual simulator/watch screenshots. Repository illustrations are computer reconstructions and must not be represented as native screenshots.
8. Use the developer preview/testing process to install and test phone settings and actual FIT/Connect behavior. Garmin states that developers can preview/download their uploaded app before approval.
9. Submit for review when ready; public availability follows approval. GitHub publication is separate.

The repository contains source and setting definitions, not an exported signed IQ. Your private key stays on your computer.

## Change size from the phone

After installing the corresponding version through the store, keep phone/watch connected. Open Connect IQ Store → Device/My Device → My Device Apps → 羽毛球计分 → Settings → Menu text size →19px or 16px → Save. Wait for transfer/sync. A running app redraws through onSettingsChanged; an inactive app reads the value on its next launch.

A sideloaded PRG alone does not register a phone settings form. The store-installed app must include the setting definition; synchronization is not guaranteed to be instantaneous.

## Future updates

Export a new IQ and submit a new version to the same store listing, keeping the app identity/key consistent and testing archive compatibility. Users can use Connect IQ Store → My Device → Updates → Update All, or obtain available updates during normal synchronization. Users do not compile application code themselves.

## Official references

- [Submission](https://developer.garmin.com/connect-iq/submit-an-app/)
- [Properties](https://developer.garmin.com/connect-iq/core-topics/persisting-data/)
- [Settings callback](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#onSettingsChanged-instance_function)
- [Phone settings](https://support.garmin.com/en-US/?faq=TMj0wxIdjh382mBFh5rG46)
- [Updates](https://support.garmin.com/en-IN/?faq=apVl8M95hQ4WG7wzgKgeA8)
