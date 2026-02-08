#!/bin/sh
# Wrapper that translates arm-none-eabi-gcc invocations to clang.
# System clang has a built-in ARM backend and integrated assembler,
# so we don't need to ship cc1/as (saves ~32MB).
set -e

DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")"
TOOLCHAIN_DIR="$(dirname "$DIR")"
LD_PATH="$TOOLCHAIN_DIR/arm-none-eabi/bin/ld"
LIBGCC_DIR="$TOOLCHAIN_DIR/lib/gcc/arm-none-eabi/13.2.1/thumb/v7e-m+dp/hard"

# Handle --version (used by build system probes)
case "$1" in
  --version|-dumpversion|-dumpmachine)
    exec clang --target=arm-none-eabi "$@"
    ;;
esac

# Translate gcc flags to clang equivalents
args=""
is_linking=true
for arg in "$@"; do
  case "$arg" in
    -c|-S|-E)
      is_linking=false
      args="$args $arg"
      ;;
    -fsingle-precision-constant)
      # gcc-only flag, no clang equivalent; safe to drop for panda firmware
      ;;
    -fmax-errors=*)
      args="$args -ferror-limit=${arg#-fmax-errors=}"
      ;;
    *)
      args="$args $arg"
      ;;
  esac
done

if [ "$is_linking" = true ]; then
  # Libraries must come AFTER objects for left-to-right symbol resolution
  exec clang --target=arm-none-eabi \
    -Wno-unused-command-line-argument \
    --ld-path="$LD_PATH" \
    $args \
    -L"$LIBGCC_DIR" -laeabi_compat -lgcc
else
  exec clang --target=arm-none-eabi \
    -Wno-unused-command-line-argument \
    $args
fi
