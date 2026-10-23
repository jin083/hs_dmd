<# Compatibility entry point; the package owns the canonical USB loader. #>
[CmdletBinding()]
param(
    [ValidateSet('Status','Upload','Configure','Start','Arm','Stop')]
    [string]$Action = 'Status',
    [string]$Plan,
    [ValidateRange(0,32767)][int]$Device = 0,
    [string]$DllPath
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../dlpc410/dmd_playback.ps1') @PSBoundParameters
exit $LASTEXITCODE
