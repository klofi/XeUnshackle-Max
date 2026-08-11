<#
.SYNOPSIS
    Encodes a video into the Windows Media format XeUnshackle Max plays on startup.

.DESCRIPTION
    The console's XMV player only accepts VC-1 video in an ASF (.wmv) container. That covers
    both Main Profile (WMV3, the codec Microsoft shipped as Windows Media Video 9) and
    Advanced Profile (WVC1). This script produces either using the Windows Media encoder that
    ships with Windows, so no Expression Encoder, Windows Media Encoder or other download is
    needed.

    Output defaults to VC-1 Main Profile (WMV3) + WMA8 in ASF, the same codecs and audio
    settings as the app's own built-in video, which is the one file we know this player
    accepts.

    Almost anything Windows itself can play works as input (.mp4, .mov, .mkv, .avi,
    .wmv, ...). If a file is rejected, remux or convert it with ffmpeg first.

.PARAMETER InputPath
    The source video.

.PARAMETER OutputPath
    Where to write the encoded file. Defaults to XeUnshackleVideo.wmv next to the source,
    which is the name the app looks for in the BadUpdatePayload folder.

.PARAMETER Quality
    720p (default) or 1080p. Use 720p if the video stutters off a slow usb stick.

.PARAMETER Codec
    WMV3 (default) encodes VC-1 Main Profile with WMA8 audio, matching the built-in video.
    WVC1 encodes VC-1 Advanced Profile with WMA9 audio, which is what the Expression
    Encoder "VC-1 Xbox 360" presets produce. Both are VC-1; they differ by profile.

.PARAMETER Bitrate
    Video bitrate in bits per second, overriding the preset (9000000 at 720p, 18000000 at
    1080p). Accepts 100000 to 30000000; anything lower encodes to mush and anything higher
    is past what the console will read off a usb stick.

.PARAMETER Start
    Skip everything before this point in the source, e.g. -Start 00:00:03.

.PARAMETER Stop
    Cut the video off at this point in the source, e.g. -Stop 00:00:20.

.PARAMETER Force
    Overwrite OutputPath if it already exists.

.EXAMPLE
    .\convert-video.ps1 .\intro.mp4

    Writes XeUnshackleVideo.wmv next to intro.mp4.

.EXAMPLE
    .\convert-video.ps1 .\intro.mp4 D:\BadUpdatePayload\XeUnshackleVideo.wmv

    Encodes straight onto the usb, into the folder the app reads the video from.

.EXAMPLE
    .\convert-video.ps1 .\intro.mp4 -Quality 1080p -Start 00:00:02 -Stop 00:00:12

    Encodes at 1080p, keeping only the ten seconds that start two seconds in.

.EXAMPLE
    .\convert-video.ps1 .\intro.mp4 -Force

    Replaces an XeUnshackleVideo.wmv left over from an earlier run instead of refusing.

.NOTES
    Must run under Windows PowerShell (powershell.exe), not PowerShell 7 (pwsh.exe),
    which does not project the WinRT media APIs this uses.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$InputPath,

    [Parameter(Position = 1)]
    [string]$OutputPath,

    [ValidateSet('720p', '1080p')]
    [string]$Quality = '720p',

    [ValidateSet('WMV3', 'WVC1')]
    [string]$Codec = 'WMV3',

    [ValidateRange(100000, 30000000)]
    [int]$Bitrate,

    [TimeSpan]$Start,

    [TimeSpan]$Stop,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Everything this script throws is a message written for the reader, and most of them get here
# by dropping a file on convert-video.bat, so print it plainly rather than as a stack trace.
trap {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Verbose $_.ScriptStackTrace
    exit 1
}

if ($PSVersionTable.PSEdition -eq 'Core') {
    throw "This script needs Windows PowerShell. Run it with: powershell.exe -ExecutionPolicy Bypass -File `"$PSCommandPath`" ..."
}

# Only inspect these when they were actually passed. An unbound [TimeSpan] parameter is $null,
# and $null compares as less than everything, so an unguarded check rejects every default run.
foreach ($trim in 'Start', 'Stop') {
    if ($PSBoundParameters.ContainsKey($trim) -and $PSBoundParameters[$trim] -lt [TimeSpan]::Zero) {
        throw "-$trim is a position in the source, so it cannot be negative."
    }
}
if ($PSBoundParameters.ContainsKey('Start') -and $PSBoundParameters.ContainsKey('Stop') -and $Stop -le $Start) {
    throw "-Stop ($Stop) has to come after -Start ($Start), otherwise there is nothing to encode."
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

$InputPath = (Resolve-Path -LiteralPath $InputPath).ProviderPath
if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "Not a file: $InputPath"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Parent $InputPath) 'XeUnshackleVideo.wmv'
}
$outDir = Split-Path -Parent $OutputPath
if (-not $outDir) { $outDir = (Get-Location).ProviderPath }
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    throw "Output folder does not exist: $outDir"
}
$outDir = (Resolve-Path -LiteralPath $outDir).ProviderPath
$outName = Split-Path -Leaf $OutputPath
$OutputPath = Join-Path $outDir $outName

if ($OutputPath -eq $InputPath) {
    throw "Output would overwrite the source. Pass a different -OutputPath."
}
if (Test-Path -LiteralPath $OutputPath) {
    if (-not $Force) {
        throw "$OutputPath already exists. Delete or rename it first, or pass -Force to overwrite it."
    }
    # The file only gets replaced once the encode finishes, so check now that it can be, rather
    # than encoding for a while and failing at the very last step. Leaving the previous video
    # open in a player is easy to do, since this script tells you to go and watch it.
    try { [IO.File]::Open($OutputPath, 'Open', 'Write', 'None').Dispose() }
    catch { throw "$OutputPath cannot be written to. It is either open in another program or read-only." }
}

# ---------------------------------------------------------------------------
# WinRT plumbing - the async media APIs have to be awaited by hand from PowerShell
# ---------------------------------------------------------------------------

Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null

$asTaskOp = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

$asTaskProgress = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' })[0]

function Wait-Operation($operation, $resultType) {
    $task = $asTaskOp.MakeGenericMethod($resultType).Invoke($null, @($operation))
    $task.Wait(-1) | Out-Null
    $task.Result
}

$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Storage.CreationCollisionOption, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Transcoding.MediaTranscoder, Windows.Media, ContentType = WindowsRuntime]
$null = [Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media, ContentType = WindowsRuntime]

function Format-Profile($mediaProfile) {
    $lines = @()
    if ($mediaProfile.Video) {
        $fps = if ($mediaProfile.Video.FrameRate.Denominator) {
            $mediaProfile.Video.FrameRate.Numerator / $mediaProfile.Video.FrameRate.Denominator
        }
        else { 0 }
        $lines += "  video  {0} {1}x{2} @ {3:n2} fps, {4:n0} kbps" -f `
            $mediaProfile.Video.Subtype, $mediaProfile.Video.Width, $mediaProfile.Video.Height, $fps, ($mediaProfile.Video.Bitrate / 1000)
    }
    if ($mediaProfile.Audio) {
        $lines += "  audio  {0} {1} ch, {2:n0} Hz, {3:n0} kbps" -f `
            $mediaProfile.Audio.Subtype, $mediaProfile.Audio.ChannelCount, $mediaProfile.Audio.SampleRate, ($mediaProfile.Audio.Bitrate / 1000)
    }
    $lines
}

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

$sourceFile = Wait-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($InputPath)) ([Windows.Storage.StorageFile])

try {
    $sourceProfile = Wait-Operation ([Windows.Media.MediaProperties.MediaEncodingProfile]::CreateFromFileAsync($sourceFile)) ([Windows.Media.MediaProperties.MediaEncodingProfile])
}
catch {
    throw "Windows could not read '$InputPath' as a video. Convert it to .mp4 with ffmpeg and try again."
}

Write-Host ""
Write-Host "Source: $InputPath"
Format-Profile $sourceProfile | ForEach-Object { Write-Host $_ }

# An audio-only source would still transcode: the encoder invents a blank video track for it
# and reports success, leaving a black boot animation behind.
if (-not $sourceProfile.Video) {
    throw "'$InputPath' has no video stream, so there is nothing to encode. Pick a video file."
}

# ---------------------------------------------------------------------------
# Target profile
# ---------------------------------------------------------------------------

$targetProfile = if ($Quality -eq '1080p') {
    [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWmv([Windows.Media.MediaProperties.VideoEncodingQuality]::HD1080p)
}
else {
    [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWmv([Windows.Media.MediaProperties.VideoEncodingQuality]::HD720p)
}

# CreateWmv gives VC-1 Advanced Profile with WMA9. Fall back to the codecs the built-in
# video uses unless the caller asked for Advanced Profile: WMV3 is VC-1 Main Profile, and
# 44.1 kHz / 320 kbps WMA8 is what sits alongside it in Media\success.wmv.
if ($Codec -eq 'WMV3') {
    $targetProfile.Video.Subtype = 'WMV3'
    $targetProfile.Audio.Subtype = 'WMA8'
    $targetProfile.Audio.SampleRate = 44100
    $targetProfile.Audio.Bitrate = 320000
}

# Keep the source frame rate when the console can take it, so nothing is judder-converted
# to 30 fps. Anything above that is left at the preset's rate.
$sourceFps = if ($sourceProfile.Video.FrameRate.Denominator) {
    $sourceProfile.Video.FrameRate.Numerator / $sourceProfile.Video.FrameRate.Denominator
}
else { 0 }
if ($sourceFps -gt 0 -and $sourceFps -le 30.01) {
    $targetProfile.Video.FrameRate.Numerator = $sourceProfile.Video.FrameRate.Numerator
    $targetProfile.Video.FrameRate.Denominator = $sourceProfile.Video.FrameRate.Denominator
}

if ($PSBoundParameters.ContainsKey('Bitrate')) {
    $targetProfile.Video.Bitrate = $Bitrate
}

# Nothing to encode into an audio stream if the source has none.
if (-not $sourceProfile.Audio) {
    $targetProfile.Audio = $null
}

Write-Host ""
Write-Host "Target: $OutputPath"
Format-Profile $targetProfile | ForEach-Object { Write-Host $_ }

# The app stretches the video across the whole screen, so a source that isn't 16:9
# comes out distorted rather than letterboxed.
$sourceAspect = if ($sourceProfile.Video.Height) {
    $sourceProfile.Video.Width / $sourceProfile.Video.Height
}
else { 0 }
if ($sourceAspect -gt 0 -and [Math]::Abs($sourceAspect - (16 / 9)) -gt 0.02) {
    Write-Host ""
    Write-Host "Note: the source is not 16:9, so it will be stretched to fill the screen." -ForegroundColor Yellow
    Write-Host "      Pad it to 16:9 first if you want black bars instead." -ForegroundColor Yellow
}

if (-not $sourceProfile.Audio) {
    Write-Host ""
    Write-Host "Note: the source has no audio track, so neither will the output. The player asks" -ForegroundColor Yellow
    Write-Host "      for a default audio stream, so add a silent one if the console refuses it." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Encode
# ---------------------------------------------------------------------------

# Encode into a temporary file beside the target and only move it into place once the whole
# thing succeeded. Writing straight to the target would truncate a file the user already has
# before we know the encode works, losing it for good if anything fails partway through.
# The temp name keeps the .wmv extension so nothing downstream picks a container from it.
$tempName = "~$outName"
$tempPath = Join-Path $outDir $tempName
Write-Verbose "Encoding to $tempPath, then moving that onto $OutputPath"

$outFolder = Wait-Operation ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($outDir)) ([Windows.Storage.StorageFolder])
$destFile = Wait-Operation ($outFolder.CreateFileAsync($tempName, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])

$transcoder = New-Object Windows.Media.Transcoding.MediaTranscoder
if ($PSBoundParameters.ContainsKey('Start')) { $transcoder.TrimStartTime = $Start }
if ($PSBoundParameters.ContainsKey('Stop')) { $transcoder.TrimStopTime = $Stop }

try {
    $prepared = Wait-Operation ($transcoder.PrepareFileTranscodeAsync($sourceFile, $destFile, $targetProfile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])

    if (-not $prepared.CanTranscode) {
        $hint = switch ("$($prepared.FailureReason)") {
            'CodecNotFound' { " The Windows Media encoder is missing - on an N/KN edition of Windows, install the Media Feature Pack." }
            'InvalidProfile' { " The requested output settings were rejected. Try without -Bitrate." }
            default { "" }
        }
        throw "Cannot encode this file: $($prepared.FailureReason).$hint"
    }

    Write-Host ""
    Write-Host "Encoding" -NoNewline
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $task = $asTaskProgress.MakeGenericMethod([double]).Invoke($null, @($prepared.TranscodeAsync()))
    while (-not $task.IsCompleted) {
        Start-Sleep -Milliseconds 500
        Write-Host "." -NoNewline
    }
    Write-Host ""
    if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }
    $stopwatch.Stop()
}
catch {
    Remove-Item -LiteralPath $tempPath -ErrorAction SilentlyContinue
    throw
}

# Only now is the existing file at $OutputPath, if there was one, safe to replace. Keep the
# encode on disk if this fails so the work isn't thrown away, and say where it ended up -
# the raw error here is "Cannot create a file when that file already exists", which explains
# nothing about the lock that actually caused it.
try {
    Move-Item -LiteralPath $tempPath -Destination $OutputPath -Force
}
catch {
    throw "The video encoded fine, but $OutputPath could not be replaced. Close anything that has it open, then rename $tempName to $outName yourself, or run this again. ($($_.Exception.Message.Trim()))"
}

$size = (Get-Item -LiteralPath $OutputPath).Length
Write-Host ("Done in {0:n1}s - {1:n1} MB" -f $stopwatch.Elapsed.TotalSeconds, ($size / 1MB)) -ForegroundColor Green
Write-Host ""
Write-Host "Play it on a PC to check it, then copy it into the BadUpdatePayload folder on the usb,"
Write-Host "next to default.xex, named XeUnshackleVideo.wmv."
