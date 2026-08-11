# Testing the boot video converter

Automated tests for [`convert-video.ps1`](../convert-video.ps1) and [`convert-video.bat`](../convert-video.bat).

## Running them

```
powershell -ExecutionPolicy Bypass -File .\BootVideo\Tests\run-tests.ps1
```

[`run-tests.ps1`](run-tests.ps1) checks the prerequisites below, prints each test as it goes, and exits with the number of failures, so a run configuration or a CI step goes red on its own. Pass `-Filter` to run part of the suite, as in `-Filter '*Overwrite protection*'`.

`Invoke-Pester .\BootVideo\Tests -Output Detailed` does the same thing if you would rather call Pester directly.

### In Rider

The repository ships a **Boot video tests** run configuration in [`.run`](../../.run), so it turns up in the run dropdown. It needs the [PowerShell plugin](https://plugins.jetbrains.com/plugin/10249-powershell), and it runs whichever executable that plugin is set to use, so point that at `powershell.exe` rather than `pwsh.exe` in `Settings > Languages & Frameworks > PowerShell`.

The test list and results stream into the Run tool window as they happen. What you do not get is Rider's unit test tree with the green and red ticks: that runner discovers .NET test frameworks out of compiled assemblies, and the PowerShell plugin has no Pester integration to hook into it.

### Prerequisites

Needs [Pester](https://pester.dev) 5 or newer:

```
powershell -ExecutionPolicy Bypass -Command "Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck"
```

Windows ships an old Pester 3, which does not understand the syntax these tests are written in, so `-Force -SkipPublisherCheck` is needed to put a current one alongside it. The whole run takes about a minute, most of it spent encoding.

Run it under Windows PowerShell (`powershell.exe`), not PowerShell 7, for the same reason the converter itself does.

## What is covered

Each test runs the converter as a separate process, the way a user does, then checks the exit code, the printed text, and the real properties of the file that came out. The script traps its own errors and exits, so calling it in-process would swallow them.

* **Parameter validation** - bitrate range, negative and out-of-order trim points, unknown quality and codec.
* **Input handling** - missing file, a folder, a file that is not media, and an audio-only file.
* **Output paths** - the default name, positional and explicit paths, a missing folder, writing over the source.
* **Overwrite protection** - refusing without `-Force`, replacing with it, keeping the old file when a run fails, refusing up front when the target is locked or read-only, and encoding to a temporary file rather than over the target.
* **Encoding** - the default codecs match the built-in video down to the VC-1 sequence header, plus Advanced Profile, 1080p, bitrate override, frame rate handling and trimming.
* **Warnings** - the ones for a source that is not 16:9 and a source with no audio.
* **The `.bat` wrapper** - usage message, exit codes, and that it does not quietly overwrite.

## Fixtures

`fixtures` holds five short sample files, each cut to expose a different branch. They are committed rather than built during the run, so the same bytes go in every time and a Windows update cannot move both the fixture and the result together and hide a regression.

[`generate-test-fixtures.ps1`](generate-test-fixtures.ps1) rebuilds them from `Media\success.wmv`. You do not need to run it to run the tests; it is there so the samples have a visible provenance and can be extended.

Rerunning it produces files with the same content but not the same bytes, because the encoder stamps the current time into the mp4 headers, so every rebuild shows up as a diff. Only commit the result when you actually meant to change a fixture.

## Adding a test

Assert the exit code before reading the output file. Several tests here originally checked only the file, and passed while reading one left over from the previous test.

Then check the new test can fail: break the behaviour it covers on purpose, confirm it goes red, and put the code back. A test that has never failed has not been tested either.
