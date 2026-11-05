"""Regression tests for asset caching, resolution memoization, and eviction."""

from __future__ import annotations

import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class PathsTrackingAndEvictionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.paths = read("source/backend/Paths.hx")

    def test_local_tracked_assets_uses_o1_set_deduplication(self):
        self.assertIn("private static var localTrackedAssetSet:Map<String, Bool>", self.paths)
        self.assertIn("public static inline function trackLocalAsset(key:String):Void", self.paths)
        self.assertNotIn("localTrackedAssets.contains(", self.paths)
        self.assertNotIn("dumpExclusions.contains(", self.paths)

    def test_external_array_mutations_resync_tracking_sets(self):
        self.assertIn("if (localTrackedAssets.length != localTrackedSyncedLen) syncLocalTrackedSet();", self.paths)
        self.assertIn("if (dumpExclusions.length != dumpExclusionsSyncedLen) syncDumpExclusionSet();", self.paths)

    def test_active_menu_music_and_playing_music_are_protected_from_eviction(self):
        self.assertIn("'assets/music/freakyMenu-' + ClientPrefs.daMenuMusic + '.$SOUND_EXT'", self.paths)
        self.assertIn("if (isMusicSound(sound)) continue;", self.paths)

    def test_sound_eviction_clears_openfl_and_lime_caches_and_closes_stopped_buffers(self):
        helper = self.paths[self.paths.index("private static function evictUnusedSounds():Int") :]
        helper = helper[: helper.index("public static function clearUnusedMemory()")]
        self.assertIn("OpenFlAssets.cache.removeSound(assetId);", helper)
        self.assertIn("Assets.cache.clear(assetId);", helper)
        self.assertIn("OpenFlAssets.cache.removeSound(key);", helper)
        self.assertIn("Assets.cache.clear(key);", helper)
        self.assertIn("sound.close();", helper)
        self.assertIn("MemoryLedger.untrackAsset(key);", helper)

    def test_clear_unused_memory_evicts_both_images_and_sounds_and_collects_before_compacting(self):
        fn = self.paths[self.paths.index("public static function clearUnusedMemory()") :]
        fn = fn[: fn.index("public static var localTrackedAssets")]
        self.assertIn("final vlogFreedSounds:Int = evictUnusedSounds();", fn)
        self.assertLess(fn.index("gc(true);"), fn.index("compress();"))


class PathsResolutionAndGpuSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.paths = read("source/backend/Paths.hx")

    def test_lookup_caches_exist_and_invalidate_on_mod_and_level_changes(self):
        for cache_field in (
            "resolvedImageKeyCache",
            "resolvedImageFileCache",
            "resolvedSoundCache",
            "resolvedExistsCache",
            "formattedSongPathCache",
        ):
            self.assertIn(cache_field, self.paths)
        self.assertIn("public static function invalidateAssetLookupCache():Void", self.paths)

        mods = read("source/backend/Mods.hx")
        self.assertGreaterEqual(mods.count("Paths.invalidateAssetLookupCache();"), 3)

    def test_cache_bitmap_avoids_duplicate_openfl_cache_retention_and_supports_mod_pack_icons(self):
        fn = self.paths[self.paths.index("public static function cacheBitmap(") :]
        fn = fn[: fn.index("static public function getTextFromFile(")]
        self.assertIn("OpenFlAssets.getBitmapData(file, false)", fn)
        self.assertIn("OpenFlAssets.cache.removeBitmapData(file)", fn)
        self.assertIn("if (FileSystem.exists(key))", fn)

    def test_gpu_caching_guards_context3d_and_avoids_dangling_cairo_surface(self):
        fn = self.paths[self.paths.index("public static function cacheBitmap(") :]
        fn = fn[: fn.index("static public function getTextFromFile(")]
        self.assertIn("FlxG.stage != null && FlxG.stage.context3D != null", fn)
        self.assertNotIn("bitmap.getSurface()", fn)
        self.assertIn("if (bitmap.__texture != null)", fn)
        self.assertIn("bitmap.readable = true;", fn)

    def test_ogg_magic_reads_only_four_byte_header_not_entire_file(self):
        self.assertIn("private static function hasOggMagic(file:String):Bool", self.paths)
        self.assertIn("input.readBytes(header, 0, 4)", self.paths)
        self.assertNotIn("File.getBytes(file).sub(0, 4)", self.paths)

    def test_atlas_loaders_short_circuit_via_find_frame_before_disk_io(self):
        for loader in ("getAtlas(", "getSparrowAtlas(", "getPackerAtlas(", "getAsepriteAtlas("):
            start = self.paths.index("static public function " + loader)
            snippet = self.paths[start : start + 500]
            self.assertIn("FlxAtlasFrames.findFrame(imageLoaded, ZERO_BORDER)", snippet, loader)

    def test_format_to_song_path_uses_memoized_char_scanner_without_per_call_regex(self):
        fn = self.paths[self.paths.index("static public function formatToSongPath(") :]
        fn = fn[: fn.index("inline static function isOggFile(")]
        self.assertNotIn("~/", fn)
        self.assertIn("formattedSongPathCache.get(path)", fn)

    def test_get_text_from_file_checks_lime_assets_exists_before_get_text(self):
        fn = self.paths[self.paths.index("static public function getTextFromFile(") :]
        fn = fn[: fn.index("inline static public function font(")]
        self.assertIn("if (Assets.exists(assetPath, TEXT)) text = Assets.getText(assetPath);", fn)


class PatchedOpenFlAssetsAndStateLifecycleTests(unittest.TestCase):
    def test_patched_openfl_assets_recognizes_gpu_textures_and_rejects_closed_sounds(self):
        assets = read("source/source-haxelib-patches/openfl/utils/Assets.hx")
        self.assertIn("bitmapData.__texture != null", assets)
        self.assertIn("sound.__buffer != null", assets)

    def test_menu_states_run_clear_unused_memory_after_loading_their_assets(self):
        for rel in (
            "source/states/MainMenuState.hx",
            "source/states/FreeplayState.hx",
            "source/states/StoryMenuState.hx",
            "source/states/CreditsState.hx",
            "source/states/AchievementsMenuState.hx",
            "source/states/ModsMenuState.hx",
            "source/options/OptionsState.hx",
        ):
            src = read(rel)
            stored_idx = src.index("Paths.clearStoredMemory();")
            unused_idx = src.rindex("Paths.clearUnusedMemory();")
            self.assertGreater(
                unused_idx,
                stored_idx + 120,
                f"{rel} should load its own assets between clearStoredMemory() and clearUnusedMemory()",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
