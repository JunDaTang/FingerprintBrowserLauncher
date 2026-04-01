param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsFromCaller
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-Error "config.json not found: $ConfigPath"
    exit 2
}

try {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse config.json"
    exit 3
}

if (-not $Config.browserPath -or -not (Test-Path $Config.browserPath)) {
    Write-Error "browserPath is invalid: $($Config.browserPath)"
    exit 4
}

$ProfileName = $Config.defaultProfile
$PassthroughArgs = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $ArgsFromCaller.Count; $i++) {
    if ($ArgsFromCaller[$i] -ieq "--profile" -and $i + 1 -lt $ArgsFromCaller.Count) {
        $ProfileName = $ArgsFromCaller[$i + 1]
        $i++
        continue
    }

    $PassthroughArgs.Add($ArgsFromCaller[$i])
}

$Profile = $Config.profiles.$ProfileName
if (-not $Profile) {
    Write-Error "Profile not found: $ProfileName"
    exit 5
}

$FinalArgs = New-Object System.Collections.Generic.List[string]

foreach ($arg in $Profile.args) {
    $FinalArgs.Add([string]$arg)
}

if ($PassthroughArgs.Count -gt 0) {
    if ($Config.appendUrlAtEnd) {
        foreach ($arg in $PassthroughArgs) {
            $FinalArgs.Add([string]$arg)
        }
    } else {
        $Tmp = New-Object System.Collections.Generic.List[string]
        foreach ($arg in $PassthroughArgs) {
            $Tmp.Add([string]$arg)
        }
        foreach ($arg in $FinalArgs) {
            $Tmp.Add([string]$arg)
        }
        $FinalArgs = $Tmp
    }
}

Start-Process -FilePath $Config.browserPath -ArgumentList $FinalArgs
