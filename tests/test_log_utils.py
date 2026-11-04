"""Privacy and bounded-retention contracts for engine diagnostic logs."""
from __future__ import annotations

import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class LogPrivacyAndRetentionTests(unittest.TestCase):
    def test_shared_policy_redacts_paths_and_caps_report_retention(self) -> None:
        source = read("source/backend/LogUtils.hx")
        for token in (
            "MAX_LOG_FILE_BYTES:Int = 2 * 1024 * 1024",
            "MAX_LOG_FILES:Int = 10",
            "MAX_LOG_TOTAL_BYTES:Int = 16 * 1024 * 1024",
            "MAX_LOG_AGE_DAYS:Int = 30",
            "HOME",
            "USERPROFILE",
            "HOMEDRIVE",
            "USERNAME",
            "WINDOWS_BACKSLASH_PATH",
            "WINDOWS_SLASH_PATH",
            "UNC_ABSOLUTE_PATH",
            "POSIX_ABSOLUTE_PATH",
            "limitText(redact(text), maxBytes)",
            "pruneDirectory(directory, Path.withoutDirectory(path))",
        ):
            self.assertIn(token, source)

    def test_startup_cleans_old_reports_before_they_can_be_shared(self) -> None:
        main = read("source/Main.hx")
        self.assertIn("backend.LogUtils.cleanup();", main)
        self.assertLess(main.index("backend.LogUtils.cleanup();"), main.index("backend.VLog.init("))
        self.assertLess(main.index("backend.LogUtils.cleanup();"), main.index("CrashHandler.init()"))
        self.assertIn('["crash", "debug/log", "logs"]', read("source/backend/LogUtils.hx"))

    def test_crash_shader_copy_and_profiler_reports_use_the_safe_writer(self) -> None:
        crash = read("source/backend/CrashHandler.hx")
        shader = read("source/shaders/ErrorHandledShader.hx")
        copy_state = read("source/mobile/CopyState.hx")
        profiler = read("source/debug/FrameProfiler.hx")
        self.assertIn("LogUtils.saveLog(path, crashReport)", crash)
        self.assertIn("backend.LogUtils.saveLog(crashLogPath", shader)
        self.assertIn("backend.LogUtils.saveLog(copyLogPath", copy_state)
        self.assertIn("return backend.LogUtils.redact(buf.toString());", profiler)
        self.assertIn("backend.LogUtils.sanitizeFile(exported)", profiler)
        self.assertLess(profiler.index("backend.LogUtils.sanitizeFile(exported)"), profiler.index("lastExportedLogPath = exported"))
        self.assertIn("safeFileName(backend.LogUtils.redact(requestedName))", profiler)

    def test_vlog_redacts_persisted_and_exported_content_and_rotates_by_size_and_age(self) -> None:
        vlog = read("source/backend/VLog.hx")
        self.assertIn("LogUtils.redact(buffer.toString())", vlog)
        self.assertIn("return LogUtils.redact(content);", vlog)
        self.assertIn("MAX_LOG_AGE_DAYS:Int = 30", vlog)
        self.assertIn("pruneExpiredRotations();", vlog)
        self.assertIn("ageMs < maxAgeMs", vlog)
        self.assertIn("MAX_LOG_BYTES", vlog)

    def test_runtime_spec_is_wired_into_haxe_ci(self) -> None:
        self.assertTrue((ROOT / "tests/haxe/LogUtilsSpec.hx").is_file())
        self.assertTrue((ROOT / "tests/haxe/run-log-utils.sh").is_file())
        checks = read(".github/workflows/checks.yml")
        self.assertIn("bash tests/haxe/run-log-utils.sh", checks)


if __name__ == "__main__":
    unittest.main()
