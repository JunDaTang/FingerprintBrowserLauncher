param(
    [string]$TargetDir = "",
    [switch]$ImportRegistry
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $TargetDir = Join-Path $ScriptDir 'dist'
}

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

$SourceExe = Join-Path $ScriptDir 'bin\Release\net8.0-windows\win-x64\publish\FingerprintBrowserLauncher.exe'
$SourceConfig = Join-Path $ScriptDir 'config.json'
$ExampleConfig = Join-Path $ScriptDir 'config.example.json'

if (-not (Test-Path $SourceExe)) {
    throw "Compiled launcher not found: $SourceExe`nRun dotnet publish first."
}

if (-not (Test-Path $SourceConfig) -and -not (Test-Path $ExampleConfig)) {
    throw "Neither config.json nor config.example.json was found."
}

$TargetExe = Join-Path $TargetDir 'FingerprintBrowserLauncher.exe'
$TargetConfig = Join-Path $TargetDir 'config.json'
$TargetReg = Join-Path $TargetDir 'Register-FingerprintBrowser.reg'

Copy-Item $SourceExe $TargetExe -Force

if (Test-Path $SourceConfig) {
    if (-not (Test-Path $TargetConfig)) {
        Copy-Item $SourceConfig $TargetConfig -Force
        Write-Host "Copied config.json to $TargetConfig"
    }
    else {
        Write-Host "config.json already exists in target directory. Keeping existing file."
    }
}
elseif (-not (Test-Path $TargetConfig)) {
    Copy-Item $ExampleConfig $TargetConfig -Force
    Write-Host "Copied config.example.json to $TargetConfig"
}

$ExePathEscaped = ($TargetExe -replace '\\', '\\\\')

$RegContent = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Classes\FingerprintBrowserLauncherHTML]
@="Fingerprint Browser Launcher HTML"
"URL Protocol"=""

[HKEY_CURRENT_USER\Software\Classes\FingerprintBrowserLauncherHTML\DefaultIcon]
@="$ExePathEscaped,0"

[HKEY_CURRENT_USER\Software\Classes\FingerprintBrowserLauncherHTML\shell]

[HKEY_CURRENT_USER\Software\Classes\FingerprintBrowserLauncherHTML\shell\open]

[HKEY_CURRENT_USER\Software\Classes\FingerprintBrowserLauncherHTML\shell\open\command]
@="\"$ExePathEscaped\" \"%1\""

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher]
@="Fingerprint Browser Launcher"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\Capabilities]
"ApplicationName"="Fingerprint Browser Launcher"
"ApplicationDescription"="Launch fingerprint Chromium with external profile config"
"Hidden"=dword:00000000

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\Capabilities\FileAssociations]
".htm"="FingerprintBrowserLauncherHTML"
".html"="FingerprintBrowserLauncherHTML"
".shtml"="FingerprintBrowserLauncherHTML"
".xht"="FingerprintBrowserLauncherHTML"
".xhtml"="FingerprintBrowserLauncherHTML"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\Capabilities\URLAssociations]
"http"="FingerprintBrowserLauncherHTML"
"https"="FingerprintBrowserLauncherHTML"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\DefaultIcon]
@="$ExePathEscaped,0"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\shell]

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\shell\open]

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\shell\open\command]
@="\"$ExePathEscaped\""

[HKEY_CURRENT_USER\Software\RegisteredApplications]
"Fingerprint Browser Launcher"="Software\\Clients\\StartMenuInternet\\FingerprintBrowserLauncher\\Capabilities"
"@

Set-Content -Path $TargetReg -Value $RegContent -Encoding ASCII
Write-Host "Generated registry file: $TargetReg"
Write-Host "Launcher exe: $TargetExe"
Write-Host "Launcher config: $TargetConfig"

if ($ImportRegistry) {
    reg import $TargetReg
    Write-Host "Registry imported successfully."
}
else {
    Write-Host "Registry not imported. To import manually run:"
    Write-Host "reg import `"$TargetReg`""
}

Write-Host "Next step: set HTTP/HTTPS/.htm/.html to Fingerprint Browser Launcher in Windows Default Apps."
