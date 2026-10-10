param(
  [string]$Version = $env:AGNT_VERSION,
  [string]$Dir = $env:AGNT_INSTALL_DIR,
  [switch]$NoModifyPath,
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$Esc = [char]27
$Vt = (-not $env:NO_COLOR) -and ($env:WT_SESSION -or $env:ConEmuANSI -eq "ON" -or $PSVersionTable.PSVersion.Major -ge 7)
$Arrow = [char]0x203A
$Tick = [char]0x2713
$Cross = [char]0x2717

$Repo = "mozzarellabio/agnt"
$Base = if ($env:AGNT_BASE_URL) { $env:AGNT_BASE_URL } else { "https://github.com/$Repo/releases" }
$Api = if ($env:AGNT_API_URL) { $env:AGNT_API_URL } else { "https://api.github.com/repos/$Repo/releases/latest" }
if (-not $Dir) { $Dir = Join-Path $env:LOCALAPPDATA "agnt\bin" }
$Dest = Join-Path $Dir "agnt.exe"

function Paint($rgb, $text) { "$Esc[38;2;${rgb}m$text$Esc[0m" }
function Say($text, $rgb, $fallback) { if ($Vt) { Write-Host (Paint $rgb $text) } else { Write-Host $text -ForegroundColor $fallback } }
function Mark($mark, $rgb, $fallback, $msg) {
  if ($Vt) { Write-Host "  $(Paint $rgb $mark) $msg" }
  else { Write-Host "  $mark " -NoNewline -ForegroundColor $fallback; Write-Host $msg }
}
function Step($m) { Mark $Arrow "217;119;87" "DarkYellow" $m }
function Ok($m) { Mark $Tick "139;196;138" "Green" $m }
function Note($m) { Say "    $m" "124;118;108" "DarkGray" }
function Fail($m) { Mark $Cross "229;104;95" "Red" $m; exit 1 }
function Row($label, $cmd, $extra) {
  if ($Vt) { Write-Host ("  " + (Paint "124;118;108" ($label.PadRight(12))) + (Paint "240;176;137" $cmd) + $(if ($extra) { " " + (Paint "124;118;108" $extra) } else { "" })) }
  else {
    Write-Host ("  " + $label.PadRight(12)) -NoNewline -ForegroundColor DarkGray
    Write-Host $cmd -NoNewline -ForegroundColor Yellow
    if ($extra) { Write-Host " $extra" -ForegroundColor DarkGray } else { Write-Host "" }
  }
}

function Installed($path) {
  if (-not (Test-Path $path)) { return "" }
  try { return ((& $path --version) -split "\s+")[1] } catch { return "" }
}

Write-Host ""
Say "     __ _  __ _ _ __ | |_" "217;119;87" "DarkYellow"
Say "    / _`` |/ _`` | '_ \| __|" "217;119;87" "DarkYellow"
Say "   | (_| | (_| | | | | |_" "217;119;87" "DarkYellow"
Say "    \__,_|\__, |_| |_|\__|" "217;119;87" "DarkYellow"
Say "          |___/" "217;119;87" "DarkYellow"
Say "  agent orchestras in your terminal" "124;118;108" "DarkGray"
Write-Host ""

if ($Uninstall) {
  if (-not (Test-Path $Dest)) { Fail "nothing to remove at $Dest" }
  Remove-Item $Dest -Force
  Ok "removed $Dest"
  Note "keys and settings in ~/.config/agnt were left in place"
  exit 0
}

if (-not [Environment]::Is64BitOperatingSystem) { Fail "only 64-bit Windows builds are published" }
Ok "detected windows x64"

$Version = $Version -replace "^v", ""
if ($Version) {
  $Urls = @("$Base/download/$Version/agnt-windows.exe", "$Base/download/v$Version/agnt-windows.exe")
  $Target = $Version
} else {
  $Urls = @("$Base/latest/download/agnt-windows.exe")
  try { $Target = ((Invoke-RestMethod -Uri $Api -TimeoutSec 8).tag_name) -replace "^v", "" } catch { $Target = "" }
}

$Current = Installed $Dest
if ($Current -and $Target -and $Current -eq $Target) {
  Ok "agnt $Current is already installed and up to date"
  exit 0
}

if ($Current) { Step "updating $Current -> $(if ($Target) { $Target } else { 'latest' })" }
else { Step "installing agnt $(if ($Target) { $Target } else { 'latest' })" }

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Tmp = Join-Path $Dir ".agnt.$([guid]::NewGuid().ToString('N').Substring(0,8)).exe"

try {
  Step "downloading"
  $Fetched = $false
  foreach ($Url in $Urls) {
    try { Invoke-WebRequest -Uri $Url -OutFile $Tmp -UseBasicParsing; $Fetched = $true; break } catch {}
  }
  if (-not $Fetched) { Fail "download failed: check $Base" }
  $Got = Installed $Tmp
  if (-not $Got) { Fail "downloaded file does not run on this system" }
  if (Test-Path $Dest) {
    $Old = "$Dest.old"
    Remove-Item $Old -Force -ErrorAction SilentlyContinue
    Move-Item $Dest $Old -Force
  }
  Move-Item $Tmp $Dest -Force
} finally {
  Remove-Item $Tmp -Force -ErrorAction SilentlyContinue
}
Ok "installed agnt $Got to $Dest"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$OnPath = ($UserPath -split ";") -contains $Dir
if (-not $OnPath) {
  if ($NoModifyPath) {
    Note "$Dir is not on your PATH"
  } else {
    [Environment]::SetEnvironmentVariable("Path", "$Dir;$UserPath", "User")
    $env:Path = "$Dir;$env:Path"
    Ok "added $Dir to your user PATH"
    Note "open a new terminal for it to take effect everywhere"
  }
}

Write-Host ""
Row "Run it" "agnt" ""
Row "Update" "agnt update" ""
Row "Add a key" "/key anthropic <key>" "inside agnt, or skip it: free models work out of the box"
Write-Host ""
Note "Keys and settings live in ~/.config/agnt and are never touched by the installer."
Write-Host ""
