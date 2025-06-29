#!/bin/bash
#
# To build a distributable version of Hex Fiend, you'll need:
# 1. Xcode 13 or greater
# 2. A Developer ID for code signing
# 3. An account with App Store Connect access for notarization
#
# For the account, you need to create an app-specific password at appleid.apple.com if one does not exist already.
#
# Store the password in Keychain Access:
# $ xcrun notarytool store-credentials HexFiendNotarization --apple-id [APPLEID] --team-id [TEAMID] --password [PASSWORD]
#
# Now you can run this script with your Developer ID certificate name. For example:
#
# $ ./dist.sh "Developer ID Application: My Cool Company"

set -e

usage() {
	echo "Usage: ./dist.sh \"Developer ID Application: My Cool Company\""
	exit 1
}

CODESIGN="${1}"
if [ -z "${CODESIGN}" ]; then
	usage
fi

# Xcode can find a certificate name by just matching by prefix, but this fails
# when it's used in the code requirements for SMJobBless, so make sure the certificate
# exists exactly in Keychain.
# See https://github.com/HexFiend/HexFiend/issues/257#issuecomment-729330382 for details.
set +e
security find-identity -p codesigning -v | grep "\"${CODESIGN}\"" > /dev/null
SECURITY_RET=$?
set -e
if [ "${SECURITY_RET}" != "0" ]; then
	echo "\"${CODESIGN}\" is not valid. Please use an exact certificate name."
	echo
	echo "Here are the valid code signing identities:"
	set +e; security find-identity -p codesigning -v; set -e;
	exit 1
fi

PWD="$(pwd)"
DERIVED_DATA_PATH="${PWD}/DerivedData"
SCHEME="Release + CodeSign"
CONFIG="Release+CodeSign"

rm -rf "${DERIVED_DATA_PATH}"

xcodebuild \
	-project app/HexFiend_2.xcodeproj \
	-scheme "${SCHEME}" \
	-derivedDataPath "${DERIVED_DATA_PATH}" \
	"CODE_SIGN_IDENTITY=${CODESIGN}" \
	"OTHER_CODE_SIGN_FLAGS=--timestamp --options runtime" \
	"CODE_SIGN_ENTITLEMENTS=${PWD}/app/Notarization.entitlements"

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

xcrun notarytool submit "${DMG}" --wait --keychain-profile HexFiendNotarization
xcrun stapler staple "${DMG}"
