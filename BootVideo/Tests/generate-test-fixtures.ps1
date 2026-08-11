<#
.SYNOPSIS
    Regenerates the sample videos in BootVideo\Tests\fixtures that convert-video.Tests.ps1
    runs against.

.DESCRIPTION
    The fixtures are committed, so you do not need to run this to run the tests. It exists so
    the sample files have a visible provenance and can be rebuilt or extended.

    They are cut down from Media\success.wmv, the app's own built-in video, at a small size
    and a low bitrate to keep the repository light. Each one exercises a different branch of
    convert-video.ps1:

        sample-16x9.mp4     640x360 30 fps with audio   the ordinary case
        sample-4x3.mp4      640x480 30 fps with audio   trips the "not 16:9" warning
        sample-silent.mp4   640x360 30 fps, no audio    trips the "no audio track" warning
        sample-60fps.mp4    640x360 60 fps with audio   frame rate above the 30 fps cutoff
        sample-audio.mp3    audio only                  has to be rejected outright

    Rerunning this after replacing Media\success.wmv (see BUILD.md) produces different
    fixtures, which is why they are committed rather than built during the test run.

.NOTES
    Windows PowerShell only, same as convert-video.ps1 itself.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -eq 'Core') {
    throw "This script needs Windows PowerShell (powershell.exe), not PowerShell 7."
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$source = Join-Path $repoRoot 'Media\success.wmv'
if (-not (Test-Path -LiteralPath $source)) {
    throw "Cannot find $source to cut the fixtures from."
}

$fixtureDir = Join-Path $PSScriptRoot 'fixtures'
if (-not (Test-Path -LiteralPath $fixtureDir)) {
    New-Item -ItemType Directory -Path $fixtureDir | Out-Null
}

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

$sourceFile = Wait-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($source)) ([Windows.Storage.StorageFile])
$outFolder = Wait-Operation ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($fixtureDir)) ([Windows.Storage.StorageFolder])

function New-Fixture {
    param(
        [string]$Name,
        [Windows.Media.MediaProperties.MediaEncodingProfile]$EncodingProfile,
        [double]$Seconds = 1
    )

    $dest = Wait-Operation ($outFolder.CreateFileAsync($Name, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])

    $transcoder = New-Object Windows.Media.Transcoding.MediaTranscoder
    $transcoder.TrimStopTime = [TimeSpan]::FromSeconds($Seconds)

    $prepared = Wait-Operation ($transcoder.PrepareFileTranscodeAsync($sourceFile, $dest, $EncodingProfile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
    if (-not $prepared.CanTranscode) {
        throw "Cannot build $Name : $($prepared.FailureReason)"
    }
    $task = $asTaskProgress.MakeGenericMethod([double]).Invoke($null, @($prepared.TranscodeAsync()))
    $task.Wait(-1) | Out-Null
    if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }

    $written = Get-Item -LiteralPath (Join-Path $fixtureDir $Name)
    "{0,-20} {1,8:n0} bytes" -f $written.Name, $written.Length
}

function New-VideoProfile {
    param([int]$Width, [int]$Height, [int]$Fps, [switch]$Silent)

    $videoProfile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateMp4(
        [Windows.Media.MediaProperties.VideoEncodingQuality]::HD720p)
    $videoProfile.Video.Width = $Width
    $videoProfile.Video.Height = $Height
    $videoProfile.Video.FrameRate.Numerator = $Fps
    $videoProfile.Video.FrameRate.Denominator = 1
    $videoProfile.Video.Bitrate = 600000
    if ($Silent) { $videoProfile.Audio = $null }
    $videoProfile
}

New-Fixture 'sample-16x9.mp4' (New-VideoProfile -Width 640 -Height 360 -Fps 30)
New-Fixture 'sample-4x3.mp4' (New-VideoProfile -Width 640 -Height 480 -Fps 30)
New-Fixture 'sample-silent.mp4' (New-VideoProfile -Width 640 -Height 360 -Fps 30 -Silent)
New-Fixture 'sample-60fps.mp4' (New-VideoProfile -Width 640 -Height 360 -Fps 60)
New-Fixture 'sample-audio.mp3' ([Windows.Media.MediaProperties.MediaEncodingProfile]::CreateMp3(
        [Windows.Media.MediaProperties.AudioEncodingQuality]::Low))
