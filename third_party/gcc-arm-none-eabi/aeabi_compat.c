// AEABI memory helper functions that clang's ARM codegen emits for
// struct copies/zeroing. GCC puts these in libc (newlib), but since panda
// uses -nostdlib we provide minimal implementations here.
// These are linked automatically by the arm-none-eabi-gcc wrapper.

typedef unsigned int size_t;

void __aeabi_memcpy(void *dest, const void *src, size_t n) {
  unsigned char *d = dest;
  const unsigned char *s = src;
  while (n--) *d++ = *s++;
}

void __aeabi_memcpy4(void *dest, const void *src, size_t n) {
  __aeabi_memcpy(dest, src, n);
}

void __aeabi_memcpy8(void *dest, const void *src, size_t n) {
  __aeabi_memcpy(dest, src, n);
}

void __aeabi_memclr(void *dest, size_t n) {
  unsigned char *d = dest;
  while (n--) *d++ = 0;
}

void __aeabi_memclr4(void *dest, size_t n) {
  __aeabi_memclr(dest, n);
}

void __aeabi_memclr8(void *dest, size_t n) {
  __aeabi_memclr(dest, n);
}

void __aeabi_memset(void *dest, size_t n, int c) {
  unsigned char *d = dest;
  while (n--) *d++ = (unsigned char)c;
}

void __aeabi_memset4(void *dest, size_t n, int c) {
  __aeabi_memset(dest, n, c);
}

void __aeabi_memset8(void *dest, size_t n, int c) {
  __aeabi_memset(dest, n, c);
}

void __aeabi_memmove(void *dest, const void *src, size_t n) {
  unsigned char *d = dest;
  const unsigned char *s = src;
  if (d < s) {
    while (n--) *d++ = *s++;
  } else {
    d += n; s += n;
    while (n--) *--d = *--s;
  }
}

void __aeabi_memmove4(void *dest, const void *src, size_t n) {
  __aeabi_memmove(dest, src, n);
}

void __aeabi_memmove8(void *dest, const void *src, size_t n) {
  __aeabi_memmove(dest, src, n);
}
