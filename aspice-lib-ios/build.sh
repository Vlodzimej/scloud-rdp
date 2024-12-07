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
#!/bin/bash -e

CERBERO_VERSION=1.24.10
EXPECTED_XCODE_PATH=/Applications/Xcode.app/Contents/Developer
# Use clang from Xcode developer toolchain
export PATH=$EXPECTED_XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin:${PATH}
export SDKROOT="$EXPECTED_XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

if [ ! -d cerbero_iphoneos -o ! -d cerbero_maccatalyst ]
then
  BREW_DEPS="expat perl autoconf libtool gtk-doc python3 cpanm cmake python-setuptools"
  brew install ${BREW_DEPS} || true
  brew unlink ${BREW_DEPS}
  brew link --overwrite ${BREW_DEPS}
  
  cpanm XML::Parser
  if [ "$(xcode-select -p)" != "$EXPECTED_XCODE_PATH" ]
  then
    echo "Need to run xcode-select as root to update Xcode path to $EXPECTED_XCODE_PATH"
    sudo xcode-select -s "$EXPECTED_XCODE_PATH"
  fi
fi

if git clone https://github.com/GStreamer/cerbero.git cerbero_iphoneos
then
  pushd cerbero_iphoneos
  git checkout $CERBERO_VERSION
  patch -p1 < ../cerbero-disable-harfbuzz-docs.patch
  popd
fi

if git clone https://github.com/GStreamer/cerbero.git cerbero_maccatalyst
then
  pushd cerbero_maccatalyst
  git checkout $CERBERO_VERSION
  patch -p1 < ../cerbero-disable-harfbuzz-docs.patch
  patch -p1 < ../cerbero-enable-maccatalyst-config.patch
  patch -p1 < ../cerbero-disable-gst-gl.patch
  patch -p1 < ../cerbero-disable-asm-mac-catalyst.patch
  popd
fi

git config --global protocol.file.allow always

/usr/bin/pip3 install six==1.16.0 pyparsing==2.4.7

echo "Get latest recipes for project"
git clone https://github.com/iiordanov/remote-desktop-clients-cerbero-recipes.git recipes || true
pushd recipes
git pull
popd

for platform in iphoneos maccatalyst
do
  pushd cerbero_$platform
  # Copy all spice recipes in automatically or git clone a repo with them.
  rsync -avP --exclude=.git --exclude='ffmpeg*' ../recipes/ ./recipes/

  # Workaround for missing lib-pthread.la dependency.
  for arch in x86_64 arm64
  do
      mkdir -p build/dist/ios_universal/${arch}/lib/
      ln -sf libz.la build/dist/ios_universal/${arch}/lib/lib-pthread.la
  done

  # NOTE: Projects openh264 and ffmpeg are dependencies for aRDP
  ./cerbero-uninstalled -c config/cross-ios-universal.cbc bootstrap
  ./cerbero-uninstalled -c config/cross-ios-universal.cbc build openh264 ffmpeg spiceglue
  popd
done

for platform in iphoneos maccatalyst
do
  for arch in arm64 x86_64
  do
    # Workaround for missing spiceglue header files. TODO: Move to recipe.
    cp cerbero_$platform/build/sources/ios_universal/$arch/spiceglue-2.2/src/*.h cerbero_$platform/build/dist/ios_universal/include/
    # Workaround for missing spice-client header files. TODO: Move to recipe.
    rsync -a cerbero_$platform/build/dist/ios_universal/$arch/include/spice-client-glib-2.0/ cerbero_$platform/build/dist/ios_universal/include/spice-client-glib-2.0/
  done

  echo "Creating ios_universal_$platform/"
  rsync -a --delete cerbero_$platform/build/dist/ios_universal/ ios_universal_$platform/
  # Cleaning up dynamic and .la files to prevent linking issues if dylib is missing one of the expected architectures (e.g. libavcodec dylib)
  find ios_universal_$platform/ -name \*.dylib -exec rm {} \;
  find ios_universal_$platform/ -name \*.la -exec rm {} \;

  # NOTE: We are using system-provided libiconv.2.tbd, so hence we exclude libiconv.a from the huge library
  deps="$(find ios_universal_$platform/lib -name \*.a ! -name 'libiconv.a')"

  mkdir -p libs_$platform/lib/
  echo libtool -static -o libs_$platform/lib/gigalib.a $deps
  libtool -static -o libs_$platform/lib/gigalib.a $deps

  rsync -a ios_universal_$platform/include/ ios_universal_$platform/lib/glib-2.0/include/ libs_$platform/include/
  rsync -a --delete $(realpath libs_$platform)/ ../bVNC.xcodeproj/ios_universal_$platform/
done
