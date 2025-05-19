#!/bin/bash -e

FREERDP_VERSION=0ee17e2f8e49d56ab5b90d5160fa8f87ffc445e0 # Head of stable-2.0 as of 2024-12-03
CMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake
#FREERDP_VERSION=0a6b999c5655d07b5653894b24a840c08838e304
#CMAKE_TOOLCHAIN_FILE=cmake/iOSToolchain.cmake

brew install coreutils cmake

PARALLELISM=16

DEP_BASE_PATH=../aspice-lib-ios/ios_universal
ISSH_DEP_PATH=../iSSH2-1.1.1w
JPEG_DEP_PATH=../libjpeg-turbo

function apply_patches() {
  patch -p1 < ../freerdp_ifreerdp_library.patch
  patch -p1 < ../freerdp_mac_catalyst.patch
  patch -p1 < ../disable_freerdp_context_free.patch
  patch -p1 < ../clipboard-redirection.patch
  patch -p1 < ../freerdp_fix_for_set_format.patch
  patch -p1 < ../freerdp_sse_guards.patch
  patch -p1 < ../freerdp_ios_disconnect_fix.patch
  patch -p1 < ../freerdp_fix_arm64_alignment_issues.patch
}

if git clone https://github.com/FreeRDP/FreeRDP.git FreeRDP_iphoneos
then
  DEP_PATH=${DEP_BASE_PATH}_iphoneos
  pushd FreeRDP_iphoneos
  git checkout ${FREERDP_VERSION}

  apply_patches

  # iOS Build
  export LDFLAGS="-lc++"
  cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../$ISSH_DEP_PATH/openssl_iphoneos) \
      -DOPENSSL_ROOT_DIR=$(realpath ../$ISSH_DEP_PATH/openssl_iphoneos) \
      -DCMAKE_CXX_FLAGS:STRING="-DTARGET_OS_IPHONE" \
      -DCMAKE_C_FLAGS:STRING="-DTARGET_OS_IPHONE" \
      -DCMAKE_LD_FLAGS:STRING="-lc++" \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DPLATFORM=OS64 \
      -DWITH_SSE2=OFF \
      -DWITH_JPEG=OFF \
      -DENABLE_BITCODE=OFF \
      -DWITH_FFMPEG=OFF \
      -G"Unix Makefiles"
  popd
fi

pushd FreeRDP_iphoneos
cmake --build . -j $PARALLELISM -v
popd

# for arch in arm64 x86_64
# do
#   DEP_PATH=${DEP_BASE_PATH}_maccatalyst
#   if git clone https://github.com/FreeRDP/FreeRDP.git FreeRDP_maccatalyst_$arch
#   then
#   # Mac Catalyst build
#     pushd FreeRDP_maccatalyst_$arch
#     git checkout ${FREERDP_VERSION}

#     apply_patches

#     MACOSX_SDK_DIR=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

#     export LDFLAGS="-lc++"
#     cmake -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}" \
#         -DFREERDP_IOS_EXTERNAL_SSL_PATH=$(realpath ../$ISSH_DEP_PATH/openssl_macosx) \
#         -DUIKIT_FRAMEWORK="${MACOSX_SDK_DIR}/System/iOSSupport/System/Library/Frameworks/UIKit.framework" \
#         -DCMAKE_OSX_ARCHITECTURES="$arch" \
#         -DCMAKE_CXX_FLAGS:STRING="-target $arch-apple-ios13.4-macabi -DTARGET_OS_IPHONE -lc++" \
#         -DCMAKE_C_FLAGS:STRING="-target $arch-apple-ios13.4-macabi -DTARGET_OS_IPHONE" \
#         -DCMAKE_IOS_SDK_ROOT=${MACOSX_SDK_DIR} \
#         -DOPENSSL_ROOT_DIR=$(realpath ../$ISSH_DEP_PATH/openssl_macosx) \
#         -DJPEG_LIBRARY=$(realpath ../$JPEG_DEP_PATH/libs_combined_maccatalyst/lib) \
#         -DJPEG_INCLUDE_DIR=$(realpath ../$JPEG_DEP_PATH/libs_combined_maccatalyst/include) \
#         -DCMAKE_PREFIX_PATH=$(realpath ../$DEP_PATH) \
#         -DPLATFORM=MAC_CATALYST \
#         -DWITH_NEON=OFF \
#         -DWITH_SSE2=OFF \
#         -DWITH_JPEG=ON \
#         -DENABLE_BITCODE=OFF \
#         -DWITH_FFMPEG=ON \
#         -DWITH_OPENH264=ON \
#         -DWITH_IOSAUDIO=ON \
#         -DWITH_ZLIB=ON \
#         -G"Unix Makefiles"
#     popd
#   fi
#   pushd FreeRDP_maccatalyst_$arch
#   cmake --build . -j $PARALLELISM -v
#   popd
# done

# Build library with all architectures
mkdir -p libs_iphoneos
for f in $(find FreeRDP_iphoneos/ -name \*.a | sed 's/FreeRDP_iphoneos\///')
do
  lipo FreeRDP_iphoneos/$f -output libs_iphoneos/$(basename $f) -create
done

# mkdir -p libs_maccatalyst
# for f in $(find FreeRDP_iphoneos/ -name \*.a | sed 's/FreeRDP_iphoneos\///')
# do
#   lipo FreeRDP_maccatalyst_*/$f -output libs_maccatalyst/$(basename $f) -create
# done

for platform in iphoneos #maccatalyst
do
  DEP_PATH=${DEP_BASE_PATH}_$platform

  issh_platform="$platform"
  if [ "$platform" == "maccatalyst" ]
  then
    issh_platform="macosx"
  fi
  deps="$JPEG_DEP_PATH/libs_combined_$platform/lib/*.a libs_$platform/* $ISSH_DEP_PATH/openssl_$issh_platform/lib/* $ISSH_DEP_PATH/libssh2_$issh_platform/lib/*"
  /Library/Developer/CommandLineTools/usr/bin//libtool -o duperlib.a $deps
  /Library/Developer/CommandLineTools/usr/bin//libtool -static -o duperlib.a $deps

  # deps="$JPEG_DEP_PATH/libs_combined_$platform/lib/*.a libs_$platform/* $ISSH_DEP_PATH/openssl_$issh_platform/lib/* $ISSH_DEP_PATH/libssh2_$issh_platform/lib/* $DEP_PATH/lib/libav*.a $DEP_PATH/lib/libswresample.a $DEP_PATH/lib/libopenh264.a"
  # echo ar -rc  duperlib.a $deps
  # /Library/Developer/CommandLineTools/usr/bin//libtool -o duperlib.a $deps
  mv duperlib.a ../sCloudRDP.xcodeproj/libs_combined_$platform/lib/

  # Make all include files available to the project
  for d in $(find FreeRDP_iphoneos/ -name include -type d) FreeRDP_iphoneos/client/iOS/FreeRDP/ FreeRDP_iphoneos/client/iOS/Misc/
  do
    rsync -avP $d/ ../sCloudRDP.xcodeproj/libs_combined_$platform/include/
  done
done

