#!/usr/bin/env python3
"""Native checks for the META_HORROR desktop capture.

`MetaHorror.hx` keeps its C++ in `@:functionCode` strings, which no Haxe
compiler can check on a Linux CI box. This test extracts the real source of
`captureDesktopToBmpNative` out of the Haxe file, builds it against a small
Win32 mock, runs it and parses the resulting BMP. That catches the mistakes
static greps miss: a bad header, an unpacked BITMAPFILEHEADER, wrong row
padding or an alpha byte leaking into a 24-bit image.

Run:  python3 tests/test_meta_horror_native.py -v
Set PHOENIX_WINDOWS_CXX to a Windows-targeting compiler to cross-compile the
real Win32 path too (x86_64-w64-mingw32-g++).
"""
from __future__ import annotations

import os
import re
import shutil
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "source/backend/MetaHorror.hx"
HEADER = ROOT / "source/backend/native/include/phoenix_meta_horror.h"

MOCK_HEADER = r"""
#ifndef PHOENIX_MH_MOCK_H
#define PHOENIX_MH_MOCK_H
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>

typedef void *HDC; typedef void *HBITMAP; typedef void *HGDIOBJ;
typedef int BOOL; typedef unsigned char BYTE; typedef unsigned short WORD;
typedef unsigned int DWORD; typedef unsigned int UINT; typedef wchar_t WCHAR;

#pragma pack(push, 2)
struct BITMAPFILEHEADER
{
  WORD bfType; DWORD bfSize; WORD bfReserved1; WORD bfReserved2; DWORD bfOffBits;
};
#pragma pack(pop)
static_assert(sizeof(BITMAPFILEHEADER) == 14, "packed 14-byte file header");
struct BITMAPINFOHEADER
{
  DWORD biSize; int biWidth; int biHeight; WORD biPlanes; WORD biBitCount;
  DWORD biCompression; DWORD biSizeImage; DWORD biXPelsPerMeter;
  DWORD biYPelsPerMeter; DWORD biClrUsed; DWORD biClrImportant;
};
static_assert(sizeof(BITMAPINFOHEADER) == 40, "40-byte info header");
struct BITMAPINFO { BITMAPINFOHEADER bmiHeader; };

#ifndef NULL
#define NULL 0
#endif
#define BI_RGB 0
#define DIB_RGB_COLORS 0
#define SRCCOPY 0x00CC0020
#define CAPTUREBLT 0x40000000
#define CP_UTF8 65001
#define MB_ERR_INVALID_CHARS 8
#define SM_XVIRTUALSCREEN 76
#define SM_YVIRTUALSCREEN 77
#define SM_CXVIRTUALSCREEN 78
#define SM_CYVIRTUALSCREEN 79

static const int kWidth = 5;
static const int kHeight = 3;
/* Every mock pixel is BGRA = AA BB CC 00, alpha deliberately zero. */
static const BYTE kBlue = 0xAA, kGreen = 0xBB, kRed = 0xCC;

inline int GetSystemMetrics(int index)
{
  if (index == SM_CXVIRTUALSCREEN) return kWidth;
  if (index == SM_CYVIRTUALSCREEN) return kHeight;
  if (index == SM_XVIRTUALSCREEN) return -100; /* secondary monitor left of primary */
  if (index == SM_YVIRTUALSCREEN) return 0;
  return 0;
}
inline int MultiByteToWideChar(UINT, DWORD, const char *text, int, WCHAR *out, int cap)
{
  if (text == NULL) return 0;
  int length = (int)strlen(text) + 1;
  if (cap == 0) return length;
  if (cap < length) return 0;
  for (int i = 0; i < length; i++) out[i] = (WCHAR)text[i];
  return length;
}
inline int WideCharToMultiByte(UINT, DWORD, const WCHAR *text, int, char *out, int cap, const char *, BOOL *)
{
  if (text == NULL) return 0;
  int length = 0;
  while (text[length] != 0) length++;
  length++;
  if (cap == 0) return length;
  if (cap < length) return 0;
  for (int i = 0; i < length; i++) out[i] = (char)text[i];
  return length;
}
inline HDC GetDC(void *) { return (HDC)1; }
static std::vector<BYTE> gPixels;
inline HBITMAP CreateDIBSection(HDC, BITMAPINFO *info, DWORD, void **bits, void *, DWORD)
{
  const size_t size = (size_t)info->bmiHeader.biWidth * (size_t)info->bmiHeader.biHeight * 4;
  gPixels.assign(size, 0);
  for (size_t i = 0; i < size; i += 4)
  {
    gPixels[i] = kBlue; gPixels[i + 1] = kGreen; gPixels[i + 2] = kRed; gPixels[i + 3] = 0;
  }
  *bits = gPixels.data();
  return (HBITMAP)2;
}
inline HDC CreateCompatibleDC(HDC) { return (HDC)3; }
inline HGDIOBJ SelectObject(HDC, HGDIOBJ) { return 0; }
inline BOOL BitBlt(HDC, int, int, int, int, HDC, int, int, DWORD) { return 1; }
inline BOOL DeleteDC(HDC) { return 1; }
inline BOOL DeleteObject(HBITMAP) { return 1; }
inline int ReleaseDC(void *, HDC) { return 1; }
#endif
"""

HARNESS = r"""
#include "mock.h"
#include <string>

static std::string gPath;
/* Stand-in for hxcpp's String: only wchar_str() is used by the helper. */
struct MockString
{
  const char *c_str() const { return gPath.c_str(); }
  /* hxcpp's String converts implicitly to std::string, which is what the
   * header's UTF-8 helpers take. */
  operator std::string() const { return gPath; }
};
#define path MockString()
/* The header converts hxcpp's UTF-8 path to UTF-16 before opening it. */
static inline std::wstring phoenixMetaUtf8ToWide(const std::string &text)
{
  std::wstring wide(text.begin(), text.end());
  return wide;
}
#define _wfopen(p, mode) mock_wfopen(p, mode)
static inline FILE *mock_wfopen(const wchar_t *widePath, const wchar_t *)
{
  std::string narrow;
  for (size_t i = 0; widePath[i] != 0; i++) narrow += (char)widePath[i];
  return fopen(narrow.c_str(), "wb");
}
#include <string>

static bool captureDesktopToBmpNative_impl()
{
#include "capture.inc"
}

#undef path
#undef _wfopen

int main(int argc, char **argv)
{
  if (argc < 2) return 2;
  gPath = argv[1];
  return captureDesktopToBmpNative_impl() ? 0 : 1;
}
"""


def compiler() -> str | None:
    return shutil.which("c++") or shutil.which("g++") or shutil.which("clang++")


def body(source: str, signature: str) -> str:
    """The brace-delimited body of the first definition matching `signature`."""
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 0
    for i in range(brace, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : i]
    raise AssertionError(f"unbalanced braces after {signature!r}")


def extract_capture_body() -> str:
    """The body of `phoenixMetaCaptureDesktopToBmp` from the native header."""
    source = HEADER.read_text(encoding="utf-8")
    signature = "static PHOENIX_META_UNUSED bool phoenixMetaCaptureDesktopToBmp("
    return body(source, "phoenixMetaCaptureDesktopToBmp(")


class CaptureBmpTests(unittest.TestCase):
    def setUp(self):
        if not compiler():
            self.skipTest("no C++ compiler available")
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        (self.root / "mock.h").write_text(MOCK_HEADER)
        (self.root / "capture.inc").write_text(extract_capture_body())
        (self.root / "main.cpp").write_text(HARNESS)
        self.binary = self.root / "capture"
        subprocess.run(
            [compiler(), "-std=c++11", "-Wall", "-Wextra", "-Werror",
             "-I", str(self.root), str(self.root / "main.cpp"), "-o", str(self.binary)],
            check=True, capture_output=True, text=True,
        )

    def tearDown(self):
        self.directory.cleanup()

    def run_capture(self) -> bytes:
        output = self.root / "shot.bmp"
        subprocess.run([str(self.binary), str(output)], check=True, capture_output=True, text=True)
        self.assertTrue(output.exists(), "the capture produced no file")
        return output.read_bytes()

    def test_writes_a_well_formed_24bit_bmp(self):
        data = self.run_capture()
        self.assertEqual(b"BM", data[:2], "missing the BMP magic")
        declared = struct.unpack("<I", data[2:6])[0]
        offset = struct.unpack("<I", data[10:14])[0]
        header_size, width, height, planes, bits, compression = struct.unpack("<IiiHHI", data[14:34])

        self.assertEqual(declared, len(data), "bfSize must describe the whole file")
        self.assertEqual(header_size, 40)
        self.assertEqual(offset, 14 + 40, "no palette, so pixels start after both headers")
        self.assertEqual((width, height), (5, 3))
        self.assertEqual(planes, 1)
        self.assertEqual((bits, compression), (24, 0), "24-bit BI_RGB")

        row = width * 3
        padding = (4 - row % 4) % 4
        self.assertEqual(offset + (row + padding) * height, len(data), "rows must be padded to 4 bytes")

    def test_keeps_bgr_and_drops_the_zero_alpha(self):
        data = self.run_capture()
        offset = struct.unpack("<I", data[10:14])[0]
        width = struct.unpack("<i", data[18:22])[0]
        self.assertEqual(data[offset : offset + 3], bytes([0xAA, 0xBB, 0xCC]),
                         "BGRA -> BGR, alpha dropped (0 would read as transparent)")

        row = width * 3
        padding = (4 - row % 4) % 4
        self.assertTrue(all(b == 0 for b in data[offset + row : offset + row + padding]),
                        "row padding must be zeroed")

    def test_every_row_is_written(self):
        data = self.run_capture()
        offset = struct.unpack("<I", data[10:14])[0]
        width, height = struct.unpack("<ii", data[18:26])
        row = width * 3
        stride = row + (4 - row % 4) % 4
        rows = {data[offset + i * stride : offset + i * stride + row] for i in range(height)}
        self.assertEqual(len(rows), 1, "the capture should have written every row")
        self.assertEqual(len(rows.pop()), row)

    def test_multi_monitor_origin_is_read(self):
        # The helper must ask for the virtual-screen origin, not assume 0,0:
        # a monitor left of the primary one has a negative x.
        source = extract_capture_body()
        self.assertIn("SM_XVIRTUALSCREEN", source)
        self.assertIn("SM_YVIRTUALSCREEN", source)
        self.assertIn("SM_CXVIRTUALSCREEN", source)
        self.assertIn("SM_CYVIRTUALSCREEN", source)

    def test_releases_gdi_resources_on_every_exit(self):
        source = extract_capture_body()
        self.assertEqual(source.count("CreateDIBSection"), 1)
        self.assertGreaterEqual(source.count("DeleteObject(dib)"), 3,
                                "each failure path and the success path release the DIB")
        # The screen DC is released on both the early bail-out and the success path.
        self.assertGreaterEqual(source.count("ReleaseDC(NULL, screen)"), 2)
        self.assertEqual(source.count("fclose(file)"), 1)


class HeaderCompileTests(unittest.TestCase):
    """The header must be self-sufficient for a translation unit that includes it.

    On Windows the generated `MetaHorror.cpp` gets the header injected through
    `@:cppFileCode`; here the same translation unit is built against the Win32
    test double, which catches missing includes, undeclared helpers and
    signature drift before CI does.
    """

    def test_header_compiles_and_every_helper_runs(self):
        compiler = shutil.which("c++") or shutil.which("g++")
        if not compiler:
            self.skipTest("no C++ compiler available")
        mock = ROOT / "tests" / "native" / "windows"
        include = ROOT / "source" / "backend" / "native" / "include"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            # Two translation units verify the header-only (static) linkage,
            # which hxcpp requires because it includes native metadata twice.
            (root / "other.cpp").write_text(
                '#include <windows.h>\n#include "phoenix_meta_horror.h"\n'
                'double otherUptime() { return phoenixMetaSystemUptime(); }\n'
            )
            source = (ROOT / "tests" / "native" / "test_meta_horror_header.cpp").read_text()
            source = source.replace("int main()", "extern double otherUptime();\nint main()")
            (root / "main.cpp").write_text(source)
            binary = root / "meta-horror-header"
            subprocess.run(
                [compiler, "-std=c++11", "-Wall", "-Wextra", "-Werror", "-D_WIN32",
                 "-I", str(mock), "-I", str(include),
                 str(root / "main.cpp"), str(root / "other.cpp"), "-o", str(binary)],
                check=True, capture_output=True, text=True,
            )
            subprocess.run([str(binary)], check=True, capture_output=True, text=True)

    def test_minGW_style_wfopen_is_available(self):
        """`_wfopen` is used by the capture; the SDK must provide it."""
        header = HEADER.read_text(encoding="utf-8")
        self.assertIn("_wfopen", header)
        mock = (ROOT / "tests" / "native" / "windows" / "windows.h").read_text(encoding="utf-8")
        self.assertIn("_wfopen", mock, "the Win32 test double must declare _wfopen")


class CrossCompileTests(unittest.TestCase):
    def test_real_windows_header_compiles(self):
        target = os.environ.get("PHOENIX_WINDOWS_CXX")
        if not target:
            self.skipTest("PHOENIX_WINDOWS_CXX is not set")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "capture.cpp").write_text(
                '#include <windows.h>\n#include <cstdio>\n#include <cstring>\n#include <string>\n'
                '#include <vector>\n'
                'static bool captureDesktopToBmpNative(const std::string &path)\n{\n'
                + extract_capture_body()
                + '\n}\n'
                'int main() { (void)captureDesktopToBmpNative("x.bmp"); return 0; }\n'
            )
            subprocess.run(
                [target, "-std=c++11", "-Wall", "-Wextra", "-Werror",
                 str(root / "capture.cpp"), "-o", str(root / "capture.exe"),
                 "-lgdi32", "-luser32"],
                check=True, capture_output=True, text=True,
            )


if __name__ == "__main__":
    unittest.main()
