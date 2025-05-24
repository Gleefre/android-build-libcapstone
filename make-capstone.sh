#!/bin/sh
set -e

# Download source
major_version=5
version=5.0.6
ext=zip
if [ ! -f $version.$ext ]; then
    wget https://github.com/capstone-engine/capstone/archive/refs/tags/$version.$ext
fi
# Clean old folders if they exist
rm -rf capstone
rm -rf capstone-$version
# Unpack
unzip $version.$ext > /dev/null
mv capstone-$version capstone
# Fix soname with patch
patch -p1 < soname-fix.patch

# Configure NDK.

if [ -z $NDK ]; then
    echo "Please set NDK path variable." && exit 1
fi

if [ -z $ABI ]; then
    echo "Running adb to determine target ABI..."
    ABI=`adb shell uname -m`
    echo $ABI
fi
case $ABI in
    arm64 | aarch64) ABI=arm64-v8a ;;
    arm) ABI=armeabi-v7a ;;
    x86-64) ABI=x86_64 ;;
esac
case $ABI in
    arm64-v8a) TARGET=aarch64-linux-android ;;
    armeabi-v7a) TARGET=armv7a-linux-androideabi ;;
    x86) TARGET=i686-linux-android ;;
    x86_64) TARGET=x86_64-linux-android ;;
    all)
        ABI=arm64-v8a ./make-capstone.sh
        ABI=armeabi-v7a ./make-capstone.sh
        ABI=x86 ./make-capstone.sh
        ABI=x86_64 ./make-capstone.sh
        echo "Done."
        exit 0 ;;
    *) echo "Unsupported CPU ABI" && exit 1 ;;
esac

case `uname` in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) echo "Unsupported OS" && exit 1 ;;
esac
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/$os-x86_64

if [ -z $API ]; then
    echo "Android API not set. Using 21 by default."
    API=21
fi


export AR=$TOOLCHAIN/bin/llvm-ar
export CC=$TOOLCHAIN/bin/$TARGET$API-clang
export AS=$CC
export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
export LD=$TOOLCHAIN/bin/ld.lld
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip
export NM=$TOOLCHAIN/bin/llvm-nm
export OBJDUMP=$TOOLCHAIN/bin/llvm-objdump
export DLLTOOL=$TOOLCHAIN/bin/llvm-dlltool


(
cd capstone ;
make libcapstone.so.$major_version ;
)

# Copy shared library
mkdir -p lib/$ABI
cp capstone/libcapstone.so.$major_version lib/$ABI/libcapstone.so
# ...and headers
mkdir -p headers
cp capstone/include/capstone/*.h headers
