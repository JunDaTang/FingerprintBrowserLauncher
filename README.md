# FingerprintBrowserLauncher

A configurable Windows launcher for `fingerprint-chromium` or custom Chromium builds.

It is designed for people who want to:

- keep browser launch arguments in an external config file
- use multiple regional browser profiles
- automatically select a profile based on current egress IP country
- register a launcher as the Windows default browser handler
- forward clicked URLs into the real browser with the right profile

---

## Who is this for?

This project is useful if you run a Chromium-based browser with custom flags such as:

- `--fingerprint=...`
- `--user-data-dir=...`
- `--lang=...`
- `--accept-lang=...`
- `--timezone=...`

Typical use cases:

- fingerprint / antidetect browser workflows
- multiple country-specific browsing environments
- using different proxy exit locations with matching browser locale/timezone
- making those environments accessible through Windows default browser links

---

## Quick start (3 minutes)

### 1. Clone the repository

```powershell
git clone https://github.com/JunDaTang/FingerprintBrowserLauncher.git
cd FingerprintBrowserLauncher
```

### 2. Install .NET 8 SDK

Download from Microsoft or use `winget`:

```powershell
winget install Microsoft.DotNet.SDK.8
```

### 3. Copy the example config

```powershell
Copy-Item .\config.example.json .\config.json
```

### 4. Edit `config.json`

At minimum, you **must** change:

- `browserPath`
- every `--user-data-dir=...` path you actually plan to use

Example:

```json
"browserPath": "C:\\Browsers\\fingerprint-chromium\\chrome.exe"
```

and:

```json
"--user-data-dir=C:\\Browsers\\profiles\\profile-uk-1001"
```

If you do not change these paths, the launcher will fail on your machine.

### 5. Build

```powershell
dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true
```

### 6. Run a test

```powershell
.\bin\Release\net8.0-windows\win-x64\publish\FingerprintBrowserLauncher.exe https://example.com
```

---

## First-time setup checklist

Before expecting this project to work, confirm all of the following:

- `.NET 8 SDK` is installed
- `config.json` exists
- `browserPath` points to a real browser executable
- the selected `--user-data-dir` path is valid for your machine
- your target browser actually supports the flags you configured

If any of these are wrong, the launcher may still start but the browser behavior will not match your expectation.

---

## How it works

Launch flow:

1. Read `config.json`
2. If `--profile <name>` was passed, use it
3. Otherwise, if `autoDetectByIp` is enabled, query the IP info API
4. Map the detected country code using `countryProfileMap`
5. If detection fails, fall back to `defaultProfile`
6. Start the real browser and forward the selected profile arguments plus the URL

Example:

- current IP country = `GB` -> select `uk`
- current IP country = `HK` -> select `hk`
- current IP country = `IN` -> select `in`
- lookup timeout / API failure -> fall back to `defaultProfile`

---

## Project structure

```text
FingerprintBrowserLauncher/
  FingerprintBrowserLauncher.csproj
  Program.cs
  config.example.json
  config.json
  Register-FingerprintBrowser.reg
  Launch-FingerprintBrowser.ps1
  Launch-FingerprintBrowser.bat
  README.md
```

`dist/`, `bin/`, and `obj/` are local build artifacts and are not intended for git.

---

## Configuration reference

Example config:

```json
{
  "browserPath": "C:\\path\\to\\fingerprint-chromium\\chrome.exe",
  "defaultProfile": "uk",
  "appendUrlAtEnd": true,
  "autoDetectByIp": true,
  "ipInfoUrl": "https://ipapi.co/json/",
  "ipLookupTimeoutSeconds": 5,
  "countryProfileMap": {
    "GB": "uk",
    "US": "us",
    "HK": "hk",
    "IN": "in"
  },
  "profiles": {
    "uk": {
      "args": [
        "--fingerprint=1001",
        "--user-data-dir=C:\\path\\to\\profiles\\profile-uk-1001",
        "--lang=en-GB",
        "--accept-lang=en-GB,en",
        "--timezone=Europe/London"
      ]
    }
  }
}
```

### Main fields

- `browserPath`: path to the real browser executable
- `defaultProfile`: fallback profile when auto detection fails
- `appendUrlAtEnd`: whether to append incoming URLs after profile args
- `autoDetectByIp`: enable profile auto-selection by egress IP country
- `ipInfoUrl`: IP lookup endpoint
- `ipLookupTimeoutSeconds`: lookup timeout in seconds
- `countryProfileMap`: map from country code to profile name
- `profiles`: actual launch argument sets

### Profile args

Each profile is just a list of raw browser arguments.

Typical examples:

- `--fingerprint=1001`
- `--user-data-dir=...`
- `--lang=...`
- `--accept-lang=...`
- `--timezone=...`

**Recommendation:** use a separate `user-data-dir` for each profile. Reusing one directory across multiple regions may leak old locale or profile state.

---

## Manual profile selection

You can bypass auto detection and force a specific profile:

```powershell
FingerprintBrowserLauncher.exe --profile hk https://browserscan.net/
```

This is useful when:

- you want deterministic testing
- IP lookup is unavailable
- you intentionally want a fixed profile regardless of exit IP

---

## Auto-detect by egress IP

When `autoDetectByIp` is enabled, the launcher queries the configured IP info API and prints debug output like this:

```text
[Launcher] Manual profile: <none>
[Launcher] Detected IP: 50.7.250.106
[Launcher] Detected country: HK
[Launcher] Detected timezone: Asia/Hong_Kong
[Launcher] Selected profile: hk
```

If the request times out or fails, the launcher falls back to `defaultProfile`.

If your network is slow or proxied, increase:

```json
"ipLookupTimeoutSeconds": 5
```

or higher.

---

## Windows default browser registration

The repository includes a sample registry file:

- `Register-FingerprintBrowser.reg`

### Important

This file contains a **machine-specific path** and is only a starting example.

Before importing it, you must update it to match your own executable location, for example:

```text
C:\\Tools\\FingerprintBrowserLauncher\\FingerprintBrowserLauncher.exe
```

### After editing the `.reg`

Import it:

```powershell
reg import .\Register-FingerprintBrowser.reg
```

Then in Windows Default Apps, assign this launcher to:

- `HTTP`
- `HTTPS`
- `.htm`
- `.html`

### Important runtime rule

`config.json` is loaded from the **same directory as the launcher exe**.

So if you move the exe, also move:

- `config.json`

And if your `.reg` points to a new location, update that path too.

---

## Testing

### Basic test

```powershell
FingerprintBrowserLauncher.exe https://example.com
```

### Browser fingerprint check

```powershell
FingerprintBrowserLauncher.exe https://browserscan.net/
```

Things worth checking on BrowserScan:

- Timezone
- Languages
- Accept-Language
- Intl API
- WebRTC
- DNS leak
- WebGL / GPU exposure

---

## Common problems

### `BrowserPath is invalid`
Your `browserPath` in `config.json` does not exist on your machine.

### `config.json not found`
The launcher expects `config.json` next to the exe.

### Auto profile selection sometimes works, sometimes falls back
Increase `ipLookupTimeoutSeconds`.

### BrowserScan shows the wrong locale even though the profile changed
Your `user-data-dir` may contain stale data from another region. Use a clean directory per profile.

### DNS leak still exists
That is usually a proxy / Clash / network-layer issue, not a launcher-only issue.

---

## New-user recommendation

If you are just trying the project for the first time, start simple:

1. Disable complexity
2. Use one fixed profile
3. Confirm the browser starts correctly
4. Then enable auto-detect by IP
5. Then test default-browser registration

A minimal beginner setup is:

```json
"autoDetectByIp": false,
"defaultProfile": "uk"
```

This is easier to debug than jumping straight into multi-country auto switching.

---

## License

MIT
