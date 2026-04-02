# FingerprintBrowserLauncher 初始化脚本
# 用于配置 NuGet 源和检查环境

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FingerprintBrowserLauncher 环境检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 检查 NuGet 源
Write-Host ""
Write-Host "检查 NuGet 源..." -ForegroundColor Yellow
$sources = dotnet nuget list source 2>&1 | Select-String "已注册的源"
if ($null -eq $sources -or $sources.Count -eq 0) {
    Write-Host "未检测到 NuGet 源，正在配置官方源..." -ForegroundColor Yellow
    dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org
    Write-Host "✓ NuGet 源已添加" -ForegroundColor Green
} else {
    Write-Host "✓ NuGet 源已配置" -ForegroundColor Green
}

# 清除缓存
Write-Host ""
Write-Host "清除 NuGet 缓存..." -ForegroundColor Yellow
dotnet nuget locals all --clear | Out-Null
Write-Host "✓ 缓存已清除" -ForegroundColor Green

# 检查 .NET SDK 版本
Write-Host ""
Write-Host "检查 .NET SDK 版本..." -ForegroundColor Yellow
$dotnetVersion = dotnet --version
Write-Host "已安装版本: $dotnetVersion" -ForegroundColor Green

if ($dotnetVersion -like "8.0*") {
    Write-Host "✓ .NET 8.0 已安装" -ForegroundColor Green
} else {
    Write-Host "⚠ 建议安装 .NET 8.0 SDK" -ForegroundColor Yellow
    Write-Host "  可运行: winget install Microsoft.DotNet.SDK.8" -ForegroundColor Gray
}

# 提示后续步骤
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "环境检查完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "后续步骤:" -ForegroundColor Yellow
Write-Host "1. 复制配置: Copy-Item .\config.example.json .\config.json" -ForegroundColor Gray
Write-Host "2. 编辑配置: config.json（修改 browserPath 和 user-data-dir）" -ForegroundColor Gray
Write-Host "3. 编译发布: dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true" -ForegroundColor Gray
Write-Host ""
