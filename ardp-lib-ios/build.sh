#!/bin/bash -e

#FREERDP_VERSION=a383740a2f85fa93f390181e5ea4bd1458b34051 # Head of stable-2.0 as of 2024-04-24
#CMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake
FREERDP_VERSION=0a6b999c5655d07b5653894b24a840c08838e304
CMAKE_TOOLCHAIN_FILE=cmake/iOSToolchain.cmake

brew install coreutils

if git clone https://github.com/FreeRDP/FreeRDP.git FreeRDP_iphoneos
then
  pushd FreeRDP_iphoneos
  git checkout ${FREERDP_VERSION}

  patch -p1 < ../freerdp_ifreerdp_library.patch
  patch -p1 < ../freerdp_mac_catalyst.patch
  patch -p1 < ../disable_freerdp_context_free.patch
  patch -p1 < ../clipboard-redirection.patch
  patch -p1 < ../freerdp_fix_for_set_format.patch

  # iOS Build
  cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
      -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2/openssl_iphoneos) \
      -DCMAKE_CXX_FLAGS:STRING="-DTARGET_OS_IPHONE" \
      -DCMAKE_C_FLAGS:STRING="-DTARGET_OS_IPHONE" \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DCMAKE_PREFIX_PATH=$(realpath ../../aspice-lib-ios/cerbero/build/dist/ios_universal) \
      -DWITH_JPEG=ON \
      -DWITH_FFMPEG=ON \
      -DWITH_IOSAUDIO=ON \
      -DWITH_ZLIB=ON \
      -DPLATFORM=OS64 \
      -G"Unix Makefiles"
  popd
fi

pushd FreeRDP_iphoneos
cmake --build . -j 12 -v
popd

if git clone https://github.com/FreeRDP/FreeRDP.git FreeRDP_maccatalyst
then
# Mac Catalyst build
  pushd FreeRDP_maccatalyst
  git checkout ${FREERDP_VERSION}

  patch -p1 < ../freerdp_ifreerdp_library.patch
  patch -p1 < ../freerdp_mac_catalyst.patch
  patch -p1 < ../disable_freerdp_context_free.patch
  patch -p1 < ../clipboard-redirection.patch
  patch -p1 < ../freerdp_fix_for_set_format.patch

  MACOSX_SDK_DIR=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

  cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
      -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2/openssl_iphoneos) \
      -DUIKIT_FRAMEWORK="${MACOSX_SDK_DIR}/System/iOSSupport/System/Library/Frameworks/UIKit.framework" \
      -DCMAKE_OSX_ARCHITECTURES="x86_64" \
      -DCMAKE_CXX_FLAGS:STRING="-target x86_64-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
      -DCMAKE_C_FLAGS:STRING="-target x86_64-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
      -DCMAKE_IOS_SDK_ROOT=${MACOSX_SDK_DIR} \
      -DWITH_NEON=OFF \
      -DCMAKE_PREFIX_PATH=$(realpath ../../aspice-lib-ios/cerbero/build/dist/ios_universal) \
      -DWITH_JPEG=ON \
      -DWITH_FFMPEG=OFF \
      -DWITH_IOSAUDIO=ON \
      -DWITH_ZLIB=ON \
      -DPLATFORM=MAC_CATALYST \
      -G"Unix Makefiles"
  popd
fi
pushd FreeRDP_maccatalyst
cmake --build . -j 12 -v
popd

# Build one library with all architectures
mkdir -p libs
for f in $(find FreeRDP_iphoneos/ -name \*.a | sed 's/FreeRDP_iphoneos\///')
do
#  lipo FreeRDP_iphoneos/$f FreeRDP_maccatalyst/$(echo $f | sed 's/Debug-iphoneos//') -output libs/$(basename $f) -create
  lipo FreeRDP_iphoneos/$f FreeRDP_maccatalyst/$f -output libs/$(basename $f) -create
done

libtool -static -o duperlib.a libs/*

mv duperlib.a ../bVNC.xcodeproj/libs_combined/lib/

# Make all include files available to the project
for d in $(find FreeRDP_maccatalyst/ -name include -type d) FreeRDP_maccatalyst/client/iOS/FreeRDP/ FreeRDP_maccatalyst/client/iOS/Misc/
do
  rsync -avP $d/ ../bVNC.xcodeproj/libs_combined/include/
done
