# GPT Usage Monitor for macOS

[中文](#中文说明) · [English](#english)

A lightweight native macOS menu-bar utility for checking Codex usage, daily token statistics, and new posts from `@thsottiaux` at a glance.

> Independent community project; not affiliated with OpenAI, ChatGPT, Codex, X, or CodexRadar.

## 中文说明

### 功能

- 菜单栏直接显示当前最低剩余额度，例如 `GPT 89%`。
- 每分钟刷新 Codex 实时额度，显示周期和刷新倒计时。
- 显示官方累计 Token、最近 7 个使用日的 Token 和每天占比。
- 标明每日数据结算日期，避免把官方延迟误认为程序未更新。
- 按当前周期消耗速度估算剩余可用时间。
- 提供基于 CodexRadar 的模型相对续航参考，并明确标记为估算。
- 每 3 分钟检查 X 用户 `@thsottiaux`，新帖子触发 macOS 通知。
- 菜单保留最近 3 条帖子入口，支持手动刷新和上次成功时间。

### 系统要求

- macOS 13 Ventura 或更高版本
- 已安装并登录 Codex CLI
- X 监控为可选功能，需要本机配置 [Agent Reach](https://github.com/Panniantong/Agent-Reach) 的 Twitter 凭据

应用会自动查找 Codex 桌面应用内置的命令，也兼容 `/opt/homebrew/bin/codex`、`/usr/local/bin/codex` 和 `~/.local/bin/codex`。

### 安装预编译版本

1. 打开本仓库的 **Releases**。
2. 下载 `GPT-Usage-Monitor-macOS.zip`。
3. 解压后把 `GPT Usage Monitor.app` 拖入“应用程序”。
4. 如果 macOS 阻止首次运行，请在“系统设置 → 隐私与安全性”中选择“仍要打开”。

安装包使用临时本地签名，没有 Apple Developer ID 公证。

### 从源码构建

```bash
git clone https://github.com/galaxy99881/gpt-usage-monitor.git
cd gpt-usage-monitor
chmod +x scripts/build_app.sh
./scripts/build_app.sh
open "dist/GPT Usage Monitor.app"
```

构建不依赖第三方代码库，使用 macOS 自带的 `clang`、AppKit 和 UserNotifications。

### 使用方法

启动后点击菜单栏的仪表图标和百分比，可查看当前额度、累计及每日 Token、消耗速度估算、模型续航参考和最近帖子。点击“立即刷新”可马上重新读取。用量每分钟刷新，帖子每 3 分钟检查。

### 数据与隐私

- 用量直接从本机已登录的 Codex CLI 读取。
- 应用不会把 Codex 登录信息、统计或 X 凭据上传到开发者服务器。
- X 凭据只从本机 `~/.agent-reach/config.yaml` 读取，并仅传给本机 Twitter CLI 子进程。
- 仓库不包含账号令牌、Cookie 或密码。
- 本地仅保存上次帖子编号与最近成功刷新摘要，用于通知去重和故障检查。

### 数值说明

- 菜单栏百分比是当前额度窗口的**剩余百分比**。
- 每日百分比是当天 Token 占最近 7 个使用日总量的比例，不是账户余额。
- 每日 Token 由官方按日结算，可能不会立即包含今天的数据。
- 预计用尽时间和模型续航均为参考估算，不是服务方承诺的精确余额。

### 手动启动与退出

```bash
open "/Applications/GPT Usage Monitor.app"
```

点击菜单底部“退出”即可关闭。需要开机启动时，可在“系统设置 → 通用 → 登录项”中添加应用。

### 故障排查

- 只显示 `GPT`：确认 Codex CLI 已安装并登录，再点“立即刷新”。
- 数值不变：查看“上次成功”时间；每日统计可能延迟，但实时剩余百分比应每分钟刷新。
- 没有帖子通知：允许本应用发送通知，并确认 Agent Reach 的 Twitter 配置可用。

## English

### Features

- Shows the lowest remaining Codex allowance in the menu bar, such as `GPT 89%`.
- Refreshes live limits every minute with window duration and reset countdown.
- Displays official lifetime tokens, the latest seven active usage days, and daily shares.
- Shows the latest settled daily date so aggregation delay is not mistaken for a failed refresh.
- Estimates time to exhaustion from the current window's observed pace.
- Includes clearly labelled relative model-endurance estimates based on CodexRadar.
- Checks `@thsottiaux` on X every three minutes and sends native notifications for new posts.
- Keeps links to the three latest posts, supports manual refresh, and shows the last successful update.

### Requirements

- macOS 13 Ventura or later
- Codex CLI installed and signed in
- Optional X monitoring requires [Agent Reach](https://github.com/Panniantong/Agent-Reach) with Twitter credentials configured locally

The app automatically discovers the CLI bundled with Codex Desktop and also supports `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`, and `~/.local/bin/codex`.

### Install the prebuilt app

1. Open **Releases** in this repository.
2. Download `GPT-Usage-Monitor-macOS.zip`.
3. Unzip it and drag `GPT Usage Monitor.app` into Applications.
4. If macOS blocks the first launch, open System Settings → Privacy & Security and choose **Open Anyway**.

The downloadable build is ad-hoc signed and is not notarized with an Apple Developer ID.

### Build from source

```bash
git clone https://github.com/galaxy99881/gpt-usage-monitor.git
cd gpt-usage-monitor
chmod +x scripts/build_app.sh
./scripts/build_app.sh
open "dist/GPT Usage Monitor.app"
```

There are no third-party source dependencies. The build uses the macOS-provided `clang`, AppKit, and UserNotifications.

### Usage and privacy

Click the gauge and percentage in the menu bar to see limits, token statistics, estimates, and recent posts. Usage refreshes every minute and posts every three minutes. Data comes directly from the locally authenticated Codex CLI. Credentials and usage data are not sent to a developer-operated server. X credentials stay local and are passed only to the local Twitter CLI process.

### Understanding the numbers

- The menu-bar percentage is the **remaining percentage** in the active quota window.
- A daily percentage is that day's share of the latest seven active usage days, not an account balance.
- Daily totals may not include the current day immediately.
- Exhaustion time and model endurance are estimates, not guaranteed balances.

### Troubleshooting

- Menu bar only shows `GPT`: make sure Codex CLI is installed and signed in, then refresh manually.
- Values appear stale: check the “last successful” time. Daily totals may lag, while live allowance should refresh every minute.
- No post notifications: allow notifications and verify the local Agent Reach Twitter setup.

## Development

The active Objective-C/AppKit implementation is `Sources/GPTUsageMonitor/main.m`. Run `scripts/build_app.sh` to compile, create the app bundle, write `Info.plist`, and apply an ad-hoc signature.

## License

Copyright © 2026 Zhixin Li. All rights reserved.
