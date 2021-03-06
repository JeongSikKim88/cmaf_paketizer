#!/bin/bash

sudo apt-get update && upgrade -y
sudo apt-get update -qq && sudo apt-get -y install \
  autoconf \
  automake \
  build-essential \
  cmake \
  git-core \
  libass-dev \
  libfreetype6-dev \
  libsdl2-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvorbis-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev \
  pkg-config \
  texinfo \
  wget \
  zlib1g-dev \
  libssl-dev

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

source ~/.profile

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
wget https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2 && \
tar xjvf nasm-2.14.02.tar.bz2 && \
cd nasm-2.14.02 && \
./autogen.sh && \
PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
make -j$MJOBS && \
make install

######### yasm ##########
cd ~/ffmpeg_sources && \
wget -O yasm-1.3.0.tar.gz https://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz && \
tar xzvf yasm-1.3.0.tar.gz && \
cd yasm-1.3.0 && \
./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
make -j$MJOBS && \
make install

###### libx264 ########
cd ~/ffmpeg_sources && \
git -C x264 pull 2> /dev/null || git clone --depth 1 https://git.videolan.org/git/x264.git && \
cd x264 && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --enable-static --enable-pic && \
PATH="$HOME/bin:$PATH" make -j$MJOBS && \
make install

###### libx265 #######
sudo apt-get install -y mercurial libnuma-dev && \
cd ~/ffmpeg_sources && \
if cd x265 2> /dev/null; then hg pull && hg update; else hg clone https://bitbucket.org/multicoreware/x265; fi && \
cd x265/build/linux && \
PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off ../../source && \
PATH="$HOME/bin:$PATH" make -j$MJOBS && \
make install

##### libvpx #####
cd ~/ffmpeg_sources && \
git -C libvpx pull 2> /dev/null || git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
cd libvpx && \
PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm && \
PATH="$HOME/bin:$PATH" make -j$MJOBS && \
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
wget -O lame-3.100.tar.gz https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz && \
tar xzvf lame-3.100.tar.gz && \
cd lame-3.100 && \
PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --disable-shared --enable-nasm && \
PATH="$HOME/bin:$PATH" make -j$MJOBS && \
make install

######### libopus #########
cd ~/ffmpeg_sources && \
git -C opus pull 2> /dev/null || git clone --depth 1 https://github.com/xiph/opus.git && \
cd opus && \
./autogen.sh && \
./configure --prefix="$HOME/ffmpeg_build" --disable-shared && \
make -j$MJOBS && \
make install

######### libaom #########
cd ~/ffmpeg_sources && \
git -C aom pull 2> /dev/null || git clone --depth 1 https://aomedia.googlesource.com/aom && \
mkdir -p aom_build && \
cd aom_build && \
PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off -DENABLE_NASM=on ../aom && \
PATH="$HOME/bin:$PATH" make -j$MJOBS && \
make install

####### libvpx #########
cd ~/ffmpeg_sources && \
git -C libvpx pull 2> /dev/null || git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
cd libvpx && \
PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm && \
PATH="$HOME/bin:$PATH" make -j$MJOBS && \
make install


####### librav1e #######
cd ~/ffmpeg_sources && \
wget https://github.com/xiph/rav1e/archive/v0.3.1.tar.gz && \
tar xvf v0.3.1.tar.gz && cd rav1e-0.3.1 && \
cargo build --release && \
find target -name rav1e -exec install -m 755 {} $HOME/bin \; && \
strip ~/bin/rav1e && \
cargo install cargo -c && \
cd ~/ffmpeg_sources/rav1e-0.3.1 && 
cargo cinstall --release \
--prefix=$HOME/ffmpeg_build \
--libdir=$HOME/ffmpeg_build/lib \
--includedir=$HOME/ffmpeg_build/include

rm -v $HOME/ffmpeg_build/lib/librav1e.so*


######## Finally install ffmpeg #########
cd ~/ffmpeg_sources && \
git -C ffmpeg pull 2> /dev/null || git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg && \
cd ffmpeg && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --extra-libs="-lpthread -lm" \
  --bindir="$HOME/bin" \
  --enable-static \
  --enable-gpl \
  --enable-libaom \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-librav1e \
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
