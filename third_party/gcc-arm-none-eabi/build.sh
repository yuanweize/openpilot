#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

VERSION="13.2.rel1"
TOOLCHAIN_NAME="arm-gnu-toolchain-13.2.rel1"

ARCHNAME="x86_64"
if [ -f /TICI ]; then
  ARCHNAME="larch64"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  ARCHNAME="Darwin"
fi

case "$ARCHNAME" in
  x86_64)
    TARBALL="${TOOLCHAIN_NAME}-x86_64-arm-none-eabi.tar.xz"
    ;;
  larch64)
    TARBALL="${TOOLCHAIN_NAME}-aarch64-arm-none-eabi.tar.xz"
    ;;
  Darwin)
    TARBALL="${TOOLCHAIN_NAME}-darwin-arm64-arm-none-eabi.tar.xz"
    ;;
esac

URL="https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/${TARBALL}"

cd "$DIR"

# Download if not cached
if [ ! -f "$TARBALL" ]; then
  echo "Downloading $TARBALL ..."
  curl -L -o "$TARBALL" "$URL"
fi

# Extract to temp dir
TMPDIR=$(mktemp -d)
echo "Extracting ..."
tar xf "$TARBALL" -C "$TMPDIR"

INSTALL_DIR="$DIR/$ARCHNAME"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# The tarball filename uses lowercase "rel1" but extracts to "Rel1"
SRC="$TMPDIR/$(ls "$TMPDIR")"
GCC_VERSION="13.2.1"
MULTILIB="thumb/v7e-m+dp/hard"

# bin/ - compiler driver + tools that panda/SConscript uses
mkdir -p "$INSTALL_DIR/bin"
for tool in gcc objcopy objdump; do
  cp "$SRC/bin/arm-none-eabi-$tool" "$INSTALL_DIR/bin/"
done

# libexec/gcc/ - compiler backends (cc1, collect2)
mkdir -p "$INSTALL_DIR/libexec/gcc/arm-none-eabi/$GCC_VERSION"
for backend in cc1 collect2; do
  cp "$SRC/libexec/gcc/arm-none-eabi/$GCC_VERSION/$backend" \
     "$INSTALL_DIR/libexec/gcc/arm-none-eabi/$GCC_VERSION/"
done

# lib/gcc/ - only the compiler headers panda actually uses + libgcc.a
# Panda includes only <stdint.h> and <stdbool.h>.
# gcc's stdint.h chains to newlib via #include_next, so we need those few newlib headers too.
GCC_INC="$INSTALL_DIR/lib/gcc/arm-none-eabi/$GCC_VERSION/include"
mkdir -p "$GCC_INC"
for hdr in stdint.h stdint-gcc.h stdbool.h stddef.h stdarg.h limits.h syslimits.h float.h; do
  cp "$SRC/lib/gcc/arm-none-eabi/$GCC_VERSION/include/$hdr" "$GCC_INC/" 2>/dev/null || true
done

mkdir -p "$INSTALL_DIR/lib/gcc/arm-none-eabi/$GCC_VERSION/$MULTILIB"
cp "$SRC/lib/gcc/arm-none-eabi/$GCC_VERSION/$MULTILIB/libgcc.a" \
   "$INSTALL_DIR/lib/gcc/arm-none-eabi/$GCC_VERSION/$MULTILIB/"

# arm-none-eabi/bin/ - assembler/linker that gcc invokes internally
mkdir -p "$INSTALL_DIR/arm-none-eabi/bin"
for tool in as ld; do
  cp "$SRC/arm-none-eabi/bin/$tool" "$INSTALL_DIR/arm-none-eabi/bin/"
done

# Minimal newlib headers needed by gcc's stdint.h (#include_next chain)
NEWLIB_INC="$INSTALL_DIR/arm-none-eabi/include"
mkdir -p "$NEWLIB_INC/machine" "$NEWLIB_INC/sys"
for hdr in stdint.h _newlib_version.h; do
  cp "$SRC/arm-none-eabi/include/$hdr" "$NEWLIB_INC/"
done
cp "$SRC/arm-none-eabi/include/machine/_default_types.h" "$NEWLIB_INC/machine/"
for hdr in features.h _intsup.h _stdint.h; do
  cp "$SRC/arm-none-eabi/include/sys/$hdr" "$NEWLIB_INC/sys/"
done

# Strip debug symbols from host binaries
find "$INSTALL_DIR" -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true

# UPX-compress ELF binaries (self-extracting, ~50ms decompression overhead)
if command -v upx &>/dev/null; then
  UPX=upx
elif [ -f /tmp/upx-4.2.4-amd64_linux/upx ]; then
  UPX=/tmp/upx-4.2.4-amd64_linux/upx
else
  # Download UPX for compression
  UPX_DIR=$(mktemp -d)
  curl -sL https://github.com/upx/upx/releases/download/v4.2.4/upx-4.2.4-amd64_linux.tar.xz \
    | tar xJ -C "$UPX_DIR" --strip-components=1
  UPX="$UPX_DIR/upx"
fi

find "$INSTALL_DIR" -type f -executable -exec "$UPX" --best {} + 2>/dev/null || true

# Cleanup
rm -rf "$TMPDIR"

echo "Installed gcc-arm-none-eabi $VERSION to $INSTALL_DIR"
echo "Verify: $INSTALL_DIR/bin/arm-none-eabi-gcc --version"
