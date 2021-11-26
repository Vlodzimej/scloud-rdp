#!/bin/bash

brew install coreutils

if git clone https://github.com/FreeRDP/FreeRDP.git FreeRDP_iphoneos
then
  pushd FreeRDP_iphoneos
  git checkout stable-2.0

# iOS Build
  cmake -DCMAKE_TOOLCHAIN_FILE=cmake/iOSToolchain.cmake \
        -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2/openssl_iphoneos) \
        -DCMAKE_CXX_FLAGS:STRING="-DTARGET_OS_IPHONE" \
        -DCMAKE_C_FLAGS:STRING="-DTARGET_OS_IPHONE" \
        -DCMAKE_OSX_ARCHITECTURES="arm64" \
        -GXcode

  cmake --build .
  popd
fi

if git clone https://github.com/FreeRDP/FreeRDP.git FreeRDP_maccatalyst
then
# Mac Catalyst build
  pushd FreeRDP_maccatalyst
  git checkout stable-2.0

  patch -p1 < ../maccatalyst.patch

  MACOSX_SDK_DIR=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  cmake -DCMAKE_TOOLCHAIN_FILE=cmake/iOSToolchain.cmake \
        -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2/openssl_iphoneos) \
        -DUIKIT_FRAMEWORK="${MACOSX_SDK_DIR}/System/iOSSupport/System/Library/Frameworks/UIKit.framework" \
        -DCMAKE_OSX_ARCHITECTURES="x86_64" \
        -DCMAKE_CXX_FLAGS:STRING="-target x86_64-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
        -DCMAKE_C_FLAGS:STRING="-target x86_64-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
        -DCMAKE_IOS_SDK_ROOT=${MACOSX_SDK_DIR} \
        -DWITH_NEON=OFF \
        -G"Unix Makefiles"

  cmake --build .
  popd
fi

# Build one library with all architectures
mkdir libs
for f in $(find FreeRDP_iphoneos/ -name \*.a | sed 's/FreeRDP_iphoneos\///')
do
  lipo FreeRDP_iphoneos/$f FreeRDP_maccatalyst/$(echo $f | sed 's/Debug-iphoneos//') -output libs/$(basename $f) -create
done

/Library/Developer/CommandLineTools/usr/bin//libtool -static -o duperlib.a libs/*

mv duperlib.a ../bVNC.xcodeproj/libs_combined/lib/

# Make all include files available to the project
for d in $(find FreeRDP_iphoneos/ -name include -type d) FreeRDP_iphoneos/client/iOS/FreeRDP/ FreeRDP_iphoneos/client/iOS/Misc/
do
  rsync -avP $d/ ../bVNC.xcodeproj/libs_combined/include/
done
