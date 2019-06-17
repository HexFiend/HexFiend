#!/bin/bash
#
# To build a distributable version of Hex Fiend, you'll need:
# 1. A Developer ID from Apple for code signing
# 2. An account with App Store Connect access for notarization
#
# For the account, you may need to create an app-specific password at appleid.apple.com.
# 
# Once you have the password for the account, add it to Keychain Access' Passwords
# using the name "HexFiendNotarization".
#
# Once this is setup, you can run this script with your Developer ID certificate name,
# and the email address for the App Store Connect account. For example:
#
# $ ./dist.sh "Developer ID Application: My Cool Company" "myself@coolcompany.com"

set -e

usage() {
	echo "Usage: ./dist.sh \"Developer ID Application: My Cool Company\" \"myself@coolcompany.com\""
	exit 1
}

CODESIGN="${1}"
if [ -z "${CODESIGN}" ]; then
	usage
fi

APPSTORE_USER="${2}"
if [ -z "${APPSTORE_USER}" ]; then
	usage
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
IDENTIFIER="$(defaults read "${APP}/Contents/Info.plist" CFBundleIdentifier)"
DMG="$(echo "${APPNAME} ${VERSION}.dmg" | tr " " "_")"
FOLDER="${APPNAME} ${VERSION}"
rm -rf "${FOLDER}"
mkdir -p "${FOLDER}"
cp -Rp "${APP}" "docs/ReleaseNotes.html" "License.txt" "${FOLDER}"
hdiutil create -fs "HFS+" -format UDBZ -srcfolder "${FOLDER}" -ov "${DMG}"
rm -rf "${FOLDER}"
codesign --timestamp -s "${CODESIGN}" "${DMG}"

APPLENOTARYBINARY="./vendor/applenotary/.build/release/applenotary"
if [ ! -f "${APPLENOTARYBINARY}" ]; then
	rm -rf ./vendor/applenotary
	cd vendor
	git clone https://github.com/pluralsight/applenotary.git
	cd applenotary
	git reset --hard 99ae14d2c16c9a3496abba8cc9d6d3d68fd2dd8f
	swift build -c release
	cd ../..
fi
"${APPLENOTARYBINARY}" -f "${DMG}" -s "${DMG}" \
	-b "${IDENTIFIER}" \
	-u "${APPSTORE_USER}" \
	-p "@keychain:HexFiendNotarization"
