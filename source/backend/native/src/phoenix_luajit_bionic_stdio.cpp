/*
 * Copyright (C) 2026 Phoenix Engine Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/*
 * LuaJIT's prebuilt Android libraries (hxluajit's
 * `project/luajit/lib/Android/libluajit-*.a`) reference the `stdin`,
 * `stdout` and `stderr` stdio *variables*. Bionic only started exporting
 * those in API 23 (see LIBC's `stderr/stdin/stdout; # var introduced=23`
 * in bionic's libc.map.txt), while this engine supports API 21, so the
 * Android link fails with:
 *
 *     ld.lld: error: undefined symbol: stdout
 *     ld.lld: error: undefined symbol: stdin
 *     ld.lld: error: undefined symbol: stderr
 *     clang++: error: linker command failed with exit code 1
 *
 * Export the three variables here instead, backed by bionic's `__sF` stream
 * array, which has been exported since API 1 as `FILE[3]` = { stdin, stdout,
 * stderr }. That is exactly what the API 23+ libc does
 * (libc/stdio/stdio.cpp):
 *
 *     FILE __sF[3] = { ... };
 *     FILE* stdin  = &__sF[0];
 *     FILE* stdout = &__sF[1];
 *     FILE* stderr = &__sF[2];
 *
 * so LuaJIT's stdio use (lua_writestring()/lua_writeline() in lauxlib.h,
 * which is what a mod's `print()` goes through) keeps working on API 21 and
 * above, writing through the very same FILE the rest of the app uses.
 *
 * The same libraries also call `fseeko64()`/`ftello64()` (LuaJIT's
 * `lib_io.c` implements `file:seek()` with them). Bionic only exports those
 * from **API 24** (`libc.map.txt`: `fseeko64; # introduced=24`), so the shim
 * forwards them to `fseeko()`/`ftello()` - the 32-bit-off_t spellings that
 * have been in libc since API 1. On a 64-bit ABI `off_t` is already 64-bit,
 * so this is exact; on 32-bit it caps `file:seek()` at 2 GiB, which no mod
 * script reaches (and which matches what the API 21 C library offered).
 *
 * Why the guards below look the way they do
 * -----------------------------------------
 * 1. `__ANDROID__` only. Desktop, Emscripten and iOS libcs export the
 *    variables themselves; defining them again would be a duplicate symbol.
 *
 * 2. `__ANDROID_API__ < 23` only. That macro is the NDK's *build* API level,
 *    derived from `android.minimum-sdk-version` (21, see project.hxp). At 23+
 *    bionic exports the three symbols itself, so defining them here would
 *    again be a duplicate.
 *
 * 3. No `LUA_ALLOWED` guard. It used to be here, but hxcpp never forwards
 *    Haxe defines to the C++ preprocessor: `LUA_ALLOWED` only ever reaches
 *    hxcpp's own XML `if=`/`unless=` conditionals (via the generated
 *    Options.txt) and is never a `-D` compiler flag. So `defined(LUA_ALLOWED)`
 *    was always false and the translation unit compiled to nothing, which is
 *    exactly why the link kept failing. Whether Lua is compiled in is decided
 *    in luajit_bionic_stdio_build.xml instead, where `if=` does work.
 *
 * 4. Bionic makes all three names *macros* in both of its branches:
 *
 *        #if __ANDROID_API__ >= 23     // real variables...
 *        extern FILE* stdin __INTRODUCED_IN(23);
 *        #define stdin stdin           // ...but still macros for C/C++
 *        #else                         // API < 23: macros over __sF
 *        extern FILE __sF[] __REMOVED_IN(23, "Use stdin/stdout/stderr");
 *        #define stdin (&__sF[0])
 *        #endif
 *
 *    so `FILE* stdin = ...` would be rewritten into `FILE* (&__sF[0]) = ...`.
 *    The `#undef`s below are therefore mandatory. `__sF` is also declared by
 *    <stdio.h> with C linkage, so it must not be re-declared here.
 *
 * 5. `fseeko64`/`ftello64` are wrapped rather than reimplemented, so the
 *    buffered offsets stay consistent with the FILE they act on.
 *
 * `NO_LUAJIT_BIONIC_STDIO` (a define, or the environment variable of the same
 * name) keeps the translation unit in the build but defines nothing, in case a
 * future NDK starts exporting the variables itself below API 23.
 */
#include "phoenix_luajit_bionic_stdio.h"

#if defined(__ANDROID__) && !defined(NO_LUAJIT_BIONIC_STDIO) && (!defined(__ANDROID_API__) || __ANDROID_API__ < 23)

/* <stdio.h> must come first: it declares `__sF` and macro-izes the streams. */
#include <stdio.h>

#undef stdin
#undef stdout
#undef stderr

/*
 * Bionic tags `__sF` with __REMOVED_IN(23, ...), i.e. a deprecated
 * declaration, so each reference warns -Wdeprecated-declarations. The
 * reference is deliberate (it is the only way to reach the streams at API
 * 21), so silence that single diagnostic around the definitions rather than
 * disabling the check for the whole file.
 */
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#elif defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

/* `__sF` is already declared (C linkage) by <stdio.h> for API < 23. */
#ifdef __cplusplus
extern "C" {
#endif

FILE* stdin = &__sF[0];
FILE* stdout = &__sF[1];
FILE* stderr = &__sF[2];

#ifdef __cplusplus
}
#endif

#if defined(__clang__)
#pragma clang diagnostic pop
#elif defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

/*
 * LuaJIT's lib_io.c links against fseeko64/ftello64, which bionic only exports
 * from API 24. Forward them to the API-1 32-bit-off_t spellings. <stdio.h>
 * declares both shapes, so these definitions must not be declared again.
 */
#ifdef __cplusplus
extern "C" {
#endif

int fseeko64(FILE* stream, off64_t offset, int whence)
{
  return fseeko(stream, (off_t)offset, whence);
}

off64_t ftello64(FILE* stream)
{
  return (off64_t)ftello(stream);
}

#ifdef __cplusplus
}
#endif

int phoenixLuajitBionicStdio(void)
{
  return 1;
}

#else

/*
 * Every other build must define none of the three symbols: desktop/web keep
 * their libc's, API 23+ Android imports bionic's, and
 * NO_LUAJIT_BIONIC_STDIO keeps the build unchanged.
 */
int phoenixLuajitBionicStdio(void)
{
  return 0;
}

#endif /* __ANDROID__ && !NO_LUAJIT_BIONIC_STDIO && __ANDROID_API__ < 23 */
