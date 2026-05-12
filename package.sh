#!/bin/bash
set -e

# 设置变量
APP_NAME="NetSwitch"
BUNDLE_ID="com.netswitch.app"
VERSION="1.0.2"
DIST_DIR="Distribution"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "开始打包 $APP_NAME..."

# 1. 清理环境
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 2. 编译 Release 通用二进制 (Apple Silicon + Intel)
echo "正在编译通用二进制文件..."
swift build -c release --arch arm64 --arch x86_64

if [ $? -ne 0 ]; then
    echo "编译失败！"
    exit 1
fi

# 3. 拷贝二进制文件
cp .build/apple/Products/Release/$APP_NAME "$APP_BUNDLE/Contents/MacOS/"

# 4. 拷贝并设置图标
if [ -f "net.icns" ]; then
    cp net.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "警告：未找到 net.icns"
fi

# 5. 生成 Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 6. 清理扩展属性，避免签名时写入 Finder metadata/resource fork
echo "清理扩展属性..."
xattr -cr "$APP_BUNDLE"

# 7. 代码签名 (Ad-hoc)
echo "正在进行代码签名..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "======================================"
echo "打包成功！"
echo "应用位置: $APP_BUNDLE"
echo "你可以将其拖入 /Applications/ 文件夹使用。"
echo "======================================"
