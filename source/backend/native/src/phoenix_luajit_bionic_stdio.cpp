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
 * The prebuilt libraries were built against API 23+, so they cannot be
 * linked into an API 21 app unchanged. Export the three variables here
 * instead, backed by bionic's `__sF` stream array, which has existed since
 * API 1 as `FILE[3]` = { stdin, stdout, stderr }. That is exactly what the
 * API 23+ <stdio.h> does:
 *
 *     extern FILE* const stdin;   // = &__sF[0]
 *     extern FILE* const stdout;  // = &__sF[1]
 *     extern FILE* const stderr;  // = &__sF[2]
 *
 * so LuaJIT's stdio use (lua_writestring()/lua_writeline() in lauxlib.h,
 * which is what a mod's `print()` goes through) keeps working on API 21
 * and above. The definitions are compiled into the app instead of being
 * imported from libc, which is the only difference from a plain API 23+
 * build.
 *
 * Guards:
 *  - `__ANDROID__` only: desktop/Emscripten builds define these variables
 *    in their own libc, and this must never clash with them.
 *  - `LUA_ALLOWED` only: nothing references the variables unless LuaJIT is
 *    linked in (project.hxp adds hxluajit for `LUA_ALLOWED`, and Lime turns
 *    every haxedef into a `-D` for hxcpp), so Android builds without the
 *    Lua VM stay byte-for-byte unchanged.
 *  - `!NO_LUAJIT_BIONIC_STDIO`: an escape hatch in case a future NDK starts
 *    exporting the variables itself.
 */
#include "phoenix_luajit_bionic_stdio.h"

#if defined(__ANDROID__) && defined(LUA_ALLOWED) && !defined(NO_LUAJIT_BIONIC_STDIO)

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/* bionic's stream array: __sF[0] = stdin, __sF[1] = stdout, __sF[2] = stderr. */
extern FILE __sF[];

FILE* stdin = &__sF[0];
FILE* stdout = &__sF[1];
FILE* stderr = &__sF[2];

#ifdef __cplusplus
}
#endif

int phoenixLuajitBionicStdio(void)
{
  return 1;
}

#else

int phoenixLuajitBionicStdio(void)
{
  return 0;
}

#endif /* __ANDROID__ && LUA_ALLOWED && !NO_LUAJIT_BIONIC_STDIO */
