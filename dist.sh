#!/bin/bash

set -e

CODESIGN="${1}"
if [ -z "${CODESIGN}" ]; then
	echo "Code signing identity is required."
	exit 1
fi

BUILDDIR="$(pwd)/build"
SCHEME="Release + CodeSign"
CONFIG="Release+CodeSign"
xcodebuild -scheme "${SCHEME}" \
	"CODE_SIGN_IDENTITY=${CODESIGN}" \
	"BUILD_DIR=${BUILDDIR}"

APPNAME="Hex Fiend"
APP="${BUILDDIR}/${CONFIG}/${APPNAME}.app"
VERSION="$(defaults read "${APP}/Contents/Info.plist" CFBundleShortVersionString)"
DMG="$(echo "${APPNAME} ${VERSION}.dmg" | tr " " "_")"
VOL="${APPNAME} ${VERSION}"
hdiutil create -format UDBZ -srcfolder "${APP}" -ov "${DMG}" -volname "${VOL}"
