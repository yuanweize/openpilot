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

# We use system clang as the compiler (it has a built-in ARM backend and
# integrated assembler), so we only need binutils (ld, objcopy, objdump)
# and libgcc.a from the ARM toolchain. A wrapper script at
# bin/arm-none-eabi-gcc translates gcc flags to clang equivalents.

# bin/ - objcopy and objdump from the toolchain
mkdir -p "$INSTALL_DIR/bin"
for tool in objcopy objdump; do
  cp "$SRC/bin/arm-none-eabi-$tool" "$INSTALL_DIR/bin/"
done

# arm-none-eabi/bin/ld - linker (invoked by clang via -fuse-ld=)
mkdir -p "$INSTALL_DIR/arm-none-eabi/bin"
cp "$SRC/arm-none-eabi/bin/ld" "$INSTALL_DIR/arm-none-eabi/bin/"

# libgcc.a - ARM runtime intrinsics (__aeabi_* functions) for our multilib
mkdir -p "$INSTALL_DIR/lib/gcc/arm-none-eabi/$GCC_VERSION/$MULTILIB"
cp "$SRC/lib/gcc/arm-none-eabi/$GCC_VERSION/$MULTILIB/libgcc.a" \
   "$INSTALL_DIR/lib/gcc/arm-none-eabi/$GCC_VERSION/$MULTILIB/"

# Build libaeabi_compat.a - AEABI memory helpers that clang emits but
# aren't in libgcc.a (they're normally in newlib's libc which we don't ship)
COMPAT_DIR="$INSTALL_DIR/lib/gcc/arm-none-eabi/$GCC_VERSION/$MULTILIB"
clang --target=arm-none-eabi -mcpu=cortex-m7 -mthumb -mhard-float -mfpu=fpv5-d16 \
  -Os -c "$DIR/aeabi_compat.c" -o "$COMPAT_DIR/aeabi_compat.o"
llvm-ar rcs "$COMPAT_DIR/libaeabi_compat.a" "$COMPAT_DIR/aeabi_compat.o"
rm "$COMPAT_DIR/aeabi_compat.o"

# Install the arm-none-eabi-gcc wrapper script
cp "$DIR/arm-none-eabi-gcc-wrapper.sh" "$INSTALL_DIR/bin/arm-none-eabi-gcc"
chmod +x "$INSTALL_DIR/bin/arm-none-eabi-gcc"

# Strip debug symbols from host binaries
find "$INSTALL_DIR" -type f -executable -not -name "*.sh" -not -name "arm-none-eabi-gcc" \
  -exec strip --strip-unneeded {} + 2>/dev/null || true

# Cleanup
rm -rf "$TMPDIR"

echo "Installed gcc-arm-none-eabi $VERSION to $INSTALL_DIR"
echo "Verify: $INSTALL_DIR/bin/arm-none-eabi-gcc --version"
