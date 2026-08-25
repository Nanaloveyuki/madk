[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Device,

  [string]$Apk = (Join-Path $PSScriptRoot "app\build\outputs\apk\debug\app-debug.apk"),

  [string]$AdbPath,

  [switch]$Build,

  [switch]$ClearLog,

  [switch]$DumpLog,

  [int]$LogLines = 120
)

$ErrorActionPreference = "Stop"

function Resolve-AdbPath {
  if ($AdbPath) {
    if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
      throw "adb was not found at '$AdbPath'."
    }
    return (Resolve-Path -LiteralPath $AdbPath).Path
  }

  $command = Get-Command adb -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $roots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
  if ($env:LOCALAPPDATA) {
    $roots += (Join-Path $env:LOCALAPPDATA "Android\Sdk")
  }
  foreach ($root in $roots) {
    if (-not $root) {
      continue
    }
    $candidate = Join-Path $root "platform-tools\adb.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }
  throw "adb was not found. Add Android SDK platform-tools to PATH or pass -AdbPath."
}

function Invoke-Adb {
  param([string[]]$Arguments)
  & $script:ResolvedAdb @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "adb command failed with exit code ${LASTEXITCODE}: adb $($Arguments -join ' ')"
  }
}

$ResolvedAdb = Resolve-AdbPath
$SdkRoot = Split-Path -Parent (Split-Path -Parent $ResolvedAdb)
if (-not $env:ANDROID_HOME -and (Test-Path -LiteralPath (Join-Path $SdkRoot "platforms"))) {
  $env:ANDROID_HOME = $SdkRoot
}
if (-not $env:ANDROID_SDK_ROOT -and (Test-Path -LiteralPath (Join-Path $SdkRoot "platforms"))) {
  $env:ANDROID_SDK_ROOT = $SdkRoot
}

if ($Build) {
  $gradle = Get-Command gradle -ErrorAction SilentlyContinue
  if (-not $gradle) {
    throw "gradle was not found. Build the APK separately or add Gradle to PATH."
  }
  Push-Location $PSScriptRoot
  try {
    & $gradle.Source --no-daemon :app:assembleDebug
    if ($LASTEXITCODE -ne 0) {
      throw "Gradle failed with exit code ${LASTEXITCODE}."
    }
  } finally {
    Pop-Location
  }
  $Apk = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "app\build\outputs\apk\debug\app-debug.apk") -ErrorAction Stop).Path
}
$Apk = (Resolve-Path -LiteralPath $Apk -ErrorAction Stop).Path

Write-Host "Using adb: $ResolvedAdb"
Write-Host "Connecting to wireless device: $Device"
& $ResolvedAdb connect $Device
if ($LASTEXITCODE -ne 0) {
  throw "adb connect failed for '$Device'."
}

$stateOutput = & $ResolvedAdb -s $Device get-state 2>&1
$stateExit = $LASTEXITCODE
$state = ($stateOutput | Out-String).Trim()
if ($stateExit -ne 0 -or $state -ne "device") {
  throw "wireless ADB device '$Device' is not ready; get-state returned '$state'."
}

if ($ClearLog) {
  Invoke-Adb -Arguments @("-s", $Device, "logcat", "-c")
}

Write-Host "Installing fixture APK: $Apk"
Invoke-Adb -Arguments @("-s", $Device, "install", "-r", $Apk)
Invoke-Adb -Arguments @("-s", $Device, "shell", "am", "force-stop", "dev.nanaloveyuki.madk.fixture")
Invoke-Adb -Arguments @("-s", $Device, "shell", "am", "start", "-n", "dev.nanaloveyuki.madk.fixture/.MainActivity")

Start-Sleep -Seconds 1
Write-Host "Wireless ADB fixture verification complete."
Write-Host "The fixture should show 'Connection: disconnected' until a USB AOA host negotiates accessory mode."

if ($DumpLog) {
  Write-Host "Recent fixture logs:"
  & $ResolvedAdb -s $Device logcat -d -t $LogLines -v time madk-fixture:V AndroidRuntime:E "*:S"
}
