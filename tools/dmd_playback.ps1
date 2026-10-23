<#
Uses the installed TI D4100_usb.dll; no Python packages or C++ compiler required.
Only -Action Upload transfers pattern data. This script never programs an FPGA.
Plan JSON: {"patterns":["p0.bin","p1.bin"],"sequence":[1,0,1],
            "repeat_count":2,"period_us":[20,100,20]}
Each pattern is exactly 98304 bytes in the existing TI/XGA packed-row format.
Paths are relative to the plan. The USB loader sends multiples of 512 bytes to
avoid the padding performed by TI LoadData for short USB packets.
#>
[CmdletBinding()]
param(
    [ValidateSet('Status','Upload','Configure','Start','Arm','Stop')]
    [string]$Action = 'Status',
    [string]$Plan,
    [ValidateRange(0,32767)][int]$Device = 0,
    [string]$DllPath
)
$ErrorActionPreference = 'Stop'
if ([IntPtr]::Size -eq 8) {
    $taskPowerShell = Join-Path $env:WINDIR 'SysWOW64/WindowsPowerShell/v1.0/powershell.exe'
    $taskArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,
                  '-Action',$Action,'-Device',"$Device")
    if ($Plan) { $taskArgs += @('-Plan',$Plan) }
    if ($DllPath) { $taskArgs += @('-DllPath',$DllPath) }
    & $taskPowerShell @taskArgs
    exit $LASTEXITCODE
}
if ($DllPath) {
    $taskDll = Get-Item -LiteralPath $DllPath
    if ($taskDll.PSIsContainer -or $taskDll.Name -ne 'D4100_usb.dll') {
        throw '-DllPath must name the installed 32-bit D4100_usb.dll'
    }
    $env:PATH = $taskDll.DirectoryName + ';' + $env:PATH
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DmdUsb {
    [DllImport("D4100_usb.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern short GetNumDev();
    [DllImport("D4100_usb.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int RegisterRead(ushort address, short device);
    [DllImport("D4100_usb.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int RegisterWrite(ushort address, ushort data, short device);
    [DllImport("D4100_usb.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int LoadData(byte[] data, int length, short dmdType, short device);
}
'@
function Read-Reg([int]$Address) {
    $value = [DmdUsb]::RegisterRead($Address,$Device)
    if ($value -lt 0) { throw ('RegisterRead 0x{0:X2}: {1}' -f $Address,$value) }
    return $value
}
function Write-Reg([int]$Address,[int]$Value) {
    $result = [DmdUsb]::RegisterWrite($Address,$Value,$Device)
    if ($result -lt 0) { throw ('RegisterWrite 0x{0:X2}: {1}' -f $Address,$result) }
}
function Wait-Status([int]$Mask,[int]$Value,[int]$TimeoutMs=10000) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        $status = Read-Reg 0x31
        if ($status -band 0x40) { throw ('FPGA error, status=0x{0:X4}' -f $status) }
        if (($status -band $Mask) -eq $Value) { return }
        Start-Sleep -Milliseconds 2
    } while ($watch.ElapsedMilliseconds -lt $TimeoutMs)
    throw ('FPGA timeout, status=0x{0:X4}' -f $status)
}
$devices = [DmdUsb]::GetNumDev()
if ($devices -le $Device) {
    if ($Action -eq 'Status') {
        [pscustomobject]@{ Devices=$devices; Connected=$false } | ConvertTo-Json
        exit 0
    }
    throw "D4100 USB device $Device is unavailable (device count: $devices)"
}
$abi = Read-Reg 0x3e
if ($Action -eq 'Status') {
    $result = [ordered]@{ Devices=$devices; Connected=$true; FPGA_ABI=('0x{0:X4}' -f $abi) }
    if ($abi -eq 0xd201) {
        $statusWord = Read-Reg 0x31
        $result.Status = '0x{0:X4}' -f $statusWord
        $result.Calibrated = [bool]($statusWord -band 1)
        $result.Loaded = [bool]($statusWord -band 4)
        $result.Running = [bool]($statusWord -band 8)
        $result.FrameBusy = [bool]($statusWord -band 0x10)
        $result.Done = [bool]($statusWord -band 0x20)
        $result.Error = [bool]($statusWord -band 0x40)
        $result.MissedTrigger = [bool]($statusWord -band 0x80)
        $result.Armed = [bool]((Read-Reg 0x2a) -band 0x10)
        $result.AcceptedTriggers = Read-Reg 0x34
        $result.UploadedPatterns = Read-Reg 0x39
        $result.CompletedLoops = Read-Reg 0x3a
        $result.CurrentPattern = Read-Reg 0x3b
    }
    [pscustomobject]$result | ConvertTo-Json
    exit 0
}
if ($abi -ne 0xd201) { throw 'The FPGA does not contain playback ABI D201. Program the verified bitstream with ISE first.' }
if ($Action -eq 'Stop') { Write-Reg 0x2a 0x20; Wait-Status 0x18 0 25000; exit 0 }
if ($Action -eq 'Start' -or $Action -eq 'Arm') {
    Wait-Status 0x1c 4
    if ($Action -eq 'Arm') { Write-Reg 0x2a 0x15 }
    else {
        $before = Read-Reg 0x34
        Write-Reg 0x2a 0x0d
        Start-Sleep -Milliseconds 2
        if ((Read-Reg 0x34) -eq $before) {
            throw ('Start was not accepted (DMD may still be initializing), status=0x{0:X4}' -f (Read-Reg 0x31))
        }
    }
    exit 0
}
if (!$Plan) { throw '-Plan is required for Upload and Configure' }
$planFile = (Resolve-Path -LiteralPath $Plan).Path
$config = Get-Content -LiteralPath $planFile -Raw -Encoding UTF8 | ConvertFrom-Json
$planDir = Split-Path -Parent $planFile
$patterns = @($config.patterns)
$sequence = @($config.sequence)
$periods = @($config.period_us)
if ($patterns.Count -lt 1 -or $patterns.Count -gt 2543) { throw 'patterns must contain 1..2543 full XGA frames' }
if ($sequence.Count -lt 1 -or $sequence.Count -gt 2543) { throw 'sequence length must be 1..2543' }
if ($periods.Count -ne 1 -and $periods.Count -ne $sequence.Count) { throw 'period_us needs one value or one per sequence entry' }
if ($null -eq $config.repeat_count -or $config.repeat_count -lt 0 -or $config.repeat_count -gt 65535 -or
    [math]::Truncate($config.repeat_count) -ne $config.repeat_count) { throw 'repeat_count must be 0..65535 (0 = unlimited)' }
$paths = @()
foreach ($pattern in $patterns) {
    $path = [IO.Path]::GetFullPath((Join-Path $planDir $pattern))
    if ((Get-Item -LiteralPath $path).Length -ne 98304) { throw "Expected 98304 bytes: $path" }
    $paths += $path
}
$ticks = @()
for ($i=0; $i -lt $sequence.Count; $i++) {
    if ($sequence[$i] -lt 0 -or $sequence[$i] -ge $patterns.Count -or
        [math]::Truncate($sequence[$i]) -ne $sequence[$i]) { throw "Invalid sequence ID at entry $i" }
    $period = $periods[0]
    if ($periods.Count -gt 1) { $period = $periods[$i] }
    if ($period -lt 20 -or $period -gt 21474836.475) { throw 'period_us must be 20..21474836.475; 20 requests fastest safe playback' }
    $ticks += [uint32][math]::Ceiling([double]$period * 200.0)
}
# Validate the whole plan before changing registers.
Write-Reg 0x2a 0x20
Wait-Status 0x18 0 25000
if ((Read-Reg 0x10) -ne 1) { throw 'This playback implementation supports DLP7000 XGA only' }
Write-Reg 0x28 0  # Global update; never enable the unverified Load2 path.
Write-Reg 0x32 1
if ($Action -eq 'Upload') {
    Wait-Status 0x101 0x101  # DDR calibration complete and controller idle.
    Write-Reg 0x30 $patterns.Count
    Write-Reg 0x31 2
    Wait-Status 2 2
    $chunk = New-Object byte[] 6144
    foreach ($path in $paths) {
        $bytes = [IO.File]::ReadAllBytes($path)
        for ($offset=0; $offset -lt $bytes.Length; $offset+=6144) {
            [Array]::Copy($bytes,$offset,$chunk,0,6144)
            $rc = [DmdUsb]::LoadData($chunk,6144,1,$Device)
            if ($rc -ne 1) { throw "LoadData failed ($rc): $path, offset $offset" }
            if ((Read-Reg 0x31) -band 0x40) { throw 'FPGA reports an upload/FIFO error' }
        }
    }
    Wait-Status 6 4
    if ((Read-Reg 0x39) -ne $patterns.Count) { throw 'Uploaded frame count mismatch' }
} elseif ((Read-Reg 0x30) -ne $patterns.Count -or ((Read-Reg 0x31) -band 4) -eq 0) {
    throw 'Upload matching frames before Configure'
}
Write-Reg 0x2b $sequence.Count
Write-Reg 0x38 $config.repeat_count
Write-Reg 0x2f 1
for ($i=0; $i -lt $sequence.Count; $i++) {
    Write-Reg 0x2c $i; Write-Reg 0x2d $sequence[$i]
    Write-Reg 0x35 $i; Write-Reg 0x36 ($ticks[$i] -band 0xffff)
    Write-Reg 0x37 ($ticks[$i] -shr 16)
}
Write-Reg 0x2a 5
Write-Output 'Patterns/configuration ready. Use -Action Start or -Action Arm to begin playback.'
