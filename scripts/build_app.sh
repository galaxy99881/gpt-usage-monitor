#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/build"
app_dir="$project_dir/dist/GPT Usage Monitor.app"
binary="$build_dir/GPTUsageMonitor"

mkdir -p "$build_dir" "$app_dir/Contents/MacOS"
clang -fobjc-arc -O2 \
  -framework Cocoa \
  -framework UserNotifications \
  "$project_dir/Sources/GPTUsageMonitor/main.m" \
  -o "$binary"
cp "$binary" "$app_dir/Contents/MacOS/GPTUsageMonitor"

plutil -create xml1 "$app_dir/Contents/Info.plist"
plutil -insert CFBundleDevelopmentRegion -string zh_CN "$app_dir/Contents/Info.plist"
plutil -insert CFBundleExecutable -string GPTUsageMonitor "$app_dir/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string com.codex.gpt-usage-monitor "$app_dir/Contents/Info.plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$app_dir/Contents/Info.plist"
plutil -insert CFBundleName -string "GPT Usage Monitor" "$app_dir/Contents/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$app_dir/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string 1.0.0 "$app_dir/Contents/Info.plist"
plutil -insert CFBundleVersion -string 1 "$app_dir/Contents/Info.plist"
plutil -insert LSMinimumSystemVersion -string 13.0 "$app_dir/Contents/Info.plist"
plutil -insert LSUIElement -bool true "$app_dir/Contents/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$app_dir/Contents/Info.plist"

codesign --force --deep --sign - "$app_dir"
echo "Built: $app_dir"
