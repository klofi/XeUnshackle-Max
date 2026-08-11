<#
.SYNOPSIS
    Runs the boot video converter tests.

.DESCRIPTION
    A thin wrapper around Invoke-Pester so the suite has one entry point that checks its own
    prerequisites and returns a real exit code. Rider's run configuration points at this, and
    it is just as usable from a terminal.

.PARAMETER Filter
    Only run tests whose full name matches this wildcard, for example
    -Filter '*Encoding*' or -Filter '*refuses*'.

.EXAMPLE
    .\BootVideo\Tests\run-tests.ps1

.EXAMPLE
    .\BootVideo\Tests\run-tests.ps1 -Filter '*Overwrite protection*'

.NOTES
    Windows PowerShell only. The tests read media properties through WinRT, which PowerShell 7
    does not project.
#>
[CmdletBinding()]
param(
    [string]$Filter
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host "ERROR: these tests need Windows PowerShell (powershell.exe), not PowerShell 7." -ForegroundColor Red
    exit 1
}

$pester = Get-Module -ListAvailable Pester |
    Where-Object { $_.Version.Major -ge 5 } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pester) {
    Write-Host "ERROR: Pester 5 or newer is not installed." -ForegroundColor Red
    Write-Host "Install it with:" -ForegroundColor Red
    Write-Host "    Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck" -ForegroundColor Red
    Write-Host "Windows ships Pester 3, which does not understand the syntax these tests use." -ForegroundColor Red
    exit 1
}

Import-Module $pester -Force

$configuration = New-PesterConfiguration
$configuration.Run.Path = $PSScriptRoot
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
if ($Filter) { $configuration.Filter.FullName = $Filter }

$result = Invoke-Pester -Configuration $configuration

# Hand the failure count back so a run configuration or a CI step goes red on its own.
exit $result.FailedCount
