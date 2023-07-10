set -e

VERSION_MAJOR=8
VERSION_MINOR=6
VERSION_PATCH=13
VERSION=${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
URL=http://prdownloads.sourceforge.net/tcl/tcl${VERSION}-src.tar.gz
FILENAME=tcl.tar.gz
DIR=tcl
BUILD_DIR=build
FRAMEWORK_DIR=${BUILD_DIR}/tcl/Tcl.framework

# Determine the deployment target from the Xcode project.
# Assume the current directory is this script's directory.
pushd ../../
BUILD_SETTINGS=build_settings.plist
xcodebuild -showBuildSettings -json | plutil -convert xml1 - -o "${BUILD_SETTINGS}"
DEPLOYMENT_TARGET=$(/usr/libexec/PlistBuddy -c "Print :0:buildSettings:MACOSX_DEPLOYMENT_TARGET" "${BUILD_SETTINGS}" | tr -d "\n")
rm "${BUILD_SETTINGS}"
popd

# Download the archive if it doesn't exist.
# The SourceForge url downloads automatically if it determines the user agent isn't a browser.
# nscurl automatically handles redirects by default.
if [ ! -f "${FILENAME}" ]; then
    nscurl ${URL} -o "${FILENAME}"
fi

# Clear out any existing expanded archive and build, then extract the archive.
rm -rf "${DIR}"
rm -rf "${BUILD_DIR}"
mkdir "${DIR}"
tar -xvf "${FILENAME}" -C "${DIR}" --strip-components=1

# Build
pushd "${DIR}/macosx"
./configure
NCPU=$(sysctl -n hw.ncpu)
MACOSX_DEPLOYMENT_TARGET=${DEPLOYMENT_TARGET} CFLAGS="-arch arm64 -arch x86_64" make embedded -j ${NCPU}
popd

pushd "${FRAMEWORK_DIR}/Versions/Current"

# Fix the install name
install_name_tool -id @rpath/Tcl.framework/Versions/${VERSION_MAJOR}.${VERSION_MINOR}/Tcl Tcl

# Remove files that cause code signing errors. These don't appear to be needed.
rm libtclstub8.6.a
rm tclConfig.sh
rm tclooConfig.sh

popd
