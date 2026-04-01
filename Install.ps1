param(
    [string]$TargetDir = "",
    [switch]$ImportRegistry,
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'

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

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    if ($Interactive) {
        $suggested = Join-Path $ScriptDir 'dist'
        $entered = Read-Host "安装目录（直接回车使用默认值：$suggested）"
        if ([string]::IsNullOrWhiteSpace($entered)) {
            $TargetDir = $suggested
        }
        else {
            $TargetDir = $entered
        }
    }
    else {
        $TargetDir = Join-Path $ScriptDir 'dist'
    }
}

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

$SourceExe = Join-Path $ScriptDir 'bin\Release\net8.0-windows\win-x64\publish\FingerprintBrowserLauncher.exe'
$SourceConfig = Join-Path $ScriptDir 'config.json'
$ExampleConfig = Join-Path $ScriptDir 'config.example.json'

if (-not (Test-Path $SourceExe)) {
    throw "Compiled launcher not found: $SourceExe`n请先运行 dotnet publish。"
}

if (-not (Test-Path $SourceConfig) -and -not (Test-Path $ExampleConfig)) {
    throw "未找到 config.json 或 config.example.json。"
}

$TargetExe = Join-Path $TargetDir 'FingerprintBrowserLauncher.exe'
$TargetConfig = Join-Path $TargetDir 'config.json'
$TargetReg = Join-Path $TargetDir 'Register-FingerprintBrowser.reg'

Copy-Item $SourceExe $TargetExe -Force

if (Test-Path $SourceConfig) {
    if (-not (Test-Path $TargetConfig)) {
        Copy-Item $SourceConfig $TargetConfig -Force
        Write-Host "已复制 config.json 到 $TargetConfig"
    }
    else {
        Write-Host "目标目录里已存在 config.json，保留现有文件。"
    }
}
elseif (-not (Test-Path $TargetConfig)) {
    Copy-Item $ExampleConfig $TargetConfig -Force
    Write-Host "已复制 config.example.json 到 $TargetConfig"
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
Write-Host "已生成注册表文件：$TargetReg"
Write-Host "Launcher exe：$TargetExe"
Write-Host "Launcher config：$TargetConfig"

$NeedsAttention = $false

try {
    $Config = Get-Content $TargetConfig -Raw | ConvertFrom-Json

    if ($Config.browserPath -match 'C:\\\\path\\\\to\\\\') {
        Write-Warning "browserPath 仍然是占位路径，请先改成你本机的 fingerprint-chromium / Chromium 可执行文件路径。"
        $NeedsAttention = $true
    }

    foreach ($profileName in $Config.profiles.PSObject.Properties.Name) {
        $profile = $Config.profiles.$profileName
        foreach ($arg in $profile.args) {
            if ($arg -match '--user-data-dir=C:\\\\path\\\\to\\\\profiles\\\\') {
                Write-Warning "profile '$profileName' 的 --user-data-dir 仍然是占位路径，请按你的机器实际目录修改。"
                $NeedsAttention = $true
                break
            }
        }
    }

    if ($NeedsAttention) {
        Write-Host "建议先编辑这个文件：$TargetConfig" -ForegroundColor Yellow
        if ($Interactive -and Ask-YesNo -Message '是否现在打开 config.json 方便你立即修改？' -Default $true) {
            Start-Process notepad.exe $TargetConfig
        }
    }
}
catch {
    Write-Warning "无法解析 $TargetConfig，请手动检查配置内容。"
}

if (-not $ImportRegistry -and $Interactive) {
    $ImportRegistry = Ask-YesNo -Message '是否现在导入注册表？' -Default $true
}

if ($ImportRegistry) {
    reg import $TargetReg
    Write-Host "注册表已导入成功。"
}
else {
    Write-Host "暂未导入注册表。你之后可以手动执行："
    Write-Host "reg import `"$TargetReg`""
}

Write-Host "下一步：去 Windows 默认应用里，把 HTTP / HTTPS / .htm / .html 指向 Fingerprint Browser Launcher。"
