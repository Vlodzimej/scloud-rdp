#!/bin/bash
#
# Copyright (C) 2020- Morpheusly Inc.
#
# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this software; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
# USA.
#

set -e

. build-libs.conf

function realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

function usage() {
  echo "$0 [Debug|Release] [clean]"
  exit 1
}

function check_dependencies() {
  if ! which brew
  then
    echo "You need to install brew from https://brew.sh"
    exit 1
  fi
  if ! which cmake
  then
    echo "You must have cmake installed, use 'brew install cmake'"
    exit 1
  fi
  if [ -f /usr/local/bin/nasm ]
  then
    echo "You have nasm installed, you must unlink it. Use 'brew unlink nasm'"
    exit 1
  fi
}

if [ "${1}" == "-h" ]
then
  usage
fi

check_dependencies

TYPE=$1
if [ -z "$TYPE" ]
then
  TYPE=Debug
fi

if [ "${TYPE}" != "Debug" -a "${TYPE}" != "Release" ]
then
  usage
fi

CLEAN=$2
if [ -n "${CLEAN}" ]
then
  rm -rf ios-cmake iSSH2 
  exit 0
fi

function set_up_ios_cmake() {
  if git clone https://github.com/leetal/ios-cmake.git
  then
    pushd ios-cmake
    git checkout ${IOS_CMAKE_VERSION}
    popd
  else
    echo "Found ios-cmake directory, run rm -rf ios-cmake to clone again."
    sleep 2
  fi
}

function build_issh2 {
  mkdir -p ./sCloudRDP.xcodeproj/libs_combined_iphoneos/lib/


  OPENSSL_VERSION=$1
  # Clone and build libssh2
  export CFLAGS=""
  DIR=iSSH2
  if [ -n "$OPENSSL_VERSION" ]
  then
    DIR=iSSH2-$OPENSSL_VERSION
    export LIBSSL_VERSION=$OPENSSL_VERSION
  fi
  if git clone https://github.com/Jan-E/iSSH2.git $DIR
  then
    pushd $DIR
    git checkout ${ISSH2_VERSION}
    echo "libssh2 Mac Catalyst build"
    echo "Patching Jan-E/iSSH2"
    patch -p1 < ../iSSH2.patch
    ./catalyst.sh
    popd
  else
    echo "Found libssh2 directory, assuming it is built, please remove directory $DIR to rebuild"
    sleep 2
  fi

  # Copy SSH libs and header files to project
  rsync -avP $DIR/libssh2_iphoneos/ ./sCloudRDP.xcodeproj/libs_combined_iphoneos/
  rsync -avP $DIR/openssl_iphoneos/ ./sCloudRDP.xcodeproj/libs_combined_iphoneos/
  rsync -avP $DIR/libssh2_macosx/ ./sCloudRDP.xcodeproj/libs_combined_maccatalyst/
  rsync -avP $DIR/openssl_macosx/ ./sCloudRDP.xcodeproj/libs_combined_maccatalyst/
}

function build_libvncserver() {
  local SSL_DIR=$1

  git clone https://github.com/iiordanov/libvncserver.git || true
  pushd libvncserver/
  git pull
  git checkout ${LIBVNCSERVER_VERSION}

  if [ -n "${CLEAN}" ]
  then
    rm -rf build_iphoneos build_maccatalyst_*
  fi

  for arch in arm64 arm64e
  do
    echo 'PRODUCT_BUNDLE_IDENTIFIER = com.scloud.rdp' > ${TYPE}.xcconfig
    if [ ! -d build_iphoneos_${arch} ]
    then
      echo "iPhone build"
      mkdir -p build_iphoneos_${arch}
      pushd build_iphoneos_${arch}
      cmake .. -G"Unix Makefiles" -DARCHS="${arch}" \
          -DCMAKE_TOOLCHAIN_FILE=$(realpath ../../ios-cmake/ios.toolchain.cmake) \
          -DPLATFORM=OS64 \
          -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
          -DDEPLOYMENT_TARGET=13.2 \
          -DENABLE_BITCODE=OFF \
          -DOPENSSL_SSL_LIBRARY=$(realpath ../../$SSL_DIR/openssl_iphoneos/lib/libssl.a) \
          -DOPENSSL_CRYPTO_LIBRARY=$(realpath ../../$SSL_DIR/openssl_iphoneos/lib/libcrypto.a) \
          -DOPENSSL_INCLUDE_DIR=$(realpath ../../$SSL_DIR/openssl_iphoneos/include) \
          -DCMAKE_INSTALL_PREFIX=./libs \
          -DBUILD_SHARED_LIBS=OFF \
          -DENABLE_VISIBILITY=ON \
          -DENABLE_ARC=OFF \
          -DWITH_SASL=OFF \
          -DWITH_LZO=OFF \
          -DLIBVNCSERVER_HAVE_ENDIAN_H=OFF \
          -DWITH_GCRYPT=OFF \
          -DWITH_PNG=OFF \
          -DWITH_EXAMPLES=OFF \
          -DWITH_TESTS=OFF \
          -DWITH_QT=OFF \
      popd
    fi
    pushd build_iphoneos_${arch}
    make -j 12
    make install
    popd
  done

  for arch in arm64 x86_64
  do
    if [ ! -d build_maccatalyst_${arch} ]
    then
      echo "libvncserver Mac Catalyst build"
      mkdir -p build_maccatalyst_${arch}
      pushd build_maccatalyst_${arch}
      cmake .. -G"Unix Makefiles" -DARCHS="${arch}" \
          -DCMAKE_TOOLCHAIN_FILE=$(realpath ../../ios-cmake/ios.toolchain.cmake) \
          -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
          -DPLATFORM=MAC_CATALYST \
          -DDEPLOYMENT_TARGET=13.2 \
          -DCMAKE_CXX_FLAGS_MAC_CATALYST:STRING="-target ${arch}-apple-ios13.2-macabi" \
          -DCMAKE_C_FLAGS_MAC_CATALYST:STRING="-target ${arch}-apple-ios13.2-macabi" \
          -DCMAKE_BUILD_TYPE=MAC_CATALYST \
          -DENABLE_BITCODE=OFF \
          -DOPENSSL_SSL_LIBRARY=$(realpath ../../$SSL_DIR/openssl_macosx/lib/libssl.a) \
          -DOPENSSL_CRYPTO_LIBRARY=$(realpath ../../$SSL_DIR/openssl_macosx/lib/libcrypto.a) \
          -DOPENSSL_INCLUDE_DIR=$(realpath ../../$SSL_DIR/openssl_macosx/include) \
          -DCMAKE_INSTALL_PREFIX=./libs \
          -DBUILD_SHARED_LIBS=OFF \
          -DENABLE_VISIBILITY=ON \
          -DENABLE_ARC=OFF \
          -DWITH_SASL=OFF \
          -DWITH_LZO=OFF \
          -DLIBVNCSERVER_HAVE_ENDIAN_H=OFF \
          -DWITH_GCRYPT=OFF \
          -DWITH_PNG=OFF \
          -DWITH_EXAMPLES=OFF \
          -DWITH_TESTS=OFF \
          -DWITH_QT=OFF \
      popd
    fi
    pushd build_maccatalyst_${arch}
    make -j 12
    make install
    popd
  done
  popd
}

function lipo_libvncserver() {
  pushd libvncserver/
  
  for platform in iphoneos maccatalyst
  do
    # # Lipo together the architectures for libvncserver and copy them to the common directory.
    mkdir -p libs_combined_${platform}
    pushd build_${platform}_arm64 # Using one of the architectures to get lib names
    for lib in lib*.a
    do
      echo "Running lipo for ${lib}"
      mkdir -p ../libs_combined_${platform}/lib/
      lipo ../build_${platform}_*/${lib} -output ../libs_combined_${platform}/lib/${lib} -create
    done
    popd
    echo "Copying include files from one of of the architectures"
    rsync -avPL build_${platform}_arm64/libs/include libs_combined_${platform}/
    # echo "Rsyncing libs_combined_${platform}/ to ../sCloudRDP.xcodeproj/libs_combined_${platform}/"
    # rsync -avPL libs_combined_${platform}/ ../sCloudRDP.xcodeproj/libs_combined_${platform}/
  done
  popd
}

function create_super_lib() {
  # Make a super duper static lib out of all the other libs
  for platform in iphoneos maccatalyst
  do
    pushd sCloudRDP.xcodeproj/libs_combined_${platform}/lib
    /Library/Developer/CommandLineTools/usr/bin//libtool -static -o superlib.a libcrypto.a libssh2.a libssl.a
    popd
  done
}

function build_rdp_dependencies() {
  # Build RDP dependencies
  pushd ardp-lib-ios
  ./build.sh
  popd
}


# Main program start
# set_up_ios_cmake
# build_issh2 "$SSL_VERSION"
# build_libvncserver
# lipo_libvncserver
# create_super_lib
build_rdp_dependencies
