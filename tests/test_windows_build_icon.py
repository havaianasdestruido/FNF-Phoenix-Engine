"""Windows build folder icon packaging and attribute restoration regressions."""
import shutil
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class WindowsBuildIconTests(unittest.TestCase):
    def test_desktop_ini_and_icon(self):
        ini = (ROOT / 'art/windows/desktop.ini').read_text(encoding='ascii')
        self.assertEqual(ini.splitlines(), ['[.ShellClassInfo]', 'IconFile=phoenix.ico', 'IconIndex=0'])
        ico = (ROOT / 'art/windows/phoenix.ico').read_bytes()
        self.assertEqual(struct.unpack_from('<HHH', ico), (0, 1, 4))
        for i, size in enumerate((16, 32, 64, 256)):
            width, height, _, _, planes, bits, length, offset = struct.unpack_from('<BBBBHHII', ico, 6 + 16 * i)
            self.assertEqual((width or 256, height or 256, planes, bits), (size, size, 1, 32))
            image = ico[offset:offset + length]
            self.assertEqual(image[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack_from('>II', image, 16), (size, size))
            if size < 256:
                self.assertEqual(image, (ROOT / f'art/icon{size}.png').read_bytes())

    def test_assets_are_windows_only_and_not_embedded(self):
        project = (ROOT / 'project.hxp').read_text()
        icons = project.split('function configureIcons()', 1)[1].split('if (isAndroid())', 1)[0]
        self.assertIn('if (isWindows())', icons)
        for name in ('desktop.ini', 'phoenix.ico'):
            self.assertIn(f'addAsset("art/windows/{name}", "{name}", "default", false)', icons)
        self.assertIn('Sys.systemName() == "Windows"', icons)
        self.assertIn('Sys.command("attrib", ["+r", folder])', icons)

    @unittest.skipUnless(shutil.which('g++'), 'g++ is required for native mock')
    def test_native_attribute_restoration(self):
        main = (ROOT / 'source/Main.hx').read_text()
        self.assertIn('#if (cpp && windows)\n    restoreBuildFolderIcon();', main)
        code = main.split('private static function restoreBuildFolderIcon', 1)[0].rsplit("@:functionCode('", 1)[1].rsplit("')", 1)[0]
        # Haxe's single-quoted metadata string decodes each escaped backslash.
        code = code.replace('\\\\', '\\')
        cpp = r'''
#include <string>
#include <cassert>
#include <cwchar>
using DWORD = unsigned long;
const DWORD INVALID_FILE_ATTRIBUTES = 0xffffffff, FILE_ATTRIBUTE_READONLY = 1, FILE_ATTRIBUTE_DIRECTORY = 16;
std::wstring exe = L"C:\\Jogos\\Phoenix\\game.exe";
DWORD ini = 0, icon = 0, folder = FILE_ATTRIBUTE_DIRECTORY, result = 0;
std::wstring changed;
DWORD GetModuleFileNameW(void*, wchar_t* out, DWORD size) {
  if (exe.empty()) return 0;
  if (exe.size() >= size) return size;
  std::wcscpy(out, exe.c_str()); return exe.size();
}
DWORD GetFileAttributesW(const wchar_t* path) {
  std::wstring p(path);
  if (p == L"C:\\Jogos\\Phoenix\\desktop.ini") return ini;
  if (p == L"C:\\Jogos\\Phoenix\\phoenix.ico") return icon;
  if (p == L"C:\\Jogos\\Phoenix") return folder;
  return INVALID_FILE_ATTRIBUTES;
}
int SetFileAttributesW(const wchar_t* path, DWORD attrs) { changed = path; result = attrs; return 1; }
void restore() {
''' + code + r'''
}
int main() {
  restore(); assert(changed == L"C:\\Jogos\\Phoenix" && result == (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_READONLY));
  changed.clear(); ini = INVALID_FILE_ATTRIBUTES; restore(); assert(changed.empty());
  ini = 0; icon = FILE_ATTRIBUTE_DIRECTORY; restore(); assert(changed.empty());
  icon = 0; folder |= FILE_ATTRIBUTE_READONLY; restore(); assert(changed.empty());
  folder = FILE_ATTRIBUTE_DIRECTORY; exe.clear(); restore(); assert(changed.empty());
  exe = std::wstring(32768, L'a'); restore(); assert(changed.empty());
}
'''
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'test.cpp'
            binary = Path(tmp) / 'test'
            source.write_text(cpp)
            subprocess.run(['g++', '-std=c++11', '-Wall', '-Werror', str(source), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)


if __name__ == '__main__':
    unittest.main()
