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

package hxluajit;

/**
 * Puts the bionic stdio shim into Android builds that link LuaJIT.
 *
 * `hxluajit` ships prebuilt Android LuaJIT libraries that reference the
 * `stdin`, `stdout` and `stderr` stdio variables. Bionic only exports those
 * from API 23 on (bionic's `libc.map.txt` marks them `introduced=23`) while
 * `project.hxp` pins `android.minimum-sdk-version` to 21, so the Android link
 * fails with:
 *
 * ```text
 * ld.lld: error: undefined symbol: stdout
 * ld.lld: error: undefined symbol: stdin
 * ld.lld: error: undefined symbol: stderr
 * clang++: error: linker command failed with exit code 1
 * ```
 *
 * The fix lives next to the engine's other native helpers:
 * `source/backend/native/src/phoenix_luajit_bionic_stdio.cpp` defines the
 * three variables on top of bionic's `__sF` stream array (available since
 * API 1), which is what an API 23+ `<stdio.h>` would have provided.
 *
 * The class only exists to declare the build file: `source/import.hx` imports
 * it for every `LUA_ALLOWED` build, and `@:keep` makes sure it reaches the
 * generated C++ so hxcpp picks the fragment up (idle classes with
 * `@:buildXml` are dropped by DCE otherwise). The build file's own
 * `<section if="android">` guard keeps the C++ translation unit out of
 * desktop, iOS and web builds.
 *
 * `NO_LUAJIT_BIONIC_STDIO` opts out, in case a future NDK starts exporting
 * the variables itself.
 */
@:keep
@:buildXml('<include name="../../../../source/backend/native/luajit_bionic_stdio_build.xml" />')
class BionicStdio
{
	/** Whether this build exports stdin/stdout/stderr for the Android LuaJIT. */
	public static function isLinked():Bool
	{
		return #if (android && LUA_ALLOWED) true #else false #end;
	}
}
