#!/bin/bash -e

FREERDP_VERSION=0ee17e2f8e49d56ab5b90d5160fa8f87ffc445e0 # Head of stable-2.0 as of 2024-12-03
CMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake
#FREERDP_VERSION=0a6b999c5655d07b5653894b24a840c08838e304
#CMAKE_TOOLCHAIN_FILE=cmake/iOSToolchain.cmake

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
  patch -p1 < ../freerdp_sse_guards.patch

  # iOS Build
  cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
      -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2/openssl_iphoneos) \
      -DCMAKE_CXX_FLAGS:STRING="-DTARGET_OS_IPHONE" \
      -DCMAKE_C_FLAGS:STRING="-DTARGET_OS_IPHONE" \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DWITH_SSE2=OFF \
      -DOPENSSL_ROOT_DIR=$(realpath ../../iSSH2/openssl_iphoneos) \
      -DJPEG_LIBRARY=$(realpath ../../libjpeg-turbo/libs_combined_iphoneos/lib) \
      -DJPEG_INCLUDE_DIR=$(realpath ../../libjpeg-turbo/libs_combined_iphoneos/include) \
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
  patch -p1 < ../freerdp_sse_guards.patch

  MACOSX_SDK_DIR=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

  cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
      -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2/openssl_iphoneos) \
      -DUIKIT_FRAMEWORK="${MACOSX_SDK_DIR}/System/iOSSupport/System/Library/Frameworks/UIKit.framework" \
      -DCMAKE_OSX_ARCHITECTURES="x86_64" \
      -DCMAKE_CXX_FLAGS:STRING="-target x86_64-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
      -DCMAKE_C_FLAGS:STRING="-target x86_64-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
      -DCMAKE_IOS_SDK_ROOT=${MACOSX_SDK_DIR} \
      -DWITH_NEON=OFF \
      -DWITH_SSE2=OFF \
      -DOPENSSL_ROOT_DIR=$(realpath ../../iSSH2/openssl_macosx) \
      -DJPEG_LIBRARY=$(realpath ../../libjpeg-turbo/libs_combined_maccatalyst/lib) \
      -DJPEG_INCLUDE_DIR=$(realpath ../../libjpeg-turbo/libs_combined_maccatalyst/include) \
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

if git clone https://github.com/FreeRDP/FreeRDP.git FreeRDP_maccatalyst_arm64
then
# Mac Catalyst build
  pushd FreeRDP_maccatalyst_arm64
  git checkout ${FREERDP_VERSION}

  patch -p1 < ../freerdp_ifreerdp_library.patch
  patch -p1 < ../freerdp_mac_catalyst.patch
  patch -p1 < ../disable_freerdp_context_free.patch
  patch -p1 < ../clipboard-redirection.patch
  patch -p1 < ../freerdp_fix_for_set_format.patch
  patch -p1 < ../freerdp_sse_guards.patch

  MACOSX_SDK_DIR=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

  cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
      -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2/openssl_iphoneos) \
      -DUIKIT_FRAMEWORK="${MACOSX_SDK_DIR}/System/iOSSupport/System/Library/Frameworks/UIKit.framework" \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DCMAKE_CXX_FLAGS:STRING="-target arm64-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
      -DCMAKE_C_FLAGS:STRING="-target arm64-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
      -DCMAKE_IOS_SDK_ROOT=${MACOSX_SDK_DIR} \
      -DWITH_NEON=OFF \
      -DWITH_SSE2=OFF \
      -DOPENSSL_ROOT_DIR=$(realpath ../../iSSH2/openssl_macosx) \
      -DJPEG_LIBRARY=$(realpath ../../libjpeg-turbo/libs_combined_maccatalyst/lib) \
      -DJPEG_INCLUDE_DIR=$(realpath ../../libjpeg-turbo/libs_combined_maccatalyst/include) \
      -DWITH_JPEG=ON \
      -DWITH_FFMPEG=OFF \
      -DWITH_IOSAUDIO=ON \
      -DWITH_ZLIB=ON \
      -DPLATFORM=MAC_CATALYST \
      -G"Unix Makefiles"
  popd
fi
pushd FreeRDP_maccatalyst_arm64
cmake --build . -j 12 -v
popd

# Build library with all architectures
mkdir -p libs_iphoneos
for f in $(find FreeRDP_iphoneos/ -name \*.a | sed 's/FreeRDP_iphoneos\///')
do
  lipo FreeRDP_iphoneos/$f -output libs_iphoneos/$(basename $f) -create
done

mkdir -p libs_maccatalyst
for f in $(find FreeRDP_iphoneos/ -name \*.a | sed 's/FreeRDP_iphoneos\///')
do
  lipo FreeRDP_maccatalyst/$f FreeRDP_maccatalyst_arm64/$f -output libs_maccatalyst/$(basename $f) -create
done

for platform in iphoneos maccatalyst
do
  libtool -static -o duperlib.a libs_$platform/*
  mv duperlib.a ../bVNC.xcodeproj/libs_combined_$platform/lib/

  # Make all include files available to the project
  for d in $(find FreeRDP_maccatalyst/ -name include -type d) FreeRDP_maccatalyst/client/iOS/FreeRDP/ FreeRDP_maccatalyst/client/iOS/Misc/
  do
    rsync -avP $d/ ../bVNC.xcodeproj/libs_combined_$platform/include/
  done
done

