set -e

VERSION=8.6.13
URL=http://prdownloads.sourceforge.net/tcl/tcl${VERSION}-src.tar.gz
FILENAME=tcl.tar.gz
DIR=tcl
FRAMEWORK_DIR=build/tcl/Tcl.framework

# Download the archive if it doesn't exist.
# The SourceForge url downloads automatically if it determines the user agent isn't a browser.
# nscurl automatically handles redirects by default.
if [ ! -f "${FILENAME}" ]; then
    nscurl ${URL} -o "${FILENAME}"
fi

# Clear out any existing expanded folder and extract the archive.
rm -rf "${DIR}"
mkdir "${DIR}"
tar -xvf "${FILENAME}" -C "${DIR}" --strip-components=1

# Build
pushd "${DIR}/macosx"
./configure
NCPU=$(sysctl -n hw.ncpu)
make embedded -j ${NCPU}
popd

# Remove files that cause code signing errors. These don't appear to be needed.
pushd "${FRAMEWORK_DIR}/Versions/Current"
rm libtclstub8.6.a
rm tclConfig.sh
rm tclooConfig.sh
popd
