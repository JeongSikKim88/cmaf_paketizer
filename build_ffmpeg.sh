#!/bin/bash

yum groupinstall 'Development Tools' -y

yum -y install \
  autoconf \
  automake \
  bzip2 \
  bzip2-devel \
  cmake \
  freetype-devel \
  gcc \
  gcc-c++ \
  git \
  libtool \
  make \
  mercurial \
  pkgconfig \
  zlib-devel

PACKAGES="$HOME/ffmpeg_sources"
WORKSPACE="$HOME/ffmpeg_build"

# Create a dir where the rest of the sources will live
mkdir -p ~/ffmpeg_sources ~/bin

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
if [[ -n $NUMJOBS ]]; then
    MJOBS=$NUMJOBS
elif [[ -f /proc/cpuinfo ]]; then
    MJOBS=$(grep -c processor /proc/cpuinfo)
elif [[ "$OSTYPE" == "darwin"* ]]; then
	MJOBS=$(sysctl -n machdep.cpu.thread_count)
else
    MJOBS=4
fi


echo "Using $MJOBS make jobs simultaneously."

######### nasm ##########
cd ~/ffmpeg_sources && \
curl -O -L https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2 && \
tar xjvf nasm-2.14.02.tar.bz2 && \
cd nasm-2.14.02 && \
./autogen.sh && \
PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
make -j$MJOBS && \
make install

######### yasm ##########
cd ~/ffmpeg_sources && \
curl -O -L https://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz && \
tar xzvf yasm-1.3.0.tar.gz && \
cd yasm-1.3.0 && \
./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
make -j$MJOBS && \
make install

###### libx264 ########
cd ~/ffmpeg_sources && \
git clone --depth 1 https://code.videolan.org/videolan/x264.git && \
cd x264 && \
PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --enable-static && \
make -j$MJOBS && \
make install

###### libx265 #######
cd ~/ffmpeg_sources && \
hg clone https://bitbucket.org/multicoreware/x265 && \
cd x265/build/linux && \
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED:bool=off ../../source && \
make -j$MJOBS && \
make install

###### libfdk-aac ########
cd ~/ffmpeg_sources && \
git -C fdk-aac pull 2> /dev/null || git clone --depth 1 https://github.com/mstorsjo/fdk-aac && \
cd fdk-aac && \
autoreconf -fiv && \
./configure --prefix="$HOME/ffmpeg_build" --disable-shared && \
make -j$MJOBS && \
make install

####### libmp3lame ########
cd ~/ffmpeg_sources && \
curl -O -L https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz && \
tar xzvf lame-3.100.tar.gz && \
cd lame-3.100 && \
./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --disable-shared --enable-nasm && \
make -j$MJOBS && \
make install

######### libopus #########
cd ~/ffmpeg_sources && \
curl -O -L https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz && \
tar xzvf opus-1.3.1.tar.gz && \
cd opus-1.3.1 && \
./configure --prefix="$HOME/ffmpeg_build" --disable-shared && \
make -j$MJOBS && \
make install

####### libvpx #########
cd ~/ffmpeg_sources && \
git -C libvpx pull 2> /dev/null || git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
cd libvpx && \
./configure --prefix="$HOME/ffmpeg_build" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm && \
make -j$MJOBS && \
make install

######## Finally install ffmpeg #########
cd ~/ffmpeg_sources && \
curl -O -L https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
tar xjvf ffmpeg-snapshot.tar.bz2 && \
cd ffmpeg && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --extra-libs=-lpthread \
  --extra-libs=-lm \
  --bindir="$HOME/bin" \
  --enable-gpl \
  --enable-libfdk_aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-nonfree && \
PATH="$HOME/bin:$PATH" make -j$MJOBS && \
make install && \
hash -r

INSTALL_FOLDER="/usr/bin"
if [[ "$OSTYPE" == "darwin"* ]]; then
INSTALL_FOLDER="/usr/local/bin"
fi

echo ""
echo "Building done. The binary can be found here: $WORKSPACE/bin/ffmpeg"
echo ""

sudo cp "$HOME/bin/ffmpeg" "$INSTALL_FOLDER/ffmpeg"
sudo cp "$HOME/bin/ffprobe" "$INSTALL_FOLDER/ffprobe"

echo ""
echo "The binary copy here: $INSTALL_FOLDER/bin/ffmpeg"
echo ""

exit 0
