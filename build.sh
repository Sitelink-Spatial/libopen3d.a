#!/bin/bash

#--------------------------------------------------------------------
# Script params

LIBNAME="libopen3d"

# What to do (build, test)
BUILDWHAT="$1"

# Build type (release, debug)
BUILDTYPE="$2"

# Build target, i.e. arm64-apple-macosx, aarch64-apple-ios14.0, x86_64-apple-ios13.0-simulator, ...
BUILDTARGET="$3"

# Build Output
BUILDOUT="$4"

#--------------------------------------------------------------------
# Functions

Log()
{
    echo ">>>>>> $@"
}

exitWithError()
{
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "$@"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit -1
}

gitCheckout()
{
    LIBGIT="$1"
    LIBGITVER="$2"
    LIBBUILD="$3"

    # Check out c++ library if needed
    if [ ! -d "${LIBBUILD}" ]; then
        Log "Checking out: ${LIBGIT} -> ${LIBGITVER}"
        git clone ${LIBGIT} ${LIBBUILD}
        if [ ! -z "${LIBGITVER}" ]; then
            cd "${LIBBUILD}"
            git checkout ${LIBGITVER}
            cd "${BUILDOUT}"
        fi
    fi

    if [ ! -d "${LIBBUILD}" ]; then
        exitWithError "Failed to checkout $LIBGIT"
    fi
}

#--------------------------------------------------------------------
# Options

# Sync command
SYNC="rsync -a"

# Default build what
if [ -z "${BUILDWHAT}" ]; then
    BUILDWHAT="build"
fi

# Default build type
if [ -z "${BUILDTYPE}" ]; then
    BUILDTYPE="release"
fi

if [ -z "${BUILDTARGET}" ]; then
    BUILDTARGET="arm64-apple-macosx"
fi

NUMCPUS=$(sysctl -n hw.physicalcpu)

#--------------------------------------------------------------------
# Get root script path
SCRIPTPATH=$(realpath $0)
if [ ! -z "$SCRIPTPATH" ]; then
    ROOTDIR=$(dirname $SCRIPTPATH)
else
    SCRIPTPATH=.
    ROOTDIR=.
fi

#--------------------------------------------------------------------
# Defaults

if [ -z $BUILDOUT ]; then
    BUILDOUT="${ROOTDIR}/build"
else
    # Get path to current directory if needed to use as custom directory
    if [ "$BUILDOUT" == "." ] || [ "$BUILDOUT" == "./" ]; then
        BUILDOUT="$(pwd)"
    fi
fi

# Make custom output directory if it doesn't exist
if [ ! -z "$BUILDOUT" ] && [ ! -d "$BUILDOUT" ]; then
    mkdir -p "$BUILDOUT"
fi

if [ ! -d "$BUILDOUT" ]; then
    exitWithError "Failed to create diretory : $BUILDOUT"
fi


LIBROOT="${BUILDOUT}/lib3"

# iOS toolchain
if [[ $BUILDTARGET == *"ios"* ]]; then
    OS="ios"
    ARCH="arm64"
    gitCheckout "https://github.com/leetal/ios-cmake.git" "4.3.0" "${LIBROOT}/ios-cmake"
    TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=${LIBROOT}/ios-cmake/ios.toolchain.cmake \
               -DPLATFORM=OS64 \
               -DCMAKE_OSX_ARCHITECTURES=\"arm64\" \
               -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
               -DCMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE=\"NO\" \
               -DCMAKE_XCODE_EFFECTIVE_PLATFORMS\"-iphoneos\" \
               -DDEFAULT_SYSROOT=`xcrun --sdk iphoneos --show-sdk-path` \
               -DCMAKE_OSX_SYSROOT=`xcrun --sdk iphoneos --show-sdk-path` \
               -DCMAKE_OSX_SYSROOT_INT=`xcrun --sdk iphoneos --show-sdk-path` \
               "
#              -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=\"iPhone Developer\"
else
    OS="mac"
    ARCH="arm64"
fi

TARGET="${OS}-${ARCH}"
PKGNAME="${LIBNAME}.a.xcframework"
PKGROOT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}"
PKGOUT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}.zip"

#--------------------------------------------------------------------
echo ""
Log "#--------------------------------------------------------------------"
Log "LIBNAME        : ${LIBNAME}"
Log "BUILDWHAT      : ${BUILDWHAT}"
Log "BUILDTYPE      : ${BUILDTYPE}"
Log "BUILDTARGET    : ${BUILDTARGET}"
Log "ROOTDIR        : ${ROOTDIR}"
Log "BUILDOUT       : ${BUILDOUT}"
Log "TARGET         : ${TARGET}"
Log "PKGNAME        : ${PKGNAME}"
Log "PKGROOT        : ${PKGROOT}"
Log "LIBROOT        : ${LIBROOT}"
Log "#--------------------------------------------------------------------"
echo ""

#-------------------------------------------------------------------
# Rebuild lib and copy files if needed
#-------------------------------------------------------------------
if [ ! -d "${LIBROOT}" ]; then

    Log "Reinitializing install..."

    mkdir -p "${LIBROOT}"

    REBUILDLIBS="YES"
fi


LIBBUILD="${LIBROOT}/open3d"
LIBBUILDOUT="${LIBBUILD}/build"

#-------------------------------------------------------------------
# Checkout and build Open3D
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [ ! -d "${LIBBUILD}" ]; then

    Log "Building ${LIBNAME}..."

    gitCheckout "https://github.com/kewlbear/Open3D.git" "0.17.0-1fix6008" "${LIBBUILD}"

    cd "${LIBBUILD}"
    sh ios/all.sh

    cd "${ROOTDIR}"
fi


#-------------------------------------------------------------------
# libopen3d package
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [ ! -f "${PKGOUT}" ]; then

    Log "Packaging ${LIBNAME}..."

    # Re initialize directory
    if [ -d "${PKGROOT}/${TARGET}" ]; then
        rm -Rf "${PKGROOT}/${TARGET}"
    fi
    mkdir -p "${PKGROOT}/${TARGET}"

    # Copy open3d include files
    mkdir -p "${PKGROOT}/${TARGET}/include/open3d"
    cp -R "${LIBBUILD}/cpp/open3d/." "${PKGROOT}/${TARGET}/include/open3d/"

    # Copy eigen include files
    mkdir -p "${PKGROOT}/${TARGET}/include/Eigen"
    cp -R "${LIBBUILDOUT}/eigen/src/ext_eigen/Eigen/." "${PKGROOT}/${TARGET}/include/Eigen/"

    # Copy fmt include files
    mkdir -p "${PKGROOT}/${TARGET}/include/fmt"
    cp -R "${LIBBUILDOUT}/fmt/src/ext_fmt/include/." "${PKGROOT}/${TARGET}/include/"

    # Combine libs
    Log "Runnning libtool..."
    LIBSRC="${LIBBUILDOUT}/build/core.build/Release-iphoneos/libcore.a \
            ${LIBBUILDOUT}/build/io.build/Release-iphoneos/libio.a \
            ${LIBBUILDOUT}/build/camera.build/Release-iphoneos/libcamera.a \
            ${LIBBUILDOUT}/build/geometry.build/Release-iphoneos/libgeometry.a \
            ${LIBBUILDOUT}/assimp/lib/libassimp.a \
            ${LIBBUILDOUT}/assimp/lib/libIrrXML.a \
            ${LIBBUILDOUT}/assimp/lib/libzlibstatic.a \
            "

    ls -l ${LIBSRC}
    libtool -static -o "${PKGROOT}/${TARGET}/${LIBNAME}.a" ${LIBSRC}

    INCPATH="include"
    LIBPATH="${LIBNAME}.a"

    # Copy manifest
    cp "${ROOTDIR}/Info.plist.in" "${PKGROOT}/Info.plist"
    sed -i '' "s#%%OS%%#${OS}#g" "${PKGROOT}/Info.plist"
    sed -i '' "s#%%ARCH%%#${ARCH}#g" "${PKGROOT}/Info.plist"
    sed -i '' "s#%%INCPATH%%#${INCPATH}#g" "${PKGROOT}/Info.plist"
    sed -i '' "s#%%LIBPATH%%#${LIBPATH}#g" "${PKGROOT}/Info.plist"

    # Create package
    cd "${PKGROOT}/.."
    zip -r "${PKGOUT}" "$PKGNAME" -x "*.DS_Store"
    cd "${BUILDOUT}"

    # Calculate sha256
    openssl dgst -sha256 < "${PKGOUT}" > "${PKGOUT}.zip.sha256.txt"

fi

