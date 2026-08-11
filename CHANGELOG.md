# Changelog - XeUnshackle Max

## [1.0.0](https://github.com/Klofi/XeUnshackle-Max/compare/b36046f...v1.0.0) (2026-08-12)

* Fork XeUnshackle as XeUnshackle Max, an independent project. The version restarts at 1.0.0.
* Add an "Auto-Start" feature: pressing **Start** sets up the app to automatically exit to the default app after a short delay on future launches. Configurable via a `XeUnshackleConfig.txt` file (`AutoStartDelay=` for the countdown in seconds).
* Add a show/hide toggle for the CPUKey and DVDKey on the main screen: pressing **A** masks them with `*` characters so the screen can be shared safely. The `ShowKeys=` setting in `XeUnshackleConfig.txt` picks the state the app starts in; the button toggle itself is never written back to the file.
* Add a `PlayVideo=0` setting to `XeUnshackleConfig.txt` to skip the boot animation, independently of whether Auto-Start is set up.
* Add a `VideoVolume=` setting to `XeUnshackleConfig.txt` to play the boot animation quieter, on a `0` to `100` scale that behaves like a volume slider, so `50` sounds about half as loud. It scales only this app's own audio and leaves the console's system volume untouched.
* Add support for a custom boot animation: a video named `XeUnshackleVideo.wmv` placed next to `default.xex` is played in place of the built-in one, with no rebuild needed. The built-in video is used when the file is missing, and when the file is there but can't be played an on-screen message says so.
* Add a converter script for the boot animation video: drag a file onto [`BootVideo\convert-video.bat`](BootVideo/convert-video.bat), or run [`BootVideo\convert-video.ps1`](BootVideo/convert-video.ps1) for quality, codec, bitrate and trim options. It drives the Windows Media encoder that ships with Windows to produce a file the console can play. Output matches the codecs of the built-in video by default, VC-1 Main Profile with WMA8 audio.
* Build improvements:
    * Add build instructions [`BUILD.md`](BUILD.md) and a `build.bat` script for building with 32-bit MSBuild.
    * Document replacing the built-in boot video.
    * The build now assembles a complete, ready to ship package at `Release_LTCG\COPY_TO_USB_ROOT`, laid out for copying straight to the root of the usb, instead of emitting only `default.xex`. The files that ship alongside the app — `launch.ini`, the release readme, `BadStorage.xex.dll` and `JRPC2.xex` — are versioned in the repo under `Dist`.

# Changelog - XeUnshackle

## [BETA v1.03](https://github.com/Klofi/XeUnshackle-Max/compare/a8503c5...b36046f) (2025-10-13)

* Add [Xbox 360 Bad Storage](https://github.com/EatonZ/BadStorage) support by [EatonZ](https://github.com/EatonZ) for unlocking up to 2 TB of internal storage.

## [BETA v1.02](https://github.com/Klofi/XeUnshackle-Max/compare/7c3bb49...a8503c5) (2025-03-30)

* Fix HV protected flags not being wiped, which caused an error when launching an extracted disc xex.
* Add localization support (English/Spanish), based on FreeMyXe.
* Add Brazilian Portuguese localization.

## [BETA v1.01](https://github.com/Klofi/XeUnshackle-Max/commit/7c3bb49) (2025-03-28)

* Initial release — applies the freeboot/xebuild HV & Kernel patch set after the Xbox360BadUpdate exploit, loads Dashlaunch, and shows a simple GUI with the console's CPUKey/DVDKey.
