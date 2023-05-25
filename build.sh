#!/bin/bash

#--------------------------------------------------------------------
# Script params

LIBNAME="libopen3d"
# REBUILDLIBS="YES"

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
    local LIBGIT="$1"
    local LIBGITVER="$2"
    local LIBBUILD="$3"

    # Check out c++ library if needed
    if [ ! -d "${LIBBUILD}" ]; then
        Log "Checking out: ${LIBGIT} -> ${LIBGITVER}"
        git clone ${LIBGIT} ${LIBBUILD}
        if [ ! -z "${LIBGITVER}" ]; then
            # cd "${LIBBUILD}"
            # git checkout ${LIBGITVER}
            # cd "${BUILDOUT}"
            git clone -b ${LIBGITVER} ${LIBGIT} ${LIBBUILD}
        else
            git clone ${LIBGIT} ${LIBBUILD}
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

if [[ $BUILDTARGET == *"ios"* ]]; then
    OS="ios"
else
    OS="macos"
fi

if [[ $BUILDTARGET == *"arm64"* ]]; then
    ARCH="arm64"
else
    ARCH="x86_64"
fi

TARGET="${OS}-${ARCH}"

# NUMCPUS=1
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

LIBROOT="${BUILDOUT}/${TARGET}/lib3"
LIBINST="${BUILDOUT}/${TARGET}/install"

PKGNAME="${LIBNAME}.a.xcframework"
PKGROOT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}"
PKGOUT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}.zip"

# iOS toolchain
if [[ $BUILDTARGET == *"ios"* ]]; then
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
fi


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


LIBBUILD="${LIBROOT}/${LIBNAME}"
LIBBUILDOUT="${LIBBUILD}/build"
LIBINSTFULL="${LIBINST}/${BUILDTARGET}/${BUILDTYPE}"


if [ "$TARGET" == "ios-arm64" ]; then

    #-------------------------------------------------------------------
    # Checkout and build Open3D
    #-------------------------------------------------------------------
    if    [ ! -z "${REBUILDLIBS}" ] \
    || [ ! -f "${LIBBUILDOUT}/lib/iOS/libOpen3D.a" ]; then

        Log "Building ${LIBNAME}..."

        gitCheckout "https://github.com/kewlbear/Open3D.git" "0.17.0-1fix6008" "${LIBBUILD}"

        sed -i '' "s|../ios/iOS.cmake|${LIBINSTFULL}|g" "${LIBBUILD}/ios/build.sh"

        sed -i '' "s|, r2|;// +++ , r2|g" \
            "${LIBBUILD}/cpp/open3d/pipelines/registration/FastGlobalRegistration.cpp"
        sed -i '' "s|r2 |;// +++ r2 |g" \
            "${LIBBUILD}/cpp/open3d/pipelines/registration/FastGlobalRegistration.cpp"

        sed -i '' "s|    Material(const Material &mat) = default;|    // +++ Material(const Material &mat) = default;|g" \
            "${LIBBUILD}/cpp/open3d/visualization/rendering/Material.h"

        cd "${LIBBUILD}"
        sh ios/all.sh

        cd "${ROOTDIR}"

        if [ ! -f "${LIBBUILDOUT}/lib/iOS/libOpen3D.a" ]; then
            exitWithError "Failed to build libOpen3D.a"
        fi

    fi


    #-------------------------------------------------------------------
    # libopen3d package
    #-------------------------------------------------------------------
    if    [ ! -z "${REBUILDLIBS}" ] \
       || [ ! -f "${PKGOUT}/${TARGET}" ]; then

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
        LIBSRC="\
                ${LIBBUILDOUT}/lib/iOS/libOpen3D.a \
                ${LIBBUILDOUT}/lib/iOS/libOpen3D_3rdparty_liblzf.a \
                ${LIBBUILDOUT}/lib/iOS/libOpen3D_3rdparty_qhullcpp.a \
                ${LIBBUILDOUT}/lib/iOS/libOpen3D_3rdparty_qhull_r.a \
                ${LIBBUILDOUT}/lib/iOS/libOpen3D_3rdparty_rply.a \
                ${LIBBUILDOUT}/lib/iOS/libOpen3D_3rdparty_rply.a \
                ${LIBBUILDOUT}/assimp/lib/libassimp.a \
                ${LIBBUILDOUT}/assimp/lib/libIrrXML.a \
                ${LIBBUILDOUT}/assimp/lib/libzlibstatic.a \
                ${LIBBUILDOUT}/libpng/src/ext_libpng-build/Release-iphoneos/libpng.a \
                ${LIBBUILDOUT}/libpng/src/ext_libpng-build/Release-iphoneos/libpng16.a \
                ${LIBBUILDOUT}/turbojpeg/lib/libjpeg.a \
                "

        ls -l ${LIBSRC}
        libtool -static -o "${PKGROOT}/${TARGET}/${LIBNAME}.a" ${LIBSRC}

        INCPATH="include"
        LIBPATH="${LIBNAME}.a"

        # Copy manifest
        cp "${ROOTDIR}/Info.target.plist.in" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%OS%%|${OS}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%ARCH%%|${ARCH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%INCPATH%%|${INCPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%LIBPATH%%|${LIBPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"

    fi


elif [ "$TARGET" == "macos-arm64" ]; then


    #-------------------------------------------------------------------
    # Checkout and build Open3D
    #-------------------------------------------------------------------
    if    [ ! -z "${REBUILDLIBS}" ] \
       || [ ! -f "${LIBINSTFULL}/lib/libOpen3D.a" ]; then

        LIBGIT="https://github.com/isl-org/Open3D"
        LIBGITVER="0.17.0-1fix6008"

        # Check out c++ library if needed
        if [ ! -d "${LIBBUILD}" ]; then
            Log "Checking out: ${LIBGIT} : ${LIBGITVER}"
            git clone ${LIBGIT} ${LIBBUILD}
            if [ ! -z "${LIBGITVER}" ]; then
                cd "${LIBBUILD}"
                git checkout ${LIBGITVER}
                cd "${ROOTDIR}"
            fi
        fi

        # Mods
        sed -i '' "s/std::min(kMaxThreads, num_searches);/std::min(kMaxThreads, num_searches); (void)kOuterThreads;/g" \
            "${LIBBUILD}/cpp/open3d/pipelines/registration/Feature.cpp"
        sed -i '' "s/std::max(kMaxThreads \/ num_searches, 1);/std::max(kMaxThreads \/ num_searches, 1); (void)kInnerThreads;/g" \
            "${LIBBUILD}/cpp/open3d/pipelines/registration/Feature.cpp"
        sed -i '' "s/std::min(kMaxThreads, num_searches);/std::min(kMaxThreads, num_searches); (void)kOuterThreads;/g" \
            "${LIBBUILD}/cpp/open3d/t/pipelines/registration/Feature.cpp"
        sed -i '' "s/<experimental\/filesystem>/<filesystem>/g" \
            "${LIBBUILD}/cpp/open3d/utility/FileSystem.cpp"
        sed -i '' "s/experimental::/__fs::/g" \
            "${LIBBUILD}/cpp/open3d/utility/FileSystem.cpp"

        # Build c++ library if needed
        Log "Rebuilding Open3D"

        cd "${LIBBUILD}"

        cmake . -B ./build -DCMAKE_BUILD_TYPE=${BUILDTYPE} \
                        -DBUILD_GUI=OFF \
                        -DBUILD_EXAMPLES=OFF \
                        -DBUILD_PYTHON_MODULE=OFF \
                        -DENABLE_CACHED_CUDA_MANAGER=OFF \
                        -DENABLE_HEADLESS_RENDERING=OFF \
                        -DBUILD_ISPC_MODULE=OFF \
                        -DCMAKE_INSTALL_PREFIX="${LIBINSTFULL}"

        # Mods After config
        sed -i '' "s/.*sentinel_count.*/\/\/ [REMOVED]/g" \
            "${LIBBUILDOUT}/filament/src/ext_filament/third_party/spirv-tools/source/util/ilist.h"
        sed -i '' "s/StructuredControlState(const StructuredControlState&) = default;/\/\/ [REMOVED]/g" \
            "${LIBBUILDOUT}/filament/src/ext_filament/third_party/spirv-tools/source/opt/merge_return_pass.h"

        cmake --build ./build -j$NUMCPUS

        cmake --install ./build

        cd "${ROOTDIR}"

        if [ ! -f "${LIBINSTFULL}/lib/libOpen3D.a" ]; then
            exitWithError "Failed to build libOpen3D.a"
        fi

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

        # Copy include files
        cp -R "${LIBINSTFULL}/." "${PKGROOT}/${TARGET}/"

        cp -R "${PKGROOT}/${TARGET}/include/open3d/3rdparty/." "${PKGROOT}/${TARGET}/include/"

        # Combine libs
        Log "Runnning libtool..."
        LIBSRC="\
                ${LIBINSTFULL}/lib/libOpen3D.a \
                ${LIBINSTFULL}/lib/libOpen3D_3rdparty_liblzf.a \
                ${LIBINSTFULL}/lib/libOpen3D_3rdparty_qhullcpp.a \
                ${LIBINSTFULL}/lib/libOpen3D_3rdparty_qhull_r.a \
                ${LIBINSTFULL}/lib/libOpen3D_3rdparty_rply.a \
                ${LIBINSTFULL}/lib/libOpen3D_3rdparty_rply.a \
                "

                # ${LIBBUILDOUT}/assimp/lib/libassimp.a \
                # ${LIBBUILDOUT}/assimp/lib/libIrrXML.a \
                # ${LIBBUILDOUT}/assimp/lib/libzlibstatic.a \
                # ${LIBBUILDOUT}/libpng/src/ext_libpng-build/Release-iphoneos/libpng.a \
                # ${LIBBUILDOUT}/libpng/src/ext_libpng-build/Release-iphoneos/libpng16.a \
                # ${LIBBUILDOUT}/turbojpeg/lib/libjpeg.a \
                # "

        ls -l ${LIBSRC}
        libtool -static -o "${PKGROOT}/${TARGET}/${LIBNAME}.a" ${LIBSRC}

        INCPATH="include"
        LIBPATH="${LIBNAME}.a"

        # Copy manifest
        cp "${ROOTDIR}/Info.target.plist.in" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%OS%%|${OS}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%ARCH%%|${ARCH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%INCPATH%%|${INCPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%LIBPATH%%|${LIBPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"

    fi

fi

if [ -d "${PKGROOT}" ]; then

    cd "${PKGROOT}"

    TARGETINFO=
    for SUB in */; do
        echo "Adding: $SUB"
        if [ -f "${SUB}/Info.target.plist" ]; then
            TARGETINFO="$TARGETINFO$(cat "${SUB}/Info.target.plist")"
        fi
    done

    if [ ! -z "$TARGETINFO" ]; then

        TARGETINFO=""${TARGETINFO//$'\n'/\\n}""

        cp "${ROOTDIR}/Info.plist.in" "${PKGROOT}/Info.plist"
        sed -i '' "s|%%TARGETS%%|${TARGETINFO}|g" "${PKGROOT}/Info.plist"

        cd "${PKGROOT}/.."

        # Remove old package if any
        if [ -f "$PKGNAME" ]; then
            rm "$PKGNAME"
        fi

        # Create new package
        zip -r "${PKGOUT}" "$PKGNAME" -x "*.DS_Store"
        # touch "${PKGOUT}"

        # Calculate sha256
        openssl dgst -sha256 < "${PKGOUT}" > "${PKGOUT}.zip.sha256.txt"

        cd "${BUILDOUT}"

    fi
fi