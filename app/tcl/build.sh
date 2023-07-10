set -e

VERSION=8.6.13
URL=http://prdownloads.sourceforge.net/tcl/tcl${VERSION}-src.tar.gz
FILENAME=tcl.tar.gz
DIR=tcl

if [ ! -f "${FILENAME}" ]; then
    nscurl ${URL} -o "${FILENAME}"
    rm -rf "${DIR}"
    mkdir "${DIR}"
    tar -xvf "${FILENAME}" -C "${DIR}" --strip-components=1
fi

cd "${DIR}/macosx"
./configure
NCPU=$(sysctl -n hw.ncpu)
make embedded -j ${NCPU}
