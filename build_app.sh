#!/bin/bash
set -euo pipefail

if [ -f "VERSION" ]; then
    # shellcheck disable=SC1091
    source "VERSION"
fi
APP_VERSION="${VERSION:-1.0.0}"
APP_BUILD="${BUILD:-1}"

APP_NAME="VoltControl"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
LAUNCHDAEMONS_DIR="${CONTENTS_DIR}/Library/LaunchDaemons"

echo "🔨 Сборка VoltControl v${APP_VERSION} (${APP_BUILD}) (arm64 Release)..."
swift build -c release --arch arm64
BUILD_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

echo "📦 Создание структуры .app бандла..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}" "${LAUNCHDAEMONS_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "${BUILD_DIR}/VoltControlHelper" "${MACOS_DIR}/VoltControlHelper"
chmod 755 "${MACOS_DIR}/${APP_NAME}" "${MACOS_DIR}/VoltControlHelper"

# Копируем Sparkle.framework (автообновления)
SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ ! -d "${SPARKLE_FRAMEWORK}" ]; then
    echo "❌ Ошибка: Sparkle.framework не найден по пути ${SPARKLE_FRAMEWORK}" >&2
    exit 1
fi
cp -R "${SPARKLE_FRAMEWORK}" "${FRAMEWORKS_DIR}/"

# Настраиваем rpath для поиска Frameworks
if ! otool -l "${MACOS_DIR}/${APP_NAME}" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}"
fi

cat << 'EOF' > "${LAUNCHDAEMONS_DIR}/com.voltcontrol.helper.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.voltcontrol.helper</string>
    <key>BundleProgram</key>
    <string>Contents/MacOS/VoltControlHelper</string>
    <key>MachServices</key>
    <dict>
        <key>com.voltcontrol.helper</key>
        <true/>
    </dict>
    <key>AssociatedBundleIdentifiers</key>
    <array>
        <string>com.voltcontrol.app</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

echo "🎨 Генерация иконки приложения (AppIcon.icns)..."
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

"${MACOS_DIR}/${APP_NAME}" --render-icon "${ICONSET_DIR}/master.png"

for sz in 16 32 128 256 512; do
    sips -z $sz $sz "${ICONSET_DIR}/master.png" --out "${ICONSET_DIR}/icon_${sz}x${sz}.png" >/dev/null
    sz2=$((sz * 2))
    sips -z $sz2 $sz2 "${ICONSET_DIR}/master.png" --out "${ICONSET_DIR}/icon_${sz}x${sz}@2x.png" >/dev/null
done
rm -f "${ICONSET_DIR}/master.png"

iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"

cat << EOF > "${CONTENTS_DIR}/Info.plist"
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
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/banzaez/volt-control/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>RFPVJFpi1khZw92PWqsHMNzPWzpG3xyggJd7ygFN2gk=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
EOF

# Select code signing identity
SIGN_ID="${SIGN_IDENTITY:-}"
if [ -z "${SIGN_ID}" ]; then
    SIGN_ID=$(security find-identity -p codesigning -v | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -n 1 || true)
fi
if [ -z "${SIGN_ID}" ]; then
    SIGN_ID=$(security find-identity -p codesigning -v | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -n 1 || true)
fi
if [ -z "${SIGN_ID}" ]; then
    SIGN_ID="-"
    echo "⚠️  Внимание: Сертификат Developer ID / Apple Development не найден. Используется ad-hoc подпись (-)."
    echo "   SMAppService.daemon и проверка TeamIdentifier в XPC могут не работать без полноценной подписи."
else
    echo "🔏 Подписание сертификатом: ${SIGN_ID}"
fi

xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

# Подписываем вложенные компоненты Sparkle изнутри наружу
SPARKLE_DEST="${FRAMEWORKS_DIR}/Sparkle.framework"
if [ -d "${SPARKLE_DEST}" ]; then
    while IFS= read -r xpc; do
        codesign --force --options runtime --sign "${SIGN_ID}" "${xpc}"
    done < <(find "${SPARKLE_DEST}" -name "*.xpc" -type d)

    if [ -e "${SPARKLE_DEST}/Versions/B/Updater.app" ]; then
        codesign --force --options runtime --sign "${SIGN_ID}" "${SPARKLE_DEST}/Versions/B/Updater.app"
    elif [ -e "${SPARKLE_DEST}/Updater.app" ]; then
        codesign --force --options runtime --sign "${SIGN_ID}" "${SPARKLE_DEST}/Updater.app"
    fi

    if [ -e "${SPARKLE_DEST}/Versions/B/Autoupdate" ]; then
        codesign --force --options runtime --sign "${SIGN_ID}" "${SPARKLE_DEST}/Versions/B/Autoupdate"
    elif [ -e "${SPARKLE_DEST}/Autoupdate" ]; then
        codesign --force --options runtime --sign "${SIGN_ID}" "${SPARKLE_DEST}/Autoupdate"
    fi

    codesign --force --options runtime --sign "${SIGN_ID}" "${SPARKLE_DEST}"
fi

codesign --force --options runtime --identifier com.voltcontrol.helper --sign "${SIGN_ID}" "${MACOS_DIR}/VoltControlHelper"
codesign --force --options runtime --sign "${SIGN_ID}" "${APP_BUNDLE}"
codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

touch "${APP_BUNDLE}"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$(pwd)/${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "✅ Приложение успешно собрано: ${APP_BUNDLE}"
