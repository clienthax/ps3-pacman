#!/usr/bin/env bash
# build-and-install.sh by Wouter Wijsman (wwijsman@live.nl)

# Exit on errors
set -e

## Remove $CC and $CXX for configure
unset CC
unset CXX

## Make sure PS3DEV is set
if [ -z "${PS3DEV}" ]; then
    echo "The PS3DEV environment variable has not been set"
    exit 1
fi

## Enter the script directory.
cd "$(dirname "$0")"
WORKDIR="${PWD}"

## MacOS specific environment variables
if [ "$(uname -s)" == "Darwin" ]; then
    export PATH="$(brew --prefix gnu-sed)/libexec/gnubin:$(brew --prefix bash)/bin:$PATH"
    export PKG_CONFIG_PATH="$(brew --prefix libarchive)/lib/pkgconfig"
fi

## Clean up from previous builds
rm -rf temp_build pkg src psp-pacman-*-*.pkg.tar.gz

## Install makepkg from source if it isn't already available and build the package
if ! which makepkg > /dev/null; then
    echo "Did not find makepkg, downloading and building pacman from source"
    source PS3BUILD
    export pkgdir="${PWD}/temp_build/psp-pacman"
    mkdir -p "${pkgdir}"
    rm -rf pacman-v${pkgver}
    wget -nc ${source[0]}
    tar -xvf pacman-v${pkgver}.tar.gz
    prepare
    cd "$WORKDIR"
    build
    cd "$WORKDIR"
    package
    cd "$WORKDIR"
    export PATH="${pkgdir}/share/pacman/bin:${PATH}"
    if (( EUID == 0 )); then
        CARCH="$(./get-arch)" PS3DEV="${pkgdir}" makepkg -p PS3BUILD --asroot .
    else
        CARCH="$(./get-arch)" PS3DEV="${pkgdir}" makepkg -p PS3BUILD .
    fi
else
    CARCH="$(./get-arch)" makepkg -p PS3BUILD .
fi

## Create the required directories for installation
mkdir -m 755 -p "${PS3DEV}/var/lib/pacman"

## Add the directory with pacman's binaries to the start of the PATH
export PATH="${PWD}/pkg/psp-pacman/share/pacman/bin:${PATH}"

export LD_LIBRARY_PATH="${PWD}/pkg/psp-pacman/lib:${LD_LIBRARY_PATH}"

## The package in $PS3DEV using the pacman that was build
./pkg/psp-pacman/share/pacman/bin/pacman  \
    --root "${PS3DEV}" \
    --dbpath "${PS3DEV}/var/lib/pacman" \
    --config "pacman.conf" \
    --arch "$(./get-arch)" \
    --noconfirm \
    -U psp-pacman-*-*.pkg.tar.gz
