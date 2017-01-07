#!/bin/bash

# This script removes features of Hex Fiend incompatbile
# with the Mac App Store, including Sparkle.framework
# It is expected to be run from Xcode as a build step
# It looks for the variable BUILD_FOR_MAS, and only does
# work if set to 1

set -e

die() { echo "Error: $@" 1>&2 ; exit 1; }

test "${BUILD_FOR_MAS}" = "1" || exit 0

test -d "${BUILT_PRODUCTS_DIR}" || die 'Missing $BUILT_PRODUCTS_DIR'
test -n "${WRAPPER_NAME}" || die 'Missing $WRAPPER_NAME'

apppath="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}"
sparklepath="${apppath}"/Contents/Frameworks/Sparkle.framework
rm -r "${sparklepath}" && echo "Removed ${sparklepath}"
