<#
    Pester tests for convert-video.ps1. Run them with:

        Invoke-Pester .\BootVideo\Tests -Output Detailed

    Needs Pester 5 or newer (Install-Module Pester -Scope CurrentUser) and Windows PowerShell,
    since the converter itself only runs there.

    Every test drives the script the way a user does, as a child powershell.exe, and asserts on
    what came out: the exit code, the printed text, and the actual properties of the encoded
    file. The script traps its own errors and exits, so an in-process call would swallow them.
#>

BeforeAll {
    $script:BootVideoDir = Split-Path -Parent $PSScriptRoot
    $script:RepoRoot = Split-Path -Parent $BootVideoDir
    $script:Converter = Join-Path $BootVideoDir 'convert-video.ps1'
    $script:Wrapper = Join-Path $BootVideoDir 'convert-video.bat'
    $script:Fixtures = Join-Path $PSScriptRoot 'fixtures'
    $script:BuiltInVideo = Join-Path $RepoRoot 'Media\success.wmv'
    $script:PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

    # Run the converter as its own process, the same way convert-video.bat does.
    function Invoke-Converter {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)

        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Converter @Arguments 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
        finally { $ErrorActionPreference = $previous }
    }

    function Invoke-Wrapper {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)

        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            # The wrapper ends in "pause", so feed it stdin that is immediately at end of file.
            $output = '' | & $Wrapper @Arguments 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
        finally { $ErrorActionPreference = $previous }
    }

    # Copy a fixture into the per-test folder, so output written next to the source does not
    # land in the fixtures folder.
    function Copy-Fixture {
        param([string]$Name, [string]$Destination)

        $target = Join-Path $Destination $Name
        Copy-Item -LiteralPath (Join-Path $Fixtures $Name) -Destination $target
        $target
    }

    Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null
    $script:AsTaskOp = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
            $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media, ContentType = WindowsRuntime]

    # What the encoded file actually turned out to be, rather than what was asked for.
    function Get-MediaInfo {
        param([string]$Path)

        function Wait-Op($operation, $resultType) {
            $task = $AsTaskOp.MakeGenericMethod($resultType).Invoke($null, @($operation))
            $task.Wait(-1) | Out-Null
            $task.Result
        }

        $file = Wait-Op ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
        $mediaProfile = Wait-Op ([Windows.Media.MediaProperties.MediaEncodingProfile]::CreateFromFileAsync($file)) ([Windows.Media.MediaProperties.MediaEncodingProfile])

        [pscustomobject]@{
            Container    = "$($mediaProfile.Container.Subtype)"
            HasVideo     = $null -ne $mediaProfile.Video
            VideoSubtype = if ($mediaProfile.Video) { "$($mediaProfile.Video.Subtype)" } else { $null }
            Width        = if ($mediaProfile.Video) { $mediaProfile.Video.Width } else { 0 }
            Height       = if ($mediaProfile.Video) { $mediaProfile.Video.Height } else { 0 }
            Fps          = if ($mediaProfile.Video -and $mediaProfile.Video.FrameRate.Denominator) {
                [Math]::Round($mediaProfile.Video.FrameRate.Numerator / $mediaProfile.Video.FrameRate.Denominator, 2)
            }
            else { 0 }
            VideoBitrate = if ($mediaProfile.Video) { $mediaProfile.Video.Bitrate } else { 0 }
            HasAudio     = $null -ne $mediaProfile.Audio
            AudioSubtype = if ($mediaProfile.Audio) { "$($mediaProfile.Audio.Subtype)" } else { $null }
            SampleRate   = if ($mediaProfile.Audio) { $mediaProfile.Audio.SampleRate } else { 0 }
            AudioBitrate = if ($mediaProfile.Audio) { $mediaProfile.Audio.Bitrate } else { 0 }
        }
    }

    # The VC-1 sequence header out of the ASF stream properties object. Two files with the same
    # bytes here are configured identically, whatever a player chooses to display.
    function Get-VideoCodecPrivateData {
        param([string]$Path)

        $headerGuid = [Guid]'75B22630-668E-11CF-A6D9-00AA0062CE6C'
        $streamPropsGuid = [Guid]'B7DC0791-A9B7-11CF-8EE6-00C00C205365'
        $videoMediaGuid = [Guid]'BC19EFC0-5B4D-11CF-A8FD-00805F5C442B'

        $stream = [IO.File]::OpenRead($Path)
        try {
            $reader = New-Object IO.BinaryReader($stream)
            if ((New-Object Guid (, $reader.ReadBytes(16))) -ne $headerGuid) { return $null }
            $reader.ReadUInt64() | Out-Null
            $count = $reader.ReadUInt32()
            $reader.ReadBytes(2) | Out-Null

            for ($i = 0; $i -lt $count; $i++) {
                $start = $stream.Position
                $guid = New-Object Guid (, $reader.ReadBytes(16))
                $size = $reader.ReadUInt64()
                if ($guid -eq $streamPropsGuid) {
                    $streamType = New-Object Guid (, $reader.ReadBytes(16))
                    $reader.ReadBytes(16) | Out-Null   # error correction type
                    $reader.ReadUInt64() | Out-Null    # time offset
                    $reader.ReadUInt32() | Out-Null    # type-specific data length
                    $reader.ReadUInt32() | Out-Null    # error correction data length
                    $reader.ReadUInt16() | Out-Null    # flags
                    $reader.ReadUInt32() | Out-Null    # reserved
                    if ($streamType -eq $videoMediaGuid) {
                        $reader.ReadUInt32() | Out-Null    # encoded width
                        $reader.ReadUInt32() | Out-Null    # encoded height
                        $reader.ReadByte() | Out-Null      # reserved flags
                        $reader.ReadUInt16() | Out-Null    # format data size
                        $biSize = $reader.ReadUInt32()
                        $reader.ReadBytes(36) | Out-Null   # rest of BITMAPINFOHEADER
                        $privateLength = $biSize - 40
                        if ($privateLength -le 0) { return '' }
                        return (($reader.ReadBytes($privateLength) | ForEach-Object { $_.ToString('X2') }) -join ' ')
                    }
                }
                $stream.Position = $start + $size
            }
            return $null
        }
        finally { $stream.Dispose() }
    }
}

Describe 'convert-video.ps1' {

    # TestDrive lives for the whole file, not per test, so wipe it between tests. Without this
    # a leftover out.wmv makes the next run refuse and the test then reads the previous test's
    # file, which passes for entirely the wrong reason.
    BeforeEach {
        Get-ChildItem -LiteralPath $TestDrive -Force | Remove-Item -Recurse -Force
    }

    Context 'Parameter validation' {

        It 'rejects a bitrate below the supported range' {
            $result = Invoke-Converter (Join-Path $Fixtures 'sample-16x9.mp4') '-OutputPath' "$TestDrive\out.wmv" '-Bitrate' '1'
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'Bitrate'
        }

        It 'rejects a bitrate above the supported range' {
            $result = Invoke-Converter (Join-Path $Fixtures 'sample-16x9.mp4') '-OutputPath' "$TestDrive\out.wmv" '-Bitrate' '99000000'
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'Bitrate'
        }

        It 'rejects a negative -Start' {
            # -Start:-00:00:05, not -Start -00:00:05: PowerShell reads a bare leading dash as
            # the start of the next parameter name, so the colon form is the only way in.
            $result = Invoke-Converter (Join-Path $Fixtures 'sample-16x9.mp4') '-OutputPath' "$TestDrive\out.wmv" '-Start:-00:00:05'
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'cannot be negative'
        }

        It 'rejects -Stop at or before -Start' {
            $result = Invoke-Converter (Join-Path $Fixtures 'sample-16x9.mp4') '-OutputPath' "$TestDrive\out.wmv" '-Start' '00:00:10' '-Stop' '00:00:02'
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'has to come after'
        }

        It 'rejects an unknown -Quality' {
            $result = Invoke-Converter (Join-Path $Fixtures 'sample-16x9.mp4') '-OutputPath' "$TestDrive\out.wmv" '-Quality' '4k'
            $result.ExitCode | Should -Not -Be 0
        }

        It 'rejects an unknown -Codec' {
            $result = Invoke-Converter (Join-Path $Fixtures 'sample-16x9.mp4') '-OutputPath' "$TestDrive\out.wmv" '-Codec' 'H264'
            $result.ExitCode | Should -Not -Be 0
        }

        It 'leaves no output behind when validation fails' {
            Invoke-Converter (Join-Path $Fixtures 'sample-16x9.mp4') '-OutputPath' "$TestDrive\out.wmv" '-Bitrate' '1' | Out-Null
            Test-Path "$TestDrive\out.wmv" | Should -BeFalse
        }
    }

    Context 'Input handling' {

        It 'rejects a path that does not exist' {
            $result = Invoke-Converter "$TestDrive\nothing-here.mp4"
            $result.ExitCode | Should -Not -Be 0
        }

        It 'rejects a directory' {
            $result = Invoke-Converter $TestDrive '-OutputPath' "$TestDrive\out.wmv"
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'Not a file'
        }

        It 'rejects a file Windows cannot read as media' {
            Set-Content "$TestDrive\notes.txt" -Value 'this is not a video'
            $result = Invoke-Converter "$TestDrive\notes.txt" '-OutputPath' "$TestDrive\out.wmv"
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'could not read'
        }

        It 'rejects an audio-only file instead of encoding a black video' {
            $source = Copy-Fixture 'sample-audio.mp3' $TestDrive
            $result = Invoke-Converter $source
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'no video stream'
            Test-Path "$TestDrive\XeUnshackleVideo.wmv" | Should -BeFalse
        }
    }

    Context 'Output path handling' {

        It 'defaults to XeUnshackleVideo.wmv beside the source' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            $result = Invoke-Converter $source
            $result.ExitCode | Should -Be 0
            Test-Path (Join-Path $TestDrive 'XeUnshackleVideo.wmv') | Should -BeTrue
        }

        It 'accepts an output path positionally' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            $result = Invoke-Converter $source "$TestDrive\named.wmv"
            $result.ExitCode | Should -Be 0
            Test-Path "$TestDrive\named.wmv" | Should -BeTrue
        }

        It 'refuses an output folder that does not exist' {
            $result = Invoke-Converter (Join-Path $Fixtures 'sample-16x9.mp4') '-OutputPath' "$TestDrive\nope\out.wmv"
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'Output folder does not exist'
        }

        It 'refuses to write over its own source' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            $result = Invoke-Converter $source $source
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'overwrite the source'
        }
    }

    Context 'Overwrite protection' {

        It 'refuses an existing output without -Force and leaves it untouched' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            Set-Content "$TestDrive\XeUnshackleVideo.wmv" -Value 'existing file'

            $result = Invoke-Converter $source
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'already exists'
            (Get-Content "$TestDrive\XeUnshackleVideo.wmv" -Raw).Trim() | Should -Be 'existing file'
        }

        It 'replaces an existing output when -Force is given' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            Set-Content "$TestDrive\XeUnshackleVideo.wmv" -Value 'existing file'

            $result = Invoke-Converter $source '-Force'
            $result.ExitCode | Should -Be 0
            (Get-MediaInfo "$TestDrive\XeUnshackleVideo.wmv").VideoSubtype | Should -Be 'WMV3'
        }

        It 'keeps the previous output when the encode fails' {
            $source = Copy-Fixture 'sample-audio.mp3' $TestDrive
            Set-Content "$TestDrive\XeUnshackleVideo.wmv" -Value 'precious existing video'

            $result = Invoke-Converter $source '-OutputPath' "$TestDrive\XeUnshackleVideo.wmv" '-Force'
            $result.ExitCode | Should -Not -Be 0
            (Get-Content "$TestDrive\XeUnshackleVideo.wmv" -Raw).Trim() | Should -Be 'precious existing video'
        }

        It 'fails before encoding when the output is open elsewhere' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            Invoke-Converter $source | Out-Null

            $handle = [IO.File]::Open("$TestDrive\XeUnshackleVideo.wmv", 'Open', 'Write', 'None')
            try {
                $result = Invoke-Converter $source '-Force'
                $result.ExitCode | Should -Not -Be 0
                $result.Output | Should -Match 'cannot be written to'
            }
            finally { $handle.Dispose() }
        }

        It 'fails before encoding when the output is read-only' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            Invoke-Converter $source | Out-Null
            $target = Get-Item "$TestDrive\XeUnshackleVideo.wmv"
            $originalLength = $target.Length
            $target.IsReadOnly = $true

            try {
                $result = Invoke-Converter $source '-Force'
                $result.ExitCode | Should -Not -Be 0
                $result.Output | Should -Match 'cannot be written to'
                (Get-Item "$TestDrive\XeUnshackleVideo.wmv").Length | Should -Be $originalLength
            }
            finally { (Get-Item "$TestDrive\XeUnshackleVideo.wmv").IsReadOnly = $false }
        }

        # The target must not be touched until the encode has finished. A failure partway
        # through is hard to stage, so pin the mechanism instead: the encode has to land on a
        # separate file first. Writing straight to the target would pass every other test here.
        It 'encodes to a separate temporary file rather than over the target' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            $result = Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv" '-Verbose'

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'Encoding to .*~out\.wmv'
        }

        It 'never leaves a temporary file behind' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            Invoke-Converter $source | Out-Null
            Invoke-Converter $source '-Force' | Out-Null
            Invoke-Converter (Copy-Fixture 'sample-audio.mp3' $TestDrive) '-OutputPath' "$TestDrive\other.wmv" | Out-Null

            Get-ChildItem $TestDrive -Filter '~*' | Should -BeNullOrEmpty
        }
    }

    Context 'Encoding' {

        It 'defaults to the codecs of the built-in video' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            (Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv").ExitCode | Should -Be 0

            $info = Get-MediaInfo "$TestDrive\out.wmv"
            $info.Container | Should -Be 'ASF'
            $info.VideoSubtype | Should -Be 'WMV3'
            $info.Width | Should -Be 1280
            $info.Height | Should -Be 720
            $info.AudioSubtype | Should -Be 'WMA8'
            $info.SampleRate | Should -Be 44100
            $info.AudioBitrate | Should -Be 320032
        }

        It 'produces a stream configured exactly like the built-in video' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            (Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv").ExitCode | Should -Be 0

            $ours = Get-VideoCodecPrivateData "$TestDrive\out.wmv"
            $builtIn = Get-VideoCodecPrivateData $BuiltInVideo
            $ours | Should -Not -BeNullOrEmpty
            $ours | Should -Be $builtIn
        }

        It 'encodes VC-1 Advanced Profile when asked for it' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            (Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv" '-Codec' 'WVC1').ExitCode | Should -Be 0

            $info = Get-MediaInfo "$TestDrive\out.wmv"
            $info.VideoSubtype | Should -Be 'WVC1'
            $info.AudioSubtype | Should -Be 'WMA9'
            $info.SampleRate | Should -Be 48000
        }

        It 'encodes 1080p when asked for it' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            (Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv" '-Quality' '1080p').ExitCode | Should -Be 0

            $info = Get-MediaInfo "$TestDrive\out.wmv"
            $info.Width | Should -Be 1920
            $info.Height | Should -Be 1080
        }

        It 'applies a bitrate override' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            (Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv" '-Bitrate' '4000000').ExitCode | Should -Be 0

            (Get-MediaInfo "$TestDrive\out.wmv").VideoBitrate | Should -Be 4000000
        }

        It 'keeps a source frame rate the console can take' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            (Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv").ExitCode | Should -Be 0

            (Get-MediaInfo "$TestDrive\out.wmv").Fps | Should -Be 30
        }

        It 'clamps a frame rate above 30 fps to the preset' {
            (Get-MediaInfo (Join-Path $Fixtures 'sample-60fps.mp4')).Fps | Should -Be 60
            $source = Copy-Fixture 'sample-60fps.mp4' $TestDrive
            (Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv").ExitCode | Should -Be 0

            (Get-MediaInfo "$TestDrive\out.wmv").Fps | Should -Be 30
        }

        It 'drops the audio stream for a silent source' {
            $source = Copy-Fixture 'sample-silent.mp4' $TestDrive
            $result = Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv"

            $result.ExitCode | Should -Be 0
            $info = Get-MediaInfo "$TestDrive\out.wmv"
            $info.HasVideo | Should -BeTrue
            $info.HasAudio | Should -BeFalse
        }

        It 'trims to the requested range' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            (Invoke-Converter $source '-OutputPath' "$TestDrive\whole.wmv").ExitCode | Should -Be 0
            (Invoke-Converter $source '-OutputPath' "$TestDrive\part.wmv" '-Stop' '00:00:00.400').ExitCode | Should -Be 0

            (Get-Item "$TestDrive\part.wmv").Length | Should -BeLessThan (Get-Item "$TestDrive\whole.wmv").Length
        }
    }

    Context 'Warnings' {

        It 'warns that a source which is not 16:9 will be stretched' {
            $source = Copy-Fixture 'sample-4x3.mp4' $TestDrive
            $result = Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv"
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'not 16:9'
        }

        It 'stays quiet about the aspect ratio for a 16:9 source' {
            $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
            $result = Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv"
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Not -Match 'not 16:9'
        }

        It 'warns that a silent source stays silent' {
            $source = Copy-Fixture 'sample-silent.mp4' $TestDrive
            $result = Invoke-Converter $source '-OutputPath' "$TestDrive\out.wmv"
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'no audio track'
        }
    }

    Context 'Help' {

        It 'has a synopsis' {
            (Get-Help $Converter).Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'documents every parameter' {
            $documented = (Get-Help $Converter -Full).Parameters.Parameter.Name
            foreach ($name in 'InputPath', 'OutputPath', 'Quality', 'Codec', 'Bitrate', 'Start', 'Stop', 'Force') {
                $documented | Should -Contain $name
            }
        }

        It 'has examples that are valid PowerShell' {
            $examples = (Get-Help $Converter -Full).Examples.Example
            $examples | Should -Not -BeNullOrEmpty
            foreach ($example in $examples) {
                $errors = $null
                [System.Management.Automation.PSParser]::Tokenize($example.Code, [ref]$errors) | Out-Null
                $errors | Should -BeNullOrEmpty
            }
        }
    }
}

Describe 'convert-video.bat' {

    BeforeEach {
        Get-ChildItem -LiteralPath $TestDrive -Force | Remove-Item -Recurse -Force
    }

    It 'explains itself when given no video' {
        $result = Invoke-Wrapper
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Drag a video file onto this script'
    }

    It 'encodes a dropped video and reports success' {
        $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
        $result = Invoke-Wrapper $source

        $result.ExitCode | Should -Be 0
        (Get-MediaInfo (Join-Path $TestDrive 'XeUnshackleVideo.wmv')).VideoSubtype | Should -Be 'WMV3'
    }

    It 'refuses a second drop rather than overwriting silently' {
        $source = Copy-Fixture 'sample-16x9.mp4' $TestDrive
        Invoke-Wrapper $source | Out-Null
        $before = (Get-Item (Join-Path $TestDrive 'XeUnshackleVideo.wmv')).LastWriteTimeUtc

        $result = Invoke-Wrapper $source
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'already exists'
        (Get-Item (Join-Path $TestDrive 'XeUnshackleVideo.wmv')).LastWriteTimeUtc | Should -Be $before
    }
}
