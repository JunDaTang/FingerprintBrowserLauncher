param(
    [string]$TargetDir = "",
    [switch]$ImportRegistry,
    [switch]$Interactive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Title {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Warning-Custom {
    param([string]$Text)
    Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "[ERROR] $Text" -ForegroundColor Red
}

function Ask-YesNo {
    param(
        [string]$Message,
        [bool]$Default = $true
    )
    $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
    $inputValue = Read-Host "$Message $suffix"
    if ([string]::IsNullOrWhiteSpace($inputValue)) {
        return $Default
    }
    return $inputValue.Trim().ToLowerInvariant() -in @('y', 'yes')
}

Write-Title "FingerprintBrowserLauncher Installation"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $TargetDir = Join-Path $ScriptDir 'dist'
    if ($Interactive) {
        Write-Host "Installation directory: (press Enter for default)" -ForegroundColor Yellow
        $entered = Read-Host "  Path"
        if (-not [string]::IsNullOrWhiteSpace($entered)) {
            $TargetDir = $entered
        }
    }
}

Write-Host "Using directory: $TargetDir" -ForegroundColor Gray

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    Write-Success "Created directory"
}

$SourceExe = Join-Path $ScriptDir 'bin\Release\net8.0-windows\win-x64\publish\FingerprintBrowserLauncher.exe'
if (-not (Test-Path $SourceExe)) {
    Write-Error-Custom "Compiled launcher not found: $SourceExe"
    Write-Host "Run: dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true" -ForegroundColor Yellow
    exit 1
}
Write-Success "Found compiled executable"

$SourceConfig = Join-Path $ScriptDir 'config.json'
$ExampleConfig = Join-Path $ScriptDir 'config.example.json'
$TargetExe = Join-Path $TargetDir 'FingerprintBrowserLauncher.exe'
$TargetConfig = Join-Path $TargetDir 'config.json'

if (-not (Test-Path $SourceConfig) -and -not (Test-Path $ExampleConfig)) {
    Write-Error-Custom "config.json or config.example.json not found"
    exit 1
}

Copy-Item $SourceExe $TargetExe -Force
Write-Success "Copied executable"

if (Test-Path $SourceConfig) {
    if (-not (Test-Path $TargetConfig)) {
        Copy-Item $SourceConfig $TargetConfig -Force
        Write-Success "Copied config.json"
    }
    else {
        Write-Warning-Custom "config.json already exists, keeping it"
    }
}
else {
    Copy-Item $ExampleConfig $TargetConfig -Force
    Write-Success "Copied config.example.json"
}

Write-Host ""
Write-Host "Checking configuration..." -ForegroundColor Gray

$ConfigIssues = $false
try {
    $Config = Get-Content $TargetConfig -Raw | ConvertFrom-Json

    if ($Config.browserPath -like '*C:\path\to*' -or $Config.browserPath -like '*placeholder*') {
        Write-Warning-Custom "browserPath is still a placeholder"
        $ConfigIssues = $true
    }

    foreach ($profileName in $Config.profiles.PSObject.Properties.Name) {
        $profile = $Config.profiles.$profileName
        foreach ($arg in $profile.args) {
            if ($arg -like '*--user-data-dir=*C:\path\to*') {
                Write-Warning-Custom "Profile '$profileName' has placeholder user-data-dir"
                $ConfigIssues = $true
                break
            }
        }
    }

    if (-not $ConfigIssues) {
        Write-Success "Configuration looks good"
    }
}
catch {
    Write-Warning-Custom "Could not parse config.json - check manually"
}

if ($ConfigIssues -and $Interactive) {
    if (Ask-YesNo -Message "Open config.json?" -Default $true) {
        Start-Process notepad.exe $TargetConfig
    }
}

Write-Host ""
Write-Host "Generating registry file..." -ForegroundColor Gray

$ExePathEscaped = ($TargetExe -replace '\\', '\\\\')
$TargetReg = Join-Path $TargetDir 'Register-Browser.reg'

$RegContent = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Classes\FingerprintBrowserLauncherHTML]
@="Fingerprint Browser Launcher HTML"
"URL Protocol"=""

[HKEY_CURRENT_USER\Software\Classes\FingerprintBrowserLauncherHTML\DefaultIcon]
@="$ExePathEscaped,0"

[HKEY_CURRENT_USER\Software\Classes\FingerprintBrowserLauncherHTML\shell\open\command]
@=`"\"$ExePathEscaped\" \"%1\"`"

[HKEY_CURRENT_USER\Software\Classes\http\shell\open\command]
@=`"\"$ExePathEscaped\" \"%1\"`"

[HKEY_CURRENT_USER\Software\Classes\https\shell\open\command]
@=`"\"$ExePathEscaped\" \"%1\"`"

[HKEY_CURRENT_USER\Software\Classes\htm\shell\open\command]
@=`"\"$ExePathEscaped\" \"%1\"`"

[HKEY_CURRENT_USER\Software\Classes\html\shell\open\command]
@=`"\"$ExePathEscaped\" \"%1\"`"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher]
@="Fingerprint Browser Launcher"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\Capabilities]
"ApplicationName"="Fingerprint Browser Launcher"
"ApplicationDescription"="Launch Chromium with multi-region profiles"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\Capabilities\URLAssociations]
"http"="FingerprintBrowserLauncherHTML"
"https"="FingerprintBrowserLauncherHTML"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\DefaultIcon]
@="$ExePathEscaped,0"

[HKEY_CURRENT_USER\Software\Clients\StartMenuInternet\FingerprintBrowserLauncher\shell\open\command]
@=`"\"$ExePathEscaped\"`"
"@

Set-Content -Path $TargetReg -Value $RegContent -Encoding ASCII
Write-Success "Generated registry file"

Write-Host ""
if (-not $ImportRegistry -and $Interactive) {
    $ImportRegistry = Ask-YesNo -Message "Import registry now?" -Default $true
}

if ($ImportRegistry) {
    try {
        reg import $TargetReg *>$null
        Write-Success "Registry imported"
    }
    catch {
        Write-Warning-Custom "Registry import may have failed"
        Write-Host "  Try manually: reg import `"$TargetReg`"" -ForegroundColor Yellow
    }
}
else {
    Write-Host "Registry file ready: $TargetReg" -ForegroundColor Gray
    Write-Host "Import later with: reg import `"$TargetReg`"" -ForegroundColor Gray
}

Write-Title "Installation Complete"
Write-Host "Executable: $TargetExe" -ForegroundColor Gray
Write-Host "Config file: $TargetConfig" -ForegroundColor Gray
Write-Host "Registry file: $TargetReg" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Open Windows Settings (Win+I)" -ForegroundColor White
Write-Host "2. Go to Apps > Default apps" -ForegroundColor White
Write-Host "3. Find 'Fingerprint Browser Launcher'" -ForegroundColor White
Write-Host "4. Set as default for HTTP and HTTPS" -ForegroundColor White
Write-Host ""
Write-Host "Test with: .\dist\FingerprintBrowserLauncher.exe https://browserscan.net/" -ForegroundColor Yellow
