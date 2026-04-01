# FingerprintBrowserLauncher

一个给 `fingerprint-chromium` / 定制 Chromium 用的 Windows 启动器。

它的目标很简单：

- 让浏览器启动参数放在外部配置里，而不是写死在快捷方式里
- 允许把它注册成默认浏览器的中转器
- 在启动前根据当前出口 IP 自动选择对应 profile
- 把 URL 继续透传给真实浏览器

这适合下面这类场景：

- 你有多个国家/地区的浏览器环境（UK / US / HK / IN ...）
- 你希望同一个启动器在不同代理出口下自动切 profile
- 你希望 Windows 的 `http/https` 链接默认走这套浏览器环境

---

## 当前特性

- 读取外部 `config.json`
- 支持多个 profile
- 支持手动指定 `--profile`
- 支持按出口 IP 自动选择 profile
- 自动把传入 URL 透传给真实浏览器
- 可注册为 Windows 默认浏览器处理器
- 失败时回退到 `defaultProfile`

---

## 工作原理

启动流程：

1. 读取 `config.json`
2. 如果手动传了 `--profile`，优先使用它
3. 否则访问 IP 信息接口（默认 `https://ipapi.co/json/`）
4. 根据 `countryProfileMap` 把国家代码映射到 profile
5. 如果检测失败，则回退到 `defaultProfile`
6. 启动真实浏览器，并附上对应 profile 的参数和传入 URL

示例：

- 当前出口 IP 属于 `GB` -> 选 `uk`
- 当前出口 IP 属于 `HK` -> 选 `hk`
- 当前出口 IP 属于 `IN` -> 选 `in`
- 检测超时/失败 -> 回退到 `defaultProfile`

---

## 目录结构

```text
FingerprintBrowserLauncher/
  FingerprintBrowserLauncher.csproj
  Program.cs
  config.json
  Register-FingerprintBrowser.reg
  Launch-FingerprintBrowser.ps1
  Launch-FingerprintBrowser.bat
  README.md
```

`dist/` 是本地发布目录，不建议提交到 git。

---

## 配置说明

`config.json` 核心字段：

```json
{
  "browserPath": "E:\\apps\\ungoogled-chromium_144.0.7559.132-1.1_windows_x64\\chrome.exe",
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
        "--user-data-dir=E:\\ungoogled-chromium-fp\\profile-uk-1001",
        "--lang=en-GB",
        "--accept-lang=en-GB,en",
        "--timezone=Europe/London"
      ]
    }
  }
}
```

### 字段说明

- `browserPath`：真实浏览器 exe 路径
- `defaultProfile`：自动识别失败时的回退 profile
- `appendUrlAtEnd`：是否把 URL 附加到参数尾部
- `autoDetectByIp`：是否启用按出口 IP 自动选 profile
- `ipInfoUrl`：IP 检测接口
- `ipLookupTimeoutSeconds`：IP 检测超时秒数
- `countryProfileMap`：国家代码 -> profile 名称
- `profiles`：profile 参数表

### profile 说明

每个 profile 目前是一组原样透传的浏览器启动参数，例如：

- `--fingerprint=1001`
- `--user-data-dir=...`
- `--lang=...`
- `--accept-lang=...`
- `--timezone=...`

建议每个国家/地区使用**独立的 user-data-dir**，避免 profile 之间相互污染。

---

## 构建

需要安装 .NET 8 SDK。

```powershell
dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true
```

发布输出默认在：

```text
bin\Release\net8.0-windows\win-x64\publish\
```

---

## 本地运行

直接运行：

```powershell
FingerprintBrowserLauncher.exe https://example.com
```

手动指定 profile：

```powershell
FingerprintBrowserLauncher.exe --profile hk https://browserscan.net/
```

如果不手动指定 profile，程序会：

- 先检查当前出口 IP
- 再自动选 profile
- 然后启动浏览器

---

## Windows 默认浏览器注册

项目包含示例注册表文件：

- `Register-FingerprintBrowser.reg`

导入后，可以在 Windows 默认应用中把这些关联给本启动器：

- `HTTP`
- `HTTPS`
- `.htm`
- `.html`

注意：

1. `.reg` 里的路径需要与你本机实际 exe 路径一致
2. `config.json` 默认按 **exe 同目录** 查找
3. 如果移动 exe，记得同时移动 `config.json`，并更新注册表路径

---

## 调试输出

当前版本会在控制台打印关键信息，例如：

```text
[Launcher] Manual profile: <none>
[Launcher] Detected IP: 50.7.250.106
[Launcher] Detected country: HK
[Launcher] Detected timezone: Asia/Hong_Kong
[Launcher] Selected profile: hk
```

如果自动识别失败，会看到超时或请求错误，然后回退到 `defaultProfile`。

---

## 已知限制

### 1. 自动识别依赖外部 IP 接口
如果 `ipapi.co` 超时或不可达，会回退到默认 profile。

### 2. DNS Leak 不是这个启动器能单独解决的
如果你使用 Clash / 代理工具，DNS 泄漏通常要在代理层配置，而不是在启动器里修。

### 3. 某些浏览器指纹残留可能来自 `user-data-dir`
如果 `Intl API`、语言或其它指纹信号出现旧值，优先检查是否复用了旧 profile 目录。

### 4. 已有浏览器实例可能导致测试结果混淆
测试新 profile 前，建议先关闭旧的同类浏览器实例。

---

## 推荐使用方式

- 给每个国家准备独立 profile 目录
- 先用 `browserscan.net` 做验证
- 再接入 Windows 默认浏览器
- 如果要长期用，建议把 exe 固定放在稳定目录，不要频繁挪位置

---

## License

暂未指定。
