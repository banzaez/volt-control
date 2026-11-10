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

echo "🎨 Генерация иконки приложения AppIcon.icns (macOS 27 Glass)..."
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
let squircle = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)

// Base Liquid Glass Gradient
let bgGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.06, green: 0.12, blue: 0.26, alpha: 1.0),
    NSColor(calibratedRed: 0.04, green: 0.25, blue: 0.36, alpha: 1.0),
    NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.42, alpha: 1.0)
])!
bgGradient.draw(in: squircle, angle: -45)

// Ambient Cyan & Mint Glow
let glowRect = NSRect(x: 200, y: 180, width: 620, height: 620)
let glowPath = NSBezierPath(ovalIn: glowRect)
let glowGrad = NSGradient(starting: NSColor(calibratedRed: 0.1, green: 0.95, blue: 0.75, alpha: 0.42), ending: .clear)!
glowGrad.draw(in: glowPath, relativeCenterPosition: .zero)

// Inner Glass Battery Body
let battRect = NSRect(x: 230, y: 340, width: 510, height: 344)
let battPath = NSBezierPath(roundedRect: battRect, xRadius: 96, yRadius: 96)
NSColor(calibratedWhite: 1.0, alpha: 0.14).setFill()
battPath.fill()
battPath.lineWidth = 22
NSColor(calibratedWhite: 1.0, alpha: 0.72).setStroke()
battPath.stroke()

// Battery Positive Terminal
let capRect = NSRect(x: 765, y: 442, width: 42, height: 140)
let capPath = NSBezierPath(roundedRect: capRect, xRadius: 20, yRadius: 20)
NSColor(calibratedWhite: 1.0, alpha: 0.72).setFill()
capPath.fill()

// Battery Charge Fill
let fillRect = NSRect(x: 266, y: 376, width: 370, height: 272)
let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 68, yRadius: 68)
let fillGrad = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.88, blue: 0.65, alpha: 0.95),
    NSColor(calibratedRed: 0.08, green: 0.75, blue: 0.96, alpha: 0.95)
])!
fillGrad.draw(in: fillPath, angle: 0)

// Specular Rim on Squircle
squircle.lineWidth = 18
NSColor(calibratedWhite: 1.0, alpha: 0.45).setStroke()
squircle.stroke()

// Center Lightning Bolt Symbol
if let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 340, weight: .black)
    if let configured = symbol.withSymbolConfiguration(config) {
        let symSize = configured.size
        let symRect = NSRect(
            x: 512 - symSize.width / 2,
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
    <string>ВольтКонтроль</string>
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
