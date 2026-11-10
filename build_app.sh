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

echo "🎨 Генерация иконки синего кубика LEGO сбоку (AppIcon.icns)..."
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

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let s = size
let inset = s * 0.0625
let bgRect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
let cornerRadius = bgRect.width * 0.225

// 1. Squircle Background (Deep Navy-Slate with subtle blue ambient glow)
let squircle = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
let bgGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.26, alpha: 1.0),
    NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.15, alpha: 1.0)
])!
bgGradient.draw(in: squircle, angle: -90)

squircle.lineWidth = s * 0.014
NSColor(calibratedRed: 0.25, green: 0.55, blue: 1.0, alpha: 0.35).setStroke()
squircle.stroke()

// 2. Blue Lego Brick (Side Profile View)
let bodyWidth = s * 0.62
let bodyHeight = s * 0.32
let bodyX = rect.midX - bodyWidth / 2.0
let bodyY = rect.midY - bodyHeight / 2.0 - s * 0.04

// Drop shadow under brick
let shadowRect = NSRect(x: bodyX + s * 0.02, y: bodyY - s * 0.035, width: bodyWidth - s * 0.04, height: s * 0.06)
let shadowPath = NSBezierPath(ovalIn: shadowRect)
NSColor(calibratedWhite: 0.0, alpha: 0.45).setFill()
shadowPath.fill()

// Bottom Lego interlock lip (recessed base seen from the side)
let lipWidth = bodyWidth * 0.86
let lipHeight = s * 0.032
let lipRect = NSRect(
    x: rect.midX - lipWidth / 2.0,
    y: bodyY - lipHeight * 0.65,
    width: lipWidth,
    height: lipHeight
)
let lipPath = NSBezierPath(roundedRect: lipRect, xRadius: s * 0.012, yRadius: s * 0.012)
NSColor(calibratedRed: 0.02, green: 0.28, blue: 0.68, alpha: 1.0).setFill()
lipPath.fill()

// Two Lego Studs on top (side view of a 2-stud brick)
let studWidth = bodyWidth * 0.31
let studHeight = s * 0.095
let studSpacing = bodyWidth * 0.14
let leftStudX = rect.midX - studSpacing / 2.0 - studWidth
let rightStudX = rect.midX + studSpacing / 2.0
let studY = bodyY + bodyHeight - s * 0.012
let studRadius = s * 0.024

let studGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.18, green: 0.62, blue: 1.00, alpha: 1.0),
    NSColor(calibratedRed: 0.04, green: 0.45, blue: 0.92, alpha: 1.0)
])!

for studX in [leftStudX, rightStudX] {
    let studRect = NSRect(x: studX, y: studY, width: studWidth, height: studHeight)
    let studPath = NSBezierPath(roundedRect: studRect, xRadius: studRadius, yRadius: studRadius)
    studGradient.draw(in: studPath, angle: 0)

    let studHighlightRect = NSRect(
        x: studRect.minX + studWidth * 0.08,
        y: studRect.maxY - studHeight * 0.26,
        width: studWidth * 0.84,
        height: studHeight * 0.16
    )
    let studHighlight = NSBezierPath(roundedRect: studHighlightRect, xRadius: studRadius * 0.5, yRadius: studRadius * 0.5)
    NSColor(calibratedWhite: 1.0, alpha: 0.35).setFill()
    studHighlight.fill()

    studPath.lineWidth = s * 0.01
    NSColor(calibratedWhite: 1.0, alpha: 0.25).setStroke()
    studPath.stroke()
}

// Main Brick Body (Side View)
let bodyRect = NSRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight)
let bodyRadius = s * 0.038
let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: bodyRadius, yRadius: bodyRadius)

let bodyGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.14, green: 0.58, blue: 1.00, alpha: 1.0),
    NSColor(calibratedRed: 0.03, green: 0.42, blue: 0.90, alpha: 1.0),
    NSColor(calibratedRed: 0.01, green: 0.32, blue: 0.76, alpha: 1.0)
])!
bodyGradient.draw(in: bodyPath, angle: -90)

// Top bevel highlight along brick body
let topBevelRect = NSRect(
    x: bodyRect.minX + s * 0.025,
    y: bodyRect.maxY - s * 0.032,
    width: bodyRect.width - s * 0.05,
    height: s * 0.018
)
let topBevelPath = NSBezierPath(roundedRect: topBevelRect, xRadius: s * 0.009, yRadius: s * 0.009)
NSColor(calibratedWhite: 1.0, alpha: 0.38).setFill()
topBevelPath.fill()

// Bottom inner shadow line on brick body
let bottomShadeRect = NSRect(
    x: bodyRect.minX + s * 0.02,
    y: bodyRect.minY + s * 0.012,
    width: bodyRect.width - s * 0.04,
    height: s * 0.02
)
let bottomShadePath = NSBezierPath(roundedRect: bottomShadeRect, xRadius: s * 0.008, yRadius: s * 0.008)
NSColor(calibratedWhite: 0.0, alpha: 0.22).setFill()
bottomShadePath.fill()

bodyPath.lineWidth = s * 0.012
NSColor(calibratedWhite: 1.0, alpha: 0.28).setStroke()
bodyPath.stroke()

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
    <key>CFBundleIconName</key>
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
    <string>2.1.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
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
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true
codesign --force --deep --sign - "${APP_BUNDLE}"

touch "${APP_BUNDLE}"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$(pwd)/${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "✅ Приложение успешно собрано: ${APP_BUNDLE}"
