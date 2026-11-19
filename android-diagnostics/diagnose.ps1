<#
.SYNOPSIS
  Read-only performance and thermal snapshot of an Android phone over adb.

.DESCRIPTION
  Collects the evidence used to find why a phone lags (for example, camera lag
  caused by thermal throttling): device info, battery, thermal status, memory,
  idle CPU, camera cold-start times and frame stats. It changes nothing on the
  phone. Every file goes to a timestamped folder so you can compare a "before"
  run against an "after" run.

  Privacy: it does not collect the serial number, IMEI, accounts or full
  logcat. Review the output before sharing it anyway.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File diagnose.ps1
  powershell -ExecutionPolicy Bypass -File diagnose.ps1 -Label after -CameraPackage com.sec.android.app.camera -Runs 3
#>
param(
    [string]$Label = 'before',
    [string]$CameraPackage = 'com.sec.android.app.camera',
    [int]$Runs = 3,
    [string]$Adb = 'adb',
    [string]$OutRoot = (Join-Path $PSScriptRoot 'runs')
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command $Adb -ErrorAction SilentlyContinue)) {
    throw "adb not found. Install Android platform-tools (winget install Google.PlatformTools) or pass -Adb <path>."
}

$devices = & $Adb devices | Select-String "`tdevice$"
if (-not $devices) { throw 'No device in "device" state. Enable USB debugging and accept the prompt on the phone.' }
if (@($devices).Count -gt 1) { throw 'More than one device connected. Leave only one.' }

$out = Join-Path $OutRoot ("{0}_{1}" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'), $Label)
New-Item -ItemType Directory -Force $out | Out-Null
function Save($name, [scriptblock]$cmd) {
    Write-Host "  - $name"
    & $cmd 2>&1 | Out-File -Encoding utf8 (Join-Path $out "$name.txt")
}
function Sh([string]$c) { & $Adb shell $c }

Write-Host "Collecting into $out"

# Device info: only non-identifying properties.
Save 'device' {
    foreach ($p in 'ro.product.model', 'ro.product.manufacturer', 'ro.soc.model', 'ro.build.version.release',
                   'ro.build.version.sdk', 'ro.build.version.security_patch', 'ro.product.cpu.abi') {
        "{0} = {1}" -f $p, (Sh "getprop $p")
    }
}
Save 'battery'  { Sh 'dumpsys battery' }
Save 'thermal'  { Sh 'dumpsys thermalservice' }
Save 'meminfo'  { Sh 'cat /proc/meminfo' }
Save 'top_idle' { Sh 'top -b -n 1 -m 15' }
Save 'display'  { "refresh_rate_mode = " + (Sh 'settings get secure refresh_rate_mode')
                  "window_animation_scale = " + (Sh 'settings get global window_animation_scale')
                  "transition_animation_scale = " + (Sh 'settings get global transition_animation_scale')
                  "animator_duration_scale = " + (Sh 'settings get global animator_duration_scale') }
Save 'disabled_packages' { Sh 'pm list packages -d --user 0' }

# Camera cold start: force-stop, then launch and read TotalTime.
$launcher = (Sh "cmd package resolve-activity --brief $CameraPackage" | Select-Object -Last 1).Trim()
if ($launcher -notmatch '/') { Write-Warning "Could not resolve a launcher activity for $CameraPackage; skipping camera tests." }
else {
    Save 'camera_cold_start' {
        for ($i = 1; $i -le $Runs; $i++) {
            Sh "am force-stop $CameraPackage" | Out-Null
            Start-Sleep -Seconds 2
            $r = Sh "am start -W -n $launcher" | Select-String 'TotalTime|WaitTime'
            "$i;" + (($r | ForEach-Object { $_.ToString().Trim() }) -join ';')
            Start-Sleep -Seconds 3
        }
    }
    Write-Host "  Use the camera for ~60 s now (record video, zoom). Press Enter when done."
    [void][Console]::ReadLine()
    Save 'camera_gfxinfo' { Sh "dumpsys gfxinfo $CameraPackage" }
    Save 'thermal_after_camera' { Sh 'dumpsys thermalservice' }
}

# Short summary for quick before/after comparison.
$mem = Get-Content (Join-Path $out 'meminfo.txt')
$avail = ($mem | Select-String '^MemAvailable').ToString()
$swapT = ($mem | Select-String '^SwapTotal').ToString()
$swapF = ($mem | Select-String '^SwapFree').ToString()
$summary = @("Label: $Label", $avail, $swapT, $swapF)
$cs = Join-Path $out 'camera_cold_start.txt'
if (Test-Path $cs) { $summary += 'Camera cold start:'; $summary += Get-Content $cs }
$gfx = Join-Path $out 'camera_gfxinfo.txt'
if (Test-Path $gfx) { $summary += (Get-Content $gfx | Select-String 'Total frames rendered|Janky frames|90th|95th|99th' | ForEach-Object { $_.ToString().Trim() }) }
$summary | Out-File -Encoding utf8 (Join-Path $out 'SUMMARY.txt')
$summary
Write-Host "Done. Compare SUMMARY.txt between runs."
