#!/bin/bash -e

FREERDP_VERSION=0ee17e2f8e49d56ab5b90d5160fa8f87ffc445e0 # Head of stable-2.0 as of 2024-12-03
CMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake
#FREERDP_VERSION=0a6b999c5655d07b5653894b24a840c08838e304
#CMAKE_TOOLCHAIN_FILE=cmake/iOSToolchain.cmake

brew install coreutils cmake

PARALLELISM=16

export LDFLAGS="-lc++"

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
      -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2-1.1.1w/openssl_iphoneos) \
      -DCMAKE_CXX_FLAGS:STRING="-DTARGET_OS_IPHONE" \
      -DCMAKE_C_FLAGS:STRING="-DTARGET_OS_IPHONE" \
      -DCMAKE_LD_FLAGS:STRING="-lc++" \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DOPENSSL_ROOT_DIR=$(realpath ../../iSSH2-1.1.1w/openssl_iphoneos) \
      -DJPEG_LIBRARY=$(realpath ../../libjpeg-turbo/libs_combined_iphoneos/lib) \
      -DJPEG_INCLUDE_DIR=$(realpath ../../libjpeg-turbo/libs_combined_iphoneos/include) \
      -DCMAKE_PREFIX_PATH=$(realpath ../../aspice-lib-ios/cerbero_iphoneos/build/dist/ios_universal) \
      -DPLATFORM=OS64 \
      -DWITH_SSE2=OFF \
      -DWITH_JPEG=ON \
      -DENABLE_BITCODE=OFF \
      -DWITH_FFMPEG=ON \
      -DWITH_OPENH264=ON \
      -DWITH_IOSAUDIO=ON \
      -DWITH_ZLIB=ON \
      -G"Unix Makefiles"
  popd
fi

pushd FreeRDP_iphoneos
cmake --build . -j $PARALLELISM -v
popd

for arch in arm64 x86_64
do
  if git clone https://github.com/FreeRDP/FreeRDP.git FreeRDP_maccatalyst_$arch
  then
  # Mac Catalyst build
    pushd FreeRDP_maccatalyst_$arch
    git checkout ${FREERDP_VERSION}

    patch -p1 < ../freerdp_ifreerdp_library.patch
    patch -p1 < ../freerdp_mac_catalyst.patch
    patch -p1 < ../disable_freerdp_context_free.patch
    patch -p1 < ../clipboard-redirection.patch
    patch -p1 < ../freerdp_fix_for_set_format.patch
    patch -p1 < ../freerdp_sse_guards.patch

    MACOSX_SDK_DIR=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

    cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
        -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../../iSSH2-1.1.1w/openssl_macosx) \
        -DUIKIT_FRAMEWORK="${MACOSX_SDK_DIR}/System/iOSSupport/System/Library/Frameworks/UIKit.framework" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_CXX_FLAGS:STRING="-target $arch-apple-ios13.4-macabi -DTARGET_OS_IPHONE -lc++" \
        -DCMAKE_C_FLAGS:STRING="-target $arch-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
        -DCMAKE_IOS_SDK_ROOT=${MACOSX_SDK_DIR} \
        -DOPENSSL_ROOT_DIR=$(realpath ../../iSSH2-1.1.1w/openssl_macosx) \
        -DJPEG_LIBRARY=$(realpath ../../libjpeg-turbo/libs_combined_maccatalyst/lib) \
        -DJPEG_INCLUDE_DIR=$(realpath ../../libjpeg-turbo/libs_combined_maccatalyst/include) \
        -DCMAKE_PREFIX_PATH=$(realpath ../../aspice-lib-ios/cerbero_maccatalyst/build/dist/ios_universal) \
        -DPLATFORM=MAC_CATALYST \
        -DWITH_NEON=OFF \
        -DWITH_SSE2=OFF \
        -DWITH_JPEG=ON \
        -DENABLE_BITCODE=OFF \
        -DWITH_FFMPEG=ON \
        -DWITH_OPENH264=ON \
        -DWITH_IOSAUDIO=ON \
        -DWITH_ZLIB=ON \
        -G"Unix Makefiles"
    popd
  fi
  pushd FreeRDP_maccatalyst_$arch
  cmake --build . -j $PARALLELISM -v
  popd
done

# Build library with all architectures
mkdir -p libs_iphoneos
for f in $(find FreeRDP_iphoneos/ -name \*.a | sed 's/FreeRDP_iphoneos\///')
do
  lipo FreeRDP_iphoneos/$f -output libs_iphoneos/$(basename $f) -create
done

mkdir -p libs_maccatalyst
for f in $(find FreeRDP_iphoneos/ -name \*.a | sed 's/FreeRDP_iphoneos\///')
do
  lipo FreeRDP_maccatalyst_*/$f -output libs_maccatalyst/$(basename $f) -create
done

for platform in iphoneos maccatalyst
do
  issh_platform="$platform"
  if [ "$platform" == "maccatalyst" ]
  then
    issh_platform="macosx"
  fi
  deps="libs_$platform/* ../iSSH2-1.1.1w/openssl_$issh_platform/lib/* ../iSSH2-1.1.1w/libssh2_$issh_platform/lib/* ../aspice-lib-ios/cerbero_$platform/build/dist/ios_universal/lib/libav*.a ../aspice-lib-ios/cerbero_$platform/build/dist/ios_universal/lib/libswresample.a ../aspice-lib-ios/cerbero_$platform/build/dist/ios_universal/lib/libopenh264.a"
  echo libtool -static -o duperlib.a $deps
  libtool -static -o duperlib.a $deps
  mv duperlib.a ../bVNC.xcodeproj/libs_combined_$platform/lib/

  # Make all include files available to the project
  for d in $(find FreeRDP_iphoneos/ -name include -type d) FreeRDP_iphoneos/client/iOS/FreeRDP/ FreeRDP_iphoneos/client/iOS/Misc/
  do
    rsync -avP $d/ ../bVNC.xcodeproj/libs_combined_$platform/include/
  done
done

