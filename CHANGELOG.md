# Changelog

本文档记录项目的重要变更。

建议遵循 Keep a Changelog 风格，并尽量保持中文说明。

---

## [Unreleased]

### 新增
- 待补充

### 变更
- 待补充

### 修复
- 待补充

---

## [0.1.0] - 2026-04-02

### 初始发布
- 初始化 `FingerprintBrowserLauncher` 项目
- 实现基于 `config.json` 的外部配置启动
- 支持多个 profile
- 支持命令行 `--profile` 手动指定 profile
- 支持根据出口 IP 自动选择 profile
- 支持 URL 透传给真实浏览器
- 支持与 Windows 默认浏览器关联场景配合使用
- 增加 `Install.ps1`，用于生成本机路径注册表并辅助安装
- 增加 `config.example.json`，降低新人上手门槛
- 中文化 `README.md`
- 明确项目主要面向 `fingerprint-chromium`
- 增加 GitHub Actions 自动构建工作流
- 安装脚本增加占位路径检查提醒
