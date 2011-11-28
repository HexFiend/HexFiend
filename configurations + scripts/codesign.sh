#!/bin/sh

# This script is an aid to code signing, allowing code signing to either
# happen or not according to the configuration. If CODE_SIGN_IDENTITY_HIDE_FROM_XCODE
# is not set, this does nothing. Otherwise, this signs either 
# WRAPPER_NAME (corresponding to a bundle), or if that is not set, it signs
# EXECUTABLE_PATH (corresponding to an executable).
#
# The reason that it's "CODE_SIGN_IDENTITY_HIDE_FROM_XCODE" is that Xcode sets its "code sign"
# checkbox according to whether CODE_SIGN_IDENTITY is set in build settings; if it is then
# it always tries to code sign.

if [ ! "${CODE_SIGN_IDENTITY_HIDE_FROM_XCODE}" ] ; then
    echo "Not code signing"
    exit 0
fi

if [ "${WRAPPER_NAME}" ]; then
    TOSIGN="${WRAPPER_NAME}"
elif [ "${EXECUTABLE_PATH}" ]; then
    TOSIGN="${EXECUTABLE_PATH}"
else
    echo "I don't know what to sign!"
fi

if [ "${TOSIGN}" ]; then
    echo "Signing ${TOSIGN}"
    set -x
    codesign -f -s "${CODE_SIGN_IDENTITY_HIDE_FROM_XCODE}" "${BUILT_PRODUCTS_DIR}/${TOSIGN}"
else
    echo "Not code signing"
fi
