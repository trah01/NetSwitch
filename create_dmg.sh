#!/bin/bash
set -e

APP_NAME="NetSwitch"
VERSION="0.1.3"
DMG_NAME="${APP_NAME}_${VERSION}.dmg"
APP_PATH="Distribution/${APP_NAME}.app"
TEMP_DIR="temp_dmg"

echo "正在创建 DMG..."

# 清理旧的临时文件和 DMG
rm -rf "$TEMP_DIR"
rm -f "$DMG_NAME"
mkdir -p "$TEMP_DIR"

# 拷贝 APP 到临时目录
cp -R "$APP_PATH" "$TEMP_DIR/"

# 创建 Applications 软链接
ln -s /Applications "$TEMP_DIR/Applications"

# 创建 DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_NAME"

# 清理任务
rm -rf "$TEMP_DIR"

echo "DMG 创建成功: $DMG_NAME"
