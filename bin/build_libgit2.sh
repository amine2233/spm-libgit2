#!/usr/bin/env bash

# Copyright 2021 Naked Software, LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# build_libgit2.sh
#
# This program automates the steps required to build libgit2 in order to be
# linked into an iOS application or framework, or linked with another library
# that depends on libgit2 for iOS.
#
# Usage: bin/build_libgit2.sh

set -euo pipefail

SCRIPT_DIR=$(dirname $0)
pushd $SCRIPT_DIR/.. > /dev/null
ROOT_PATH=$PWD
popd > /dev/null

PLATFORMS="OS SIMULATOR CATALYST_X86_64 CATALYST_ARM64 MACOS"
for PLATFORM in $PLATFORMS
do
    echo "Building libgit2 for $PLATFORM"

    rm -rf /tmp/libgit2
    cp -r External/libgit2 /tmp/

    pushd /tmp/libgit2 > /dev/null

    LOG=/tmp/libgit2-$PLATFORM.log
    rm -f $LOG

    OUTPUT_PATH=$ROOT_PATH/build/libgit2/$PLATFORM
    rm -rf $OUTPUT_PATH

    case $PLATFORM in
        "OS" )
            OPENSSL_ROOT_DIR=$ROOT_PATH/build/openssl/ios64
            OPENSSL_LIBRARIES_DIR=$ROOT_PATH/build/openssl/lib
            ;;

        "SIMULATOR" )
            OPENSSL_ROOT_DIR=$ROOT_PATH/build/openssl/iossimulator
            OPENSSL_LIBRARIES_DIR=$OPENSSL_ROOT_DIR/lib
            ;;

        CATALYST* )
            OPENSSL_ROOT_DIR=$ROOT_PATH/build/openssl/catalyst
            OPENSSL_LIBRARIES_DIR=$OPENSSL_ROOT_DIR/lib
            ;;
        
        "MACOS" )
            OPENSSL_ROOT_DIR=$ROOT_PATH/build/openssl/mac64
            OPENSSL_LIBRARIES_DIR=$ROOT_PATH/build/openssl/mac/lib
            ;;
    esac

    OPENSSL_INCLUDE_DIR=$OPENSSL_ROOT_DIR/include
    OPENSSL_CRYPTO_LIBRARY=$OPENSSL_LIBRARIES_DIR/libcrypto.a
    OPENSSL_SSL_LIBRARY=$OPENSSL_LIBRARIES_DIR/libssl.a
    LIBSSH2_ROOT_DIR=$ROOT_PATH/build/libssh2/$PLATFORM

    case $PLATFORM in
        "OS" )
            PLATFORM_ARGS=(-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0)
            ;;
        "SIMULATOR" )
            PLATFORM_ARGS=(-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator "-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64" -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0)
            ;;
        "CATALYST_X86_64" )
            PLATFORM_ARGS=(-DCMAKE_OSX_ARCHITECTURES=x86_64 "-DCMAKE_C_FLAGS=-target x86_64-apple-ios13.1-macabi")
            ;;
        "CATALYST_ARM64" )
            PLATFORM_ARGS=(-DCMAKE_OSX_ARCHITECTURES=arm64 "-DCMAKE_C_FLAGS=-target arm64-apple-ios13.1-macabi")
            ;;
        "MACOS" )
            PLATFORM_ARGS=(-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15)
            ;;
    esac

    mkdir bin
    cd bin
    cmake \
        "${PLATFORM_ARGS[@]}" \
        -DCMAKE_INSTALL_PREFIX=$OUTPUT_PATH \
        -DOPENSSL_ROOT_DIR=$OPENSSL_ROOT_DIR \
        -DOPENSSL_CRYPTO_LIBRARY=$OPENSSL_CRYPTO_LIBRARY \
        -DOPENSSL_SSL_LIBRARY=$OPENSSL_SSL_LIBRARY \
        -DOPENSSL_INCLUDE_DIR=$OPENSSL_INCLUDE_DIR \
        -DBUILD_SHARED_LIBS=OFF \
        -DUSE_SSH=libssh2 \
        -DUSE_HTTPS=OpenSSL \
        -DPKG_CONFIG_EXECUTABLE=/usr/bin/false \
        -DLIBSSH2_INCLUDE_DIR=$LIBSSH2_ROOT_DIR/include \
        -DLIBSSH2_LIBRARY=$LIBSSH2_ROOT_DIR/lib/libssh2.a \
        -DBUILD_TESTS=OFF \
        -DBUILD_CLI=OFF \
        .. >> $LOG 2>&1
    cmake --build . --target install >> $LOG 2>&1

    popd > /dev/null
done

echo "Creating the universal Catalyst library"

CATALYST_PATH=$ROOT_PATH/build/libgit2/CATALYST
rm -rf $CATALYST_PATH
mkdir -p $CATALYST_PATH/lib
cp -R $ROOT_PATH/build/libgit2/CATALYST_X86_64/include $CATALYST_PATH/include
lipo -create \
    $ROOT_PATH/build/libgit2/CATALYST_X86_64/lib/libgit2.a \
    $ROOT_PATH/build/libgit2/CATALYST_ARM64/lib/libgit2.a \
    -output $CATALYST_PATH/lib/libgit2.a

echo "Creating the XCFramework"

LIB_PATH=$ROOT_PATH/lib/libgit2
LIBGIT2_PATH=$LIB_PATH/libgit2.xcframework
rm -rf $LIBGIT2_PATH
mkdir -p $LIB_PATH

xcodebuild -create-xcframework \
    -library $ROOT_PATH/build/libgit2/OS/lib/libgit2.a \
    -headers $ROOT_PATH/build/libgit2/OS/include \
    -library $ROOT_PATH/build/libgit2/SIMULATOR/lib/libgit2.a \
    -headers $ROOT_PATH/build/libgit2/SIMULATOR/include \
    -library $ROOT_PATH/build/libgit2/CATALYST/lib/libgit2.a \
    -headers $ROOT_PATH/build/libgit2/CATALYST/include \
    -library $ROOT_PATH/build/libgit2/MACOS/lib/libgit2.a \
    -headers $ROOT_PATH/build/libgit2/MACOS/include \
    -output $LIBGIT2_PATH

pushd $LIB_PATH > /dev/null
zip -r ../libgit2.zip .
popd > /dev/null

echo "Done; cleaning up"
rm -rf /tmp/libgit2