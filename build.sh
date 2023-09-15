#!/bin/bash

# Examples:
#
#   Build for desktop
#   > ./build.sh build release arm64-apple-macos13.0
#
#   Build for iphone
#   > ./build.sh build release arm64-apple-ios12.0
#
#   Build for iphone
#   > ./build.sh build release x86_64-apple-ios12.0-simulator

# Package layout
#
# ├── Info.plist
# ├── [ios-arm64]
# │     ├── mylib.a
# │     └── [include]
# ├── [ios-arm64_x86_64-simulator]
# │     ├── mylib.a
# │     └── [include]
# └── [macos-arm64_x86_64]
#       ├── mylib.a
#       └── [include]


#--------------------------------------------------------------------
# Script params

LIBNAME="libopen3d"

# What to do (build, test)
BUILDWHAT="$1"

# Build type (release, debug)
BUILDTYPE="$2"

# Build target, i.e. arm64-apple-macos13.0, aarch64-apple-ios12.0, x86_64-apple-ios12.0-simulator, ...
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

exitOnError()
{
    if [[ 0 -eq $? ]]; then return 0; fi
    exitWithError $@
}

gitCheckout()
{
    local LIBGIT="$1"
    local LIBGITVER="$2"
    local LIBBUILD="$3"

    # Check out c++ library if needed
    if [ ! -d "${LIBBUILD}" ]; then
        Log "Checking out: ${LIBGIT} -> ${LIBGITVER}"
        if [ ! -z "${LIBGITVER}" ]; then
            git clone  --recurse-submodules --depth 1 -b ${LIBGITVER} ${LIBGIT} ${LIBBUILD}
        else
            git clone  --recurse-submodules ${LIBGIT} ${LIBBUILD}
        fi
    fi

    if [ ! -d "${LIBBUILD}" ]; then
        exitWithError "Failed to checkout $LIBGIT"
    fi
}

extractVersion()
{
    local tuple="$1"
    local key="$2"
    local version=""

    IFS='-' read -ra components <<< "$tuple"
    for component in "${components[@]}"; do
        if [[ $component == ${key}* ]]; then
        version="${component#$key}"
        break
        fi
    done

    echo "$version"
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
    BUILDTARGET="arm64-apple-macos"
fi

# ios-arm64_x86_64-simulator
if [[ $BUILDTARGET == *"ios"* ]]; then
    TGT_OS="ios"
    else
    TGT_OS="macos"
fi

if [[ $BUILDTARGET == *"arm64"* ]]; then
    if [[ $BUILDTARGET == *"x86_64"* ]]; then
        TGT_ARCH="arm64_x86_64"
    elif [[ $BUILDTARGET == *"x86"* ]]; then
        TGT_ARCH="arm64_x86"
    else
        TGT_ARCH="arm64"
    fi
elif [[ $BUILDTARGET == *"x86_64"* ]]; then
    TGT_ARCH="x86_64"
elif [[ $BUILDTARGET == *"x86"* ]]; then
    TGT_ARCH="x86"
else
    exitWithError "Invalid architecture : $BUILDTARGET"
fi

TGT_OPTS=
if [[ $BUILDTARGET == *"simulator"* ]]; then
    TGT_OPTS="-simulator"
fi

# NUMCPUS=1
NUMCPUS=$(sysctl -n hw.physicalcpu)

#--------------------------------------------------------------------
# Get root script path
if [ ! -z "$0" ] && [ ! -z "$(which realpath)" ]; then
SCRIPTPATH=$(realpath $0)
fi
ROOTDIR="$GITHUB_WORKSPACE"
if [ -z "$ROOTDIR" ]; then
    if [[ -z "$SCRIPTPATH" ]] || [[ "." == "$SCRIPTPATH" ]]; then
        ROOTDIR=$(pwd)
    elif [ ! -z "$SCRIPTPATH" ]; then
        ROOTDIR=$(dirname $SCRIPTPATH)
    else
        SCRIPTPATH=.
        ROOTDIR=.
    fi
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

# Add build type to output folder
BUILDOUT="${BUILDOUT}/${BUILDTYPE}"

# Make custom output directory if it doesn't exist
if [ ! -z "$BUILDOUT" ] && [ ! -d "$BUILDOUT" ]; then
    mkdir -p "$BUILDOUT"
fi

if [ ! -d "$BUILDOUT" ]; then
    exitWithError "Failed to create diretory : $BUILDOUT"
fi

TARGET="${TGT_OS}-${TGT_ARCH}${TGT_OPTS}"

LIBROOT="${BUILDOUT}/${BUILDTARGET}/lib3"
LIBINST="${BUILDOUT}/${BUILDTARGET}/install"

PKGNAME="${LIBNAME}.a.xcframework"
PKGROOT="${BUILDOUT}/pkg/${PKGNAME}"
PKGFILE="${BUILDOUT}/pkg/${PKGNAME}.zip"

# iOS toolchain
if [[ $BUILDTARGET == *"ios"* ]]; then

    TGT_OSVER=$(extractVersion "$BUILDTARGET" "ios")
    if [ -z "$TGT_OSVER" ]; then
        TGT_OSVER="14.0"
    fi

    gitCheckout "https://github.com/leetal/ios-cmake.git" "4.3.0" "${LIBROOT}/ios-cmake"

    if [[ $BUILDWHAT == *"xbuild"* ]]; then
        TOOLCHAIN="${TOOLCHAIN} -GXcode"
    fi

    # https://github.com/leetal/ios-cmake/blob/master/ios.toolchain.cmake
    if [[ $BUILDTARGET == *"simulator"* ]]; then
        if [ "${TGT_ARCH}" == "x86" ]; then
            TGT_PLATFORM="SIMULATOR"
        elif [ "${TGT_ARCH}" == "x86_64" ]; then
            TGT_PLATFORM="SIMULATOR64"
        else
            TGT_PLATFORM="SIMULATORARM64"
        fi
    else
        if [ "${TGT_ARCH}" == "x86" ]; then
            TGT_PLATFORM="OS"
        elif [ "${TGT_ARCH}" == "x86_64" ]; then
            TGT_ARCH="arm64_x86_64"
            TGT_PLATFORM="OS64COMBINED"
        else
            TGT_PLATFORM="OS64"
        fi
    fi

    TARGET="${TGT_OS}-${TGT_ARCH}${TGT_OPTS}"
    TOOLCHAIN="${TOOLCHAIN} \
               -DCMAKE_TOOLCHAIN_FILE=${LIBROOT}/ios-cmake/ios.toolchain.cmake \
               -DPLATFORM=${TGT_PLATFORM} \
               -DENABLE_BITCODE=OFF \
               -DDEPLOYMENT_TARGET=$TGT_OSVER \
               "
else
    TGT_OSVER=$(extractVersion "$BUILDTARGET" "macos")
    if [ -z "$TGT_OSVER" ]; then
        TGT_OSVER="13.2"
    fi

    TOOLCHAIN="${TOOLCHAIN} \
               -DCMAKE_OSX_DEPLOYMENT_TARGET=$TGT_OSVER \
               -DCMAKE_OSX_ARCHITECTURES=$TGT_ARCH
               "
fi

TOOLCHAIN="${TOOLCHAIN} \
            -DCMAKE_CXX_STANDARD=17 \
            "


#--------------------------------------------------------------------
showParams()
{
    echo ""
    Log "#--------------------------------------------------------------------"
    Log "LIBNAME        : ${LIBNAME}"
    Log "BUILDWHAT      : ${BUILDWHAT}"
    Log "BUILDTYPE      : ${BUILDTYPE}"
    Log "BUILDTARGET    : ${BUILDTARGET}"
    Log "ROOTDIR        : ${ROOTDIR}"
    Log "BUILDOUT       : ${BUILDOUT}"
    Log "TARGET         : ${TARGET}"
    Log "OSVER          : ${TGT_OSVER}"
    Log "ARCH           : ${TGT_ARCH}"
    Log "PLATFORM       : ${TGT_PLATFORM}"
    Log "PKGNAME        : ${PKGNAME}"
    Log "PKGROOT        : ${PKGROOT}"
    Log "LIBROOT        : ${LIBROOT}"
    Log "#--------------------------------------------------------------------"
    echo ""
}
showParams


#-------------------------------------------------------------------
# Rebuild lib and copy files if needed
#-------------------------------------------------------------------
if [[ $BUILDWHAT == *"clean"* ]]; then
    if [ -d "${LIBROOT}" ]; then
        rm -Rf "${LIBROOT}"
    fi
fi

if [ ! -d "${LIBROOT}" ]; then

    Log "Reinitializing install..."

    mkdir -p "${LIBROOT}"

    REBUILDLIBS="YES"
fi


LIBBUILD="${LIBROOT}/${LIBNAME}"
LIBBUILDOUT="${LIBBUILD}/build"
LIBINSTFULL="${LIBINST}/${BUILDTARGET}/${BUILDTYPE}"


if [ "$TGT_OS" == "ios" ]; then

    #-------------------------------------------------------------------
    # Checkout and build Open3D
    #-------------------------------------------------------------------

    if [[ $BUILDTARGET == *"simulator"* ]]; then
        OUTKEY="${LIBBUILDOUT}/build/core.build/Release-iphonesimulator/libcore.a"
    else
        OUTKEY="${LIBBUILDOUT}/lib/iOS/libOpen3D.a"
    fi

    if    [ ! -z "${REBUILDLIBS}" ] \
    || [ ! -f "${OUTKEY}" ]; then

        Log "Building ${LIBNAME}..."

        # Remove existing package
        rm -Rf "${PKGROOT}/${TARGET}"

        gitCheckout "https://github.com/kewlbear/Open3D.git" "iOS" "${LIBBUILD}"

        # !!! Can't just do this, installation path is hardcoded other places
        # sed -i '' "s|../ios/install|${LIBINSTFULL}|g" "${LIBBUILD}/ios/config.sh"

        # Allows building more than once, simulator build often fails the first time...
        sed -i '' "s|rm -rf build|# +++ rm -rf build|g" \
            "${LIBBUILD}/ios/config.sh"
        # sed -i '' "s|CMAKE_OSX_DEPLOYMENT_TARGET=13|CMAKE_OSX_DEPLOYMENT_TARGET=14|g" \
        #     "${LIBBUILD}/ios/config.sh"


        sed -i '' "s|, r2|;// +++ , r2|g" \
            "${LIBBUILD}/cpp/open3d/pipelines/registration/FastGlobalRegistration.cpp"
        sed -i '' "s|r2 |;// +++ r2 |g" \
            "${LIBBUILD}/cpp/open3d/pipelines/registration/FastGlobalRegistration.cpp"

        sed -i '' "s|    Material(const Material &mat) = default;|    // +++ Material(const Material &mat) = default;|g" \
            "${LIBBUILD}/cpp/open3d/visualization/rendering/Material.h"


        if [[ $BUILDTARGET == *"simulator"* ]]; then

            cd "${LIBBUILD}/ios"
            git clone https://github.com/kewlbear/LAPACKE-iOS.git

            cd "${LIBBUILD}"
            mkdir -p "${LIBBUILD}/build"
            cmake . -B ./build -DCMAKE_BUILD_TYPE=${BUILDTYPE} \
                -DBUILD_CUDA_MODULE=OFF \
                -DBUILD_GUI=OFF \
                -DBUILD_TENSORFLOW_OPS=OFF \
                -DBUILD_PYTORCH_OPS=OFF \
                -DBUILD_UNIT_TESTS=OFF \
                -DBUILD_ISPC_MODULE=OFF \
                -DCMAKE_INSTALL_PREFIX=../ios/install \
                -DBUILD_EXAMPLES=OFF \
                -DWITH_IPPICV=OFF \
                -GXcode \
                -DCMAKE_TOOLCHAIN_FILE=../ios/iOS.cmake \
                "-DCMAKE_OSX_ARCHITECTURES=arm64;x86_64" \
                -DCMAKE_OSX_DEPLOYMENT_TARGET=13 \
                -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO

            xcodebuild -project build/Open3D.xcodeproj -target ext_qhull -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
            xcodebuild -project build/Open3D.xcodeproj -target install -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
            xcodebuild -project build/Open3D.xcodeproj -target pybind -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
            xcodebuild -project build/turbojpeg/src/ext_turbojpeg-build/libjpeg-turbo.xcodeproj -target turbojpeg-static -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
            xcodebuild -project build/libpng/src/ext_libpng-build/libpng.xcodeproj -target png_static -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
            xcodebuild -project build/jsoncpp/src/ext_jsoncpp-build/jsoncpp.xcodeproj -target jsoncpp_static -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
            xcodebuild -project build/faiss/src/ext_faiss-build/faiss.xcodeproj -target faiss -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
            xcodebuild -project build/tbb/src/ext_tbb-build/tbb.xcodeproj -target tbb_static -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
            xcodebuild -project build/assimp/src/ext_assimp-build/Assimp.xcodeproj -target assimp -configuration Release -sdk iphonesimulator -xcconfig ios/override.xcconfig
        else
            cd "${LIBBUILD}"
            sh ios/all.sh
        fi

        if [ ! -f "${OUTKEY}" ]; then
            exitWithError "Failed to build ${OUTKEY}"
        fi

        cmake --install ./build

        cd "${ROOTDIR}"

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

        if [[ $BUILDTARGET == *"simulator"* ]]; then
            LIBSRC="\
                    ${LIBBUILDOUT}/lib/Release/libOpen3D.a \
                    ${LIBBUILDOUT}/lib/Release/libOpen3D_3rdparty_liblzf.a \
                    ${LIBBUILDOUT}/lib/Release/libOpen3D_3rdparty_qhullcpp.a \
                    ${LIBBUILDOUT}/lib/Release/libOpen3D_3rdparty_qhull_r.a \
                    ${LIBBUILDOUT}/lib/Release/libOpen3D_3rdparty_rply.a \
                    ${LIBBUILDOUT}/lib/Release/libOpen3D_3rdparty_rply.a \
                    ${LIBBUILDOUT}/assimp/lib/libassimp.a \
                    ${LIBBUILDOUT}/assimp/lib/libIrrXML.a \
                    ${LIBBUILDOUT}/assimp/lib/libzlibstatic.a \
                    ${LIBBUILDOUT}/libpng/src/ext_libpng-build/Release-iphonesimulator/libpng.a \
                    ${LIBBUILDOUT}/libpng/src/ext_libpng-build/Release-iphonesimulator/libpng16.a \
                    ${LIBBUILDOUT}/turbojpeg/lib/libjpeg.a \
                    "
        else
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
        fi

        ls -l ${LIBSRC}
        libtool -static -o "${PKGROOT}/${TARGET}/${LIBNAME}.a" ${LIBSRC}

        INCPATH="include"
        LIBPATH="${LIBNAME}.a"

        # Copy manifest
        cp "${ROOTDIR}/Info.target.plist.in" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%TARGET%%|${TARGET}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%OS%%|${TGT_OS}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%ARCH%%|${TGT_ARCH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%INCPATH%%|${INCPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%LIBPATH%%|${LIBPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"

        EXTRA=
        if [[ $BUILDTARGET == *"simulator"* ]]; then
            EXTRA="<key>SupportedPlatformVariant</key><string>simulator</string>"
        fi
        sed -i '' "s|%%EXTRA%%|${EXTRA}|g" "${PKGROOT}/${TARGET}/Info.target.plist"

    fi

elif [ "$TARGET" == "macos-arm64" ]; then


    #-------------------------------------------------------------------
    # Checkout and build Open3D
    #-------------------------------------------------------------------
    if    [ ! -z "${REBUILDLIBS}" ] \
       || [ ! -f "${LIBINSTFULL}/lib/libOpen3D.a" ]; then

        gitCheckout "https://github.com/isl-org/Open3D.git" "v0.17.0-1fix6008" "${LIBBUILD}"

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
                        ${TOOLCHAIN} \
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
        sed -i '' "s|%%TARGET%%|${TARGET}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%OS%%|${TGT_OS}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%ARCH%%|${TGT_ARCH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%INCPATH%%|${INCPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
        sed -i '' "s|%%LIBPATH%%|${LIBPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"

        EXTRA=
        if [[ $BUILDTARGET == *"simulator"* ]]; then
            EXTRA="<key>SupportedPlatformVariant</key><string>simulator</string>"
        fi
        sed -i '' "s|%%EXTRA%%|${EXTRA}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    fi
fi


#-------------------------------------------------------------------
# Create full package
#-------------------------------------------------------------------
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
        if [ -f "${PKGFILE}" ]; then
            rm "${PKGFILE}"
        fi

        # Create new package
        zip -r "${PKGFILE}" "$PKGNAME" -x "*.DS_Store"

        # Calculate sha256
        openssl dgst -sha256 -r < "${PKGFILE}" | cut -f1 -d' ' > "${PKGFILE}.sha256.txt"

        cd "${BUILDOUT}"

    fi
fi

showParams
