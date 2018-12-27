#!/bin/bash

set -e

CODESIGN="${1}"
if [ -z "${CODESIGN}" ]; then
	echo "Code signing identity is required."
	exit 1
fi

DERIVED_DATA_PATH="$(pwd)/DerivedData"
SCHEME="Release + CodeSign"
CONFIG="Release+CodeSign"

rm -rf "vendor" "${DERIVED_DATA_PATH}"

xcodebuild \
	-scheme "${SCHEME}" \
	-derivedDataPath "${DERIVED_DATA_PATH}" \
	"CODE_SIGN_IDENTITY=${CODESIGN}" \
	"OTHER_CODE_SIGN_FLAGS=--timestamp --options runtime" \
	"CODE_SIGN_ENTITLEMENTS=app/Notarization.entitlements"

APPNAME="Hex Fiend"
APP="${DERIVED_DATA_PATH}/Build/Products/${CONFIG}/${APPNAME}.app"
SPARKLE="${APP}/Contents/Frameworks/Sparkle.framework"
AUTOUPDATEAPP="${SPARKLE}/Versions/A/Resources/Autoupdate.app"
codesign --timestamp --options runtime -f -s "${CODESIGN}" --deep "${AUTOUPDATEAPP}"
codesign --timestamp --options runtime -f -s "${CODESIGN}" "${SPARKLE}"
codesign --timestamp --options runtime -f -s "${CODESIGN}" "${APP}"
VERSION="$(defaults read "${APP}/Contents/Info.plist" CFBundleShortVersionString)"
DMG="$(echo "${APPNAME} ${VERSION}.dmg" | tr " " "_")"
FOLDER="${APPNAME} ${VERSION}"
rm -rf "${FOLDER}"
mkdir -p "${FOLDER}"
cp -Rp "${APP}" "docs/ReleaseNotes.html" "License.txt" "${FOLDER}"
hdiutil create -fs "HFS+" -format UDBZ -srcfolder "${FOLDER}" -ov "${DMG}"
rm -rf "${FOLDER}"
codesign --timestamp -s "${CODESIGN}" "${DMG}"
