# FingerprintBrowserLauncher

一个以 [`fingerprint-chromium`](https://github.com/adryfish/fingerprint-chromium) 为主要使用场景的 Windows 启动器。

它主要解决这几件事：

- 把浏览器启动参数放到外部配置，而不是写死在快捷方式里
- 支持多个国家/地区 profile
- 启动前根据当前出口 IP 自动选择对应 profile
- 把它注册成 Windows 默认浏览器中转器
- 把系统传入的 URL 继续转发给真实浏览器

---

## 项目定位

这个项目**主要面向 `fingerprint-chromium` 用户**。

也就是说，它默认假设你使用的是这类支持类似参数模型的 Chromium 变体，例如：

- `--fingerprint=...`
- `--user-data-dir=...`
- `--lang=...`
- `--accept-lang=...`
- `--timezone=...`

如果你使用的是普通 Chrome / Chromium，也不是完全不能用，但你需要自己确认：

- 你的浏览器是否支持这些参数
- 这些参数是否真的会生效
- 某些指纹相关行为是否由浏览器分支本身实现

换句话说：

**这是一个围绕 `fingerprint-chromium` 使用方式设计的启动器，不是给普通 Chrome 做的通用包装壳。**

---

## 这项目适合谁？

典型场景：

- 指纹浏览器 / 反检测浏览器工作流
- 多国家/地区浏览环境
- 代理出口国家变化时，自动匹配浏览器语言与时区
- 希望 Windows 点链接时，默认走这套浏览器环境

---

## 3 分钟快速开始

### 1）克隆仓库

```powershell
git clone https://github.com/JunDaTang/FingerprintBrowserLauncher.git
cd FingerprintBrowserLauncher
```

### 2）安装 .NET 8 SDK

可以去微软官网安装，也可以直接用：

```powershell
winget install Microsoft.DotNet.SDK.8
```

### 3）复制示例配置

```powershell
Copy-Item .\config.example.json .\config.json
```

### 4）修改 `config.json`

至少必须改这两类路径：

- `browserPath`
- 你实际会用到的每个 `--user-data-dir=...`

例如：

```json
"browserPath": "C:\\Browsers\\fingerprint-chromium\\chrome.exe"
```

以及：

```json
"--user-data-dir=C:\\Browsers\\profiles\\profile-uk-1001"
```

**如果你不改这些路径，项目在你的机器上大概率无法直接运行。**

### 5）编译

```powershell
dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true
```

### 6）先跑一个最简单的测试

```powershell
.\bin\Release\net8.0-windows\win-x64\publish\FingerprintBrowserLauncher.exe https://example.com
```

---

## 对新人更友好的安装方式

如果你已经编译好了，可以直接用安装脚本准备一个可运行目录，并自动生成适合你本机路径的注册表文件：

```powershell
.\Install.ps1
```

它会帮你：

- 创建 `dist\`
- 把编译好的 exe 复制到 `dist\`
- 把 `config.json` 复制到 `dist\`（如果目标目录里还没有）
- 自动生成本机路径版的注册表文件

如果你还想让它顺手导入注册表：

```powershell
.\Install.ps1 -ImportRegistry
```

如果你想安装到固定目录，比如：

```powershell
.\Install.ps1 -TargetDir "C:\\Tools\\FingerprintBrowserLauncher" -ImportRegistry
```

对于不想手改注册表的用户，这个方式更推荐。

---

## 第一次使用前的检查清单

在你预期这个项目能正常工作前，先确认下面几件事：

- 已安装 `.NET 8 SDK`
- `config.json` 已存在
- `browserPath` 指向真实存在的浏览器 exe
- 选中的 `--user-data-dir` 路径在你的机器上可用
- 你的目标浏览器本身支持这些参数

如果这些基础项没配对，启动器可能能启动，但结果不会符合你的预期。

---

## 工作原理

启动流程大致是：

1. 读取 `config.json`
2. 如果命令行手动传了 `--profile <name>`，优先用它
3. 否则，如果开启了 `autoDetectByIp`，就先查询当前出口 IP 信息
4. 用 `countryProfileMap` 把国家代码映射成 profile 名称
5. 如果检测失败，就回退到 `defaultProfile`
6. 启动真实浏览器，并附上对应 profile 的参数和传入 URL

例如：

- 当前出口国家是 `GB` -> 选择 `uk`
- 当前出口国家是 `HK` -> 选择 `hk`
- 当前出口国家是 `IN` -> 选择 `in`
- 查询超时 / 接口失败 -> 回退到 `defaultProfile`

---

## 项目结构

```text
FingerprintBrowserLauncher/
  FingerprintBrowserLauncher.csproj
  Program.cs
  config.example.json
  config.json
  Install.ps1
  README.md
```

其中：

- `bin/`
- `obj/`
- `dist/`

都属于本地构建或发布产物，不建议直接提交到 git。

---

## 配置说明

示例配置：

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

### 主要字段

- `browserPath`：真实浏览器 exe 路径
- `defaultProfile`：自动识别失败时使用的回退 profile
- `appendUrlAtEnd`：是否把传入 URL 追加到参数最后
- `autoDetectByIp`：是否根据出口 IP 自动选 profile
- `ipInfoUrl`：IP 信息查询接口
- `ipLookupTimeoutSeconds`：IP 查询超时时间（秒）
- `countryProfileMap`：国家代码 -> profile 名称映射
- `profiles`：实际的浏览器参数集合

### profile 里的参数是什么？

每个 profile 本质上就是一组原样传给浏览器的参数，例如：

- `--fingerprint=1001`
- `--user-data-dir=...`
- `--lang=...`
- `--accept-lang=...`
- `--timezone=...`

**建议：每个国家/地区用独立的 `user-data-dir`。**
如果多个 profile 共用一个目录，很容易残留旧的语言、地区或浏览状态。

---

## 与 `fingerprint-chromium` 的关系

这个项目本身不是浏览器内核，也不负责实现指纹伪装逻辑。

它做的是：

- 组织配置
- 选择 profile
- 启动浏览器
- 转发 URL
- 帮你接入 Windows 默认浏览器链路

而真正的指纹相关能力是否生效，仍然取决于你使用的浏览器本体。

如果你正在使用：

- <https://github.com/adryfish/fingerprint-chromium>

那么本项目就是围绕这类用法设计的辅助启动器。

---

## 手动指定 profile

如果你不想自动识别，也可以手动强制指定某个 profile：

```powershell
FingerprintBrowserLauncher.exe --profile hk https://browserscan.net/
```

适合这些场景：

- 你想做可重复测试
- 当前 IP 查询接口不稳定
- 你就是想固定某一个 profile，不想跟出口 IP 联动

---

## 按出口 IP 自动选 profile

当 `autoDetectByIp` 开启时，程序会先查询 IP 信息，然后在控制台输出类似：

```text
[Launcher] Manual profile: <none>
[Launcher] Detected IP: 50.7.250.106
[Launcher] Detected country: HK
[Launcher] Detected timezone: Asia/Hong_Kong
[Launcher] Selected profile: hk
```

如果请求超时或失败，就会自动回退到 `defaultProfile`。

如果你的网络比较慢，或者经过 Clash / 代理链路，建议适当调大：

```json
"ipLookupTimeoutSeconds": 5
```

必要时可以更高。

---

## Windows 默认浏览器注册

这个项目现在不再维护静态 `.reg` 示例文件。

推荐方式是直接使用：

- `Install.ps1`

它会根据你本机实际安装目录，自动生成注册表文件并可选导入。

例如：

```powershell
.\Install.ps1 -ImportRegistry
```

或者安装到固定目录：

```powershell
.\Install.ps1 -TargetDir "C:\\Tools\\FingerprintBrowserLauncher" -ImportRegistry
```

执行完成后，再去 Windows 默认应用里，把下面这些关联给它：

- `HTTP`
- `HTTPS`
- `.htm`
- `.html`

### 一个很重要的运行规则

程序会默认从 **exe 同目录** 读取 `config.json`。

所以如果你移动了 exe，也要把下面这个文件一起带走：

- `config.json`

如果你更换了安装目录，建议重新运行一次 `Install.ps1`，让它重新生成对应路径的注册表。

---

## 测试方法

### 最基础的测试

```powershell
FingerprintBrowserLauncher.exe https://example.com
```

### 指纹测试

```powershell
FingerprintBrowserLauncher.exe https://browserscan.net/
```

在 BrowserScan 上建议重点关注：

- Timezone
- Languages
- Accept-Language
- Intl API
- WebRTC
- DNS Leak
- WebGL / GPU 暴露

---

## 常见问题

### `BrowserPath is invalid`
说明 `config.json` 里的 `browserPath` 在你的机器上不存在。

### `config.json not found`
说明程序没有在 exe 同目录找到 `config.json`。

### 自动选 profile 有时成功，有时回退
通常是 IP 查询超时，调大 `ipLookupTimeoutSeconds`。

### BrowserScan 显示语言/地区没完全切干净
通常是 `user-data-dir` 残留了旧状态。建议每个 profile 使用独立且尽量干净的目录。

### DNS Leak 还在
这通常不是启动器本身的问题，而是 Clash / 代理 / 网络层配置问题。

### Windows 默认应用里看不到这个启动器
确认你已经导入了由 `Install.ps1` 生成的注册表，然后重新打开默认应用页面再看。

---

## 给新人的建议

如果你第一次接触这个项目，建议先别一上来就搞多国家自动切换。

更稳的顺序是：

1. 先关闭复杂功能
2. 先固定一个 profile
3. 先确认浏览器能正常启动
4. 再开启按 IP 自动选 profile
5. 最后再接入默认浏览器

一个更容易排错的最小配置是：

```json
"autoDetectByIp": false,
"defaultProfile": "uk"
```

先把单 profile 跑通，再逐步加复杂度，会舒服很多。

---

## 自动构建

仓库已配置 GitHub Actions 自动构建 Windows x64 单文件版本。

每次 push 到 `main` 或创建 PR 时，都会自动执行构建。

如果你只是想先试用项目，也可以直接去 GitHub Actions / Artifacts 查看构建产物。

---

## License

MIT
