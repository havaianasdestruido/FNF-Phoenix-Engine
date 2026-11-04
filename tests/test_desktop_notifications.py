"""Native notification helpers must treat mod-supplied strings as data."""
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class DesktopNotificationTests(unittest.TestCase):
    def test_native_helpers(self):
        compiler = shutil.which('c++')
        if not compiler:
            self.skipTest('C++ compiler unavailable')
        source = r'''
#include "phoenix_desktop_dialog.h"
#include <cassert>
int main() {
  assert(phoenixShowLinuxNotification("--title", "$(touch /tmp/phoenix-injection)"));
  assert(phoenixShowMacNotification("a\"b", "line\n\\end"));
  assert(phoenixMacNotificationScript("a\"b", "line\n\\end") ==
    "display notification \"line\\n\\\\end\" with title \"a\\\"b\"");
  return 0;
}
'''
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            cpp = root / 'test.cpp'
            cpp.write_text(source)
            program = root / 'test'
            subprocess.run([compiler, '-std=c++11', '-Wall', '-Wextra', '-Werror',
                            '-I', str(ROOT / 'source/utils/include'), str(cpp), '-o', str(program)], check=True)
            for name in ('notify-send', 'osascript'):
                executable = root / name
                executable.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$CAPTURE/' + name + '.args"\n')
                executable.chmod(0o755)
            env = dict(os.environ, PATH=str(root), CAPTURE=str(root))
            subprocess.run([str(program)], env=env, check=True)
            self.assertEqual((root / 'notify-send.args').read_text(),
                             '--\n--title\n$(touch /tmp/phoenix-injection)\n')
            self.assertEqual((root / 'osascript.args').read_text(),
                             '-e\ndisplay notification "line\\n\\\\end" with title "a\\\"b"\n')
            (root / 'notify-send').write_text('#!/bin/sh\nexit 1\n')
            failure = root / 'failure.cpp'
            failure.write_text('#include "phoenix_desktop_dialog.h"\nint main() { return phoenixShowLinuxNotification("x", "y") ? 1 : 0; }\n')
            subprocess.run([compiler, '-std=c++11', '-I', str(ROOT / 'source/utils/include'),
                            str(failure), '-o', str(program)], check=True)
            subprocess.run([str(program)], env=env, check=True)
            (root / 'notify-send').unlink()
            subprocess.run([str(program)], env=env, check=True)

    def test_platform_dispatch(self):
        public = (ROOT / 'source/utils/PlatformUtil.hx').read_text()
        native = (ROOT / 'source/utils/PlatformUtilNative.hx').read_text()
        self.assertIn('PlatformUtilNative.sendDesktopNotification(title, message)', public)
        self.assertIn('Windows.sendWindowsNotification(title, message)', public)
        self.assertIn('phoenixShowLinuxNotification', native)
        self.assertIn('phoenixShowMacNotification', native)
        self.assertIn('!android', public)
        self.assertIn('!ios', public)


if __name__ == '__main__':
    unittest.main()
