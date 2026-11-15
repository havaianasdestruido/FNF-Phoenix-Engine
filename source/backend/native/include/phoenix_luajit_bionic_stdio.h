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
 * Declarations for the bionic stdio shim that lets the API 21 Android link
 * satisfy LuaJIT's references to `stdin`/`stdout`/`stderr`.
 *
 * Nothing calls these functions; they exist so the translation unit has a
 * header to share with the tests, and so the reason for the file is visible
 * from the include folder. See src/phoenix_luajit_bionic_stdio.cpp for the
 * full explanation, and source/hxluajit/BionicStdio.hx for the include that
 * gets the translation unit into the build.
 *
 * The behavior is compile-time: the definitions land in the binary whenever
 * `__ANDROID__ && LUA_ALLOWED` is set (see the .cpp). `phoenixLuajitBionicStdio()`
 * reports whether that happened, which the C++ smoke test asserts.
 */
#ifndef PHOENIX_LUAJIT_BIONIC_STDIO_H
#define PHOENIX_LUAJIT_BIONIC_STDIO_H

#ifdef __cplusplus
extern "C" {
#endif

/** 1 when this build exports stdin/stdout/stderr for LuaJIT, 0 otherwise. */
int phoenixLuajitBionicStdio(void);

#ifdef __cplusplus
}
#endif

#endif /* PHOENIX_LUAJIT_BIONIC_STDIO_H */
