# How to use your own boot animation video?

XeUnshackle Max plays a short boot animation video on startup, and you can replace it with your own. No rebuild is needed, it works with a released build.

Encode your video in a format the console can play, then drop it next to `default.xex`.

## Step 1 - Encode your video

The console only plays VC-1 video in a Windows Media (`.wmv`) container. Renaming an .mp4 to .wmv does not work; the file has to be re-encoded.

### Option 1 - With the included script

Drag your video onto [`convert-video.bat`](convert-video.bat). It writes `XeUnshackleVideo.wmv` next to your video, encoded at 720p and ready for step 2.

There is nothing to install. The script drives the Windows Media encoder that ships with Windows itself, and almost anything Windows can play works as the source: .mp4, .mov, .mkv, .avi, .wmv and so on.

By default, it encodes the same codecs as the app's built-in video: VC-1 Main Profile (`WMV3`) with WMA8 audio. That is the one combination this app is known to play, because it has been shipping a file in it since the beginning.

Run [`convert-video.ps1`](convert-video.ps1) directly for the rest of the options:

```
powershell -ExecutionPolicy Bypass -File convert-video.ps1 .\your-video.mp4
```

* `-OutputPath <path>` - write the encoded file here instead of to `XeUnshackleVideo.wmv` next to the source.
* `-Quality 1080p` - encode at 1920x1080 rather than the default 1280x720.
* `-Codec WVC1` - encode VC-1 Advanced Profile with WMA9 audio, which is what the Expression Encoder presets below produce, instead of the default Main Profile with WMA8.
* `-Bitrate <bits per second>` - override the preset's video bitrate, which is 9000000 at 720p and 18000000 at 1080p. Accepts 100000 to 30000000.
* `-Start <time>` / `-Stop <time>` - trim the source, as in `-Start 00:00:02 -Stop 00:00:10`.
* `-Force` - overwrite the output file if it is already there.

Notes:
* It has to run under Windows PowerShell (`powershell.exe`). PowerShell 7 (`pwsh.exe`) doesn't expose the media APIs it uses, and the script tells you so rather than failing obscurely.
* On an N or KN edition of Windows, install the Media Feature Pack first. That is what carries the encoder.
* The video is stretched across the whole screen, so pad a source that isn't 16:9 to 16:9 yourself if you want black bars rather than a distorted picture. The script warns you when it spots one.
* If Windows can't read your source at all, convert it to .mp4 with ffmpeg and run the script on that.

### Option 2 - With Microsoft Expression Encoder 4

If you would rather use a GUI tool, you can use a legacy tool like [Microsoft Expression Encoder 4](https://en.wikipedia.org/wiki/Microsoft_Expression_Encoder). This was tested on Windows 7. On a modern system like Windows 11, it will require additional dependencies (.NET Framework 3.5, compatibility mode) not covered by this guide. Additionally, Windows Media Encoder 9 also produces playable files, but this guide doesn't cover it.

* Your source video MUST be in .avi, .mpg or .wmv. Expression Encoder will not accept .mp4 files, so use ffmpeg or online-convert to get it into one of those first.
* Import your video, then go to Edit > Apply Preset > Encoding For Devices > WMV, and pick either VC-1 Xbox 360 720p or 1080p.
* With the preset selected, press CTRL + E to encode.
* The encoded file lands in `Documents\Expression\Output`.

### Checking the encoded file

Both options give you VC-1, just not the same flavor of it. The Expression Encoder presets encode VC-1 Advanced Profile (`WVC1`), while the built-in video and the script's default are VC-1 Main Profile (`WMV3`). [MediaInfo](https://mediaarea.net/en/MediaInfo) shows the difference as `VC-1 (Microsoft)` against `VC-1 (WMV3)`.

## Step 2 - Drop it next to the .xex

1. Make sure the encoded file is named **`XeUnshackleVideo.wmv`** - the script names it that already.
2. Copy it into the `BadUpdatePayload` folder, next to `default.xex` - the same folder `XeUnshackleConfig.txt` and `ConsoleInfo.txt` live in.

The app plays your video instead of the built-in one. Delete the file to go back to the built-in video.

Notes:
* The name must match exactly, including the `.wmv` extension. Watch out for a file manager hiding extensions and leaving you with `XeUnshackleVideo.wmv.wmv`.
* Your video is streamed from the usb/hdd as it plays, so its size costs no extra memory and there is no limit to worry about. The built-in one is already in memory by then, loaded along with the rest of `default.xex` before the app starts. Either quality setting should play fine, but if your video stutters on a slow or failing usb stick, re-encode it at 720p.
* If the file can't be played - an .mp4 renamed to .wmv, for example - the app shows a "Could not play XeUnshackleVideo.wmv!" message and falls back to the built-in video. So a built-in video with no message means your file wasn't found at all, most likely a name that doesn't match.
* The video settings in `XeUnshackleConfig.txt` apply to your video too: `PlayVideo=0` skips it entirely and `VideoVolume=` sets its volume. **B** still skips it while it's playing.
* Auto-Start only begins its countdown once the video has finished, so a long video delays the exit by its own length.

> [!CAUTION]
> This replaces a video belonging to this app only, and nothing in flash is touched. It is **not** the console's bootanim, which must never be replaced. Replacing the stock bootanim with an unsigned file locks you out of using BadUpdate. If that has already happened to you, BadUpdate v1.3 added a [boot animation recovery mode](https://github.com/grimdoomer/Xbox360BadUpdate/tree/v1.3#boot-animation-recovery-mode) that restores the stock file.
