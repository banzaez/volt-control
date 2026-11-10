#!/bin/bash
set -e

APP_NAME="VoltControl"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Сборка VoltControl в Release режиме..."
swift build -c release

echo "📦 Создание структуры .app бандла..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

echo "🎨 Генерация минималистичной иконки AppIcon.icns..."
ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
mkdir -p "${ICONSET_DIR}"

swift -e '
import AppKit

let size = CGFloat(1024)
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let rect = NSRect(x: 64, y: 64, width: 896, height: 896)
let squircle = NSBezierPath(roundedRect: rect, xRadius: 205, yRadius: 205)

// Minimalist Graphite Gradient
let bgGradient = NSGradient(colors: [
    NSColor(calibratedWhite: 0.22, alpha: 1.0),
    NSColor(calibratedWhite: 0.11, alpha: 1.0)
])!
bgGradient.draw(in: squircle, angle: -90)

// Subtle Rim
squircle.lineWidth = 14
NSColor(calibratedWhite: 1.0, alpha: 0.25).setStroke()
squircle.stroke()

// Minimalist Battery Outline
let battRect = NSRect(x: 235, y: 342, width: 510, height: 340)
let battPath = NSBezierPath(roundedRect: battRect, xRadius: 92, yRadius: 92)
NSColor(calibratedWhite: 1.0, alpha: 0.08).setFill()
battPath.fill()
battPath.lineWidth = 24
NSColor(calibratedWhite: 1.0, alpha: 0.88).setStroke()
battPath.stroke()

// Positive Terminal Cap
let capRect = NSRect(x: 770, y: 448, width: 38, height: 128)
let capPath = NSBezierPath(roundedRect: capRect, xRadius: 18, yRadius: 18)
NSColor(calibratedWhite: 1.0, alpha: 0.78).setFill()
capPath.fill()

// Center Bolt Symbol
if let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 230, weight: .bold)
    if let configured = symbol.withSymbolConfiguration(config) {
        let symSize = configured.size
        let symRect = NSRect(
            x: 490 - symSize.width / 2,
            y: 512 - symSize.height / 2,
            width: symSize.width,
            height: symSize.height
        )
        configured.draw(in: symRect)
    }
}

NSGraphicsContext.restoreGraphicsState()

let pngData = rep.representation(using: .png, properties: [:])!
try! pngData.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
' "${ICONSET_DIR}/master.png"

for sz in 16 32 128 256 512; do
    sips -z $sz $sz "${ICONSET_DIR}/master.png" --out "${ICONSET_DIR}/icon_${sz}x${sz}.png" >/dev/null
    sz2=$((sz * 2))
    sips -z $sz2 $sz2 "${ICONSET_DIR}/master.png" --out "${ICONSET_DIR}/icon_${sz}x${sz}@2x.png" >/dev/null
done
rm -f "${ICONSET_DIR}/master.png"

iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ru</string>
    <key>CFBundleExecutable</key>
    <string>VoltControl</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.voltcontrol.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>VoltControl</string>
    <key>CFBundleDisplayName</key>
    <string>VoltControl</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "🔏 Подписание приложения ad-hoc подписью..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Приложение успешно собрано: ${APP_BUNDLE}"
