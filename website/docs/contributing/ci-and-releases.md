---
title: CI & releases
sidebar_position: 3
description: The GitHub Actions workflows, the build matrix, caching and how releases are produced.
---

# CI & releases

All workflows live in `.github/workflows/`.

## `main.yml` — Build

The shared build matrix runs on pushes and pull requests targeting `main` or `bleeding`.
It also supports manual and reusable calls (`workflow_dispatch` and `workflow_call`),
with inputs to select targets **and the script modding level**. CI supports only Windows
and Android; other Lime targets can still be built locally. `fail-fast` is off, so one
broken target does not hide the other.

| Job | Runner | Target | Artifact |
|---|---|---|---|
| Windows | `windows-latest` | `windows` | `<commit>_windows_<HH>_<MM>_<scripts>` |
| Android | `ubuntu-24.04` | `android` | `<commit>_android_<HH>_<MM>_<scripts>` |

Each job: checkout → target selection check → resolve the script modding level →
platform setup (Java 17 and Android SDK/NDK for Android) → restore haxelib/hxcpp caches →
install `hmm.json` dependencies → configure Android / ensure the MSVC hxcpp checkout →
compile hxcpp tools → restore the generated C++ cache → **compile** → save caches →
publish artifacts.

### Script modding level and artifact names

`moddingLevel` (`0` = no scripts, `1` = Lua, `2` = Lua + Python, default `2`) is passed to
the build as `-DMODDING_LEVEL`, which `project.hxp` turns into the `LUA_ALLOWED` and
`PYTHON_ALLOWED` feature flags. It is shown in two places, so a build never has to be
opened to know what it can run:

- **Run title** — every run is named `Build (<event>) - MODDING_LEVEL <level>`, and the
  release workflows name theirs too (`Release <tag> - MODDING_LEVEL <level>`).
- **Artifact name** — `<commit>_<target>_<HH>_<MM>_<scripts>`, where `<scripts>` lists only
  the backends that really are in the binary:

  | Suffix | Level | What it can run |
  |---|---|---|
  | `_LUA_PYTHON_HSCRIPT` | 2 | Lua, Python and HScript mods (default on Windows) |
  | `_LUA_HSCRIPT` | 1 | Lua and HScript mods |
  | `_HSCRIPT` | 0 | HScript mods only — also every Android build |
  | `_NONE` | — | no script support at all |

  HScript is compiled for every desktop and mobile target independently of the level, so it
  is always listed. The suffix also shows up in the download links of the pull-request
  comment posted by `nightly.yml`.

Android is always built at level `0`: `project.hxp` only adds the `hxluajit` haxelib for
desktop targets, so asking for Lua there would compile `import hxluajit.*` without the
bindings and fail at `source/import.hx`. The workflow clamps the level and prints a
`::notice::` instead.

The level is part of the hxcpp object cache key, since objects compiled for one level are
useless for another. The haxelib and Gradle caches are shared between levels: the
dependencies are installed either way.

Two steps worth knowing about:

- **`Verify Android APK native libs`** — unzips the APK and fails the build if
  `libc++_shared.so` is missing for any ABI. This is the automated form of the
  [`dlopen` failure](../getting-started/troubleshooting.md#android-dlopen-failed-libc_sharedso-not-found).
  The preceding manifest check also verifies Media3/SAF components and SDK levels.
- **Cache handling** — both the haxelib/hxcpp tools and hxcpp's native object cache
  (`.hxcpp_cache`, via `HXCPP_COMPILE_CACHE`) are cached per target (`cache_name`).
  Cold builds take longer than warm ones.

### How the caches are keyed

GitHub Actions caches are immutable and every entry is a full snapshot of the path it
was saved from, so a cache key that changes with every commit stores the same 140–370 MB
of objects (and 1.6 GB of haxelibs) over and over until the 10 GB quota evicts all of
them. This workflow therefore uses **one rolling entry per target**:

- The key hashes only what makes the cache *incompatible*: `CACHE_SCHEMA`, the target,
  OS/arch, Haxe version, the pinned dependency set (`hmm.json` + the setup scripts) and
  the build flags. Source files, `project.hxp` and the workflow itself are deliberately
  **not** hashed.
- hxcpp already hashes each translation unit's own inputs (sources, headers declared as
  `<depend>` in `source/**/build.xml`, compiler flags) and recompiles the objects that
  changed, so sharing the cache across commits is safe. A new native header must be
  declared in its `build.xml`, or cached objects will keep the old inline code —
  `tests/haxe/run-build-cache-policy.sh` enforces that (it runs in `checks.yml` and needs
  no Haxe or C++ toolchain).
- The save step writes the **same key** that was looked up (`cache-hit` is only true on
  an exact match, and a restore-key hit counts as a miss), so a miss restores the
  previous generation, adds the new objects and replaces the entry after the build.
- Only `pull_request` runs are read-only. `push`, `workflow_dispatch` and `workflow_call`
  (manual/mobile releases, release assets) all refresh the shared entry.
- The haxelib key is content-derived too, so it hits exactly on a warm run instead of
  re-uploading the haxelib tree on every commit. Dependencies are only installed when
  that exact key misses.
- **Gradle is cached manually, not with `actions/setup-java`'s `cache: gradle`.** That
  action hashes a Gradle project that Lime only generates *during* the build, so the
  lookup missed on every run and each PR scope saved its own 512 MB copy (~3 GB of the
  quota). `~/.gradle/caches` is restored/saved on the same rolling per-target key
  instead, so all PRs share the main branch's entry.
- Bump `CACHE_SCHEMA` in `main.yml` to invalidate every existing entry at once (e.g.
  after changing what is cached). Evicted payloads are rebuilt on the next run.

`HXCPP_CACHE_MB` is raised to 2048 so a full Windows/dual-ABI Android object set fits
hxcpp's own disk budget instead of being evicted mid-build. Note that the hxcpp object
directory is content-addressed, so entries for source revisions that no longer build are
simply not referenced anymore; the rolling save replaces the snapshot rather than
accumulating one per commit.

Windows artifacts contain `build/release/windows/bin`. Android artifacts contain the
APK under `build/release/android/bin/app/build/outputs/apk/debug`: the pinned Lime fork
uses the debug flavor when no signing keystore is configured.

`mobile.yml` was removed because it duplicated this Android build. All Android CI and
mobile releases now use `main.yml`, including its manifest and native-library checks.

## `mobile-release.yml` — Mobile Release

Manual. Select an existing Phoenix release tag explicitly; the workflow validates the
tag and build commit before calling `main.yml` with `buildWindows: false`,
`buildAndroid: true` and `moddingLevel: "0"` (mobile cannot ship the Lua/Python VMs). It
attaches the resulting APK to the existing release. It does not use GitHub's `latest`
redirect, which excludes prereleases.

## `release.yml` — Manual Release

Manual, with `tag_name`, `prerelease` and `moddingLevel` inputs. Validates the version,
creates the tag if needed, calls `main.yml` at that modding level, and uploads the Windows
artifact to a draft release.
GitHub-generated notes and the optional Markdown message become the release body; edit
the release on GitHub to maintain its changelog.

## `release-assets.yml` — Release Assets

Automatic. When a release is published on the Releases page — a brand-new release or a
draft promoted to published — this workflow builds the tagged commit through `main.yml`
with `buildFlags: officialBuild` and attaches `FNF-Phoenix-Engine-windows.zip` and
`FNF-Phoenix-Engine-android.apk` to the release page. It builds at the default
`moddingLevel` (`2`, so the Windows release runs Lua and Python mods); a manual dispatch
can pick another level with the `moddingLevel` input. The published asset names stay
stable — the level is in the run title and in the uploaded artifact names instead.
Assets already attached to the release are skipped, so publishing a draft prepared by
`release.yml` only builds what is missing (typically the APK). The `tools/release_version.py` check is advisory here
because the release is already public; the manual workflows above still gate tag creation
on it. A manual dispatch with an explicit `tag_name` backfills or re-attaches artifacts
for an existing release and must be run from the tagged commit. The workflow has to exist
in the commit a release points at, so release from up-to-date `main`.

## `checks.yml` — Checks

Runs the dependency-manifest check, the JNI bridge contract check, host-JVM
Android tests, standalone native C/C++ smoke tests, and an hxcpp
native-object-cache smoke test on Linux and Windows. These checks do not require
a full game build or the Android SDK. The isolated Haxe interpreter specs in
`tests/haxe/` are not wired into this workflow; run the matching `run-*.sh` script
locally (see
[`docs/HAXE_LINUX.md`](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/HAXE_LINUX.md)).

## `docs.yml` — Documentation

Builds and checks the Docusaurus site, then publishes it to GitHub Pages for non-PR
events. See [Documentation](./documentation.md).

## `sparse-submodule.yml` — Sparse Submodule

On changes to the submodule configuration, on demand, or as a reusable workflow, checks
out only `fnf_030_ui` from `mods/psych-scripts`. It verifies the pinned commit and local
mod link, then uploads the mod as an artifact. This keeps the full upstream repository
out of the checkout.

## `nightly.yml`, `autotriage.yml`, `autolock.yml`

Housekeeping: a comment on pull requests, label cleanup when issues are closed or
commented on, and automatic closing of inactive issues.

## Dependabot

`.github/dependabot.yml` keeps GitHub Actions versions up to date.

## Reproducing CI locally

```bash
# Install dependencies first: sh setup/unix.sh (or setup\windows.bat on Windows).
haxelib run lime build windows -Dcommit -DMODDING_LEVEL=2
haxelib run lime build android -DMODDING_LEVEL=0
python3 tools/check_dependencies.py
python3 tools/check_android_bridge.py --check
bash tests/java/run.sh
bash tests/native/run.sh
```

For Android make sure `lime setup android` has been run so `ANDROID_NDK_ROOT` resolves.
Official builds use `-DofficialBuild`; see [Building](../getting-started/building.md) for
the full setup and other locally supported targets.

## Versioning

`VERSION` in `project.hxp` is the single source of truth and is queried at runtime. Bump
it there and run `python3 tools/release_version.py v0.0.1 --check-only`, then run
the release workflow with the matching tag. Phoenix supports `-alpha`, `-beta`,
`-preN`, and `-rcN`. The in-game checker displays the GitHub release body and
checks stable releases by default. Players can include prereleases via **Misc →
Enable pre-release updates**. Drafts are never shown.
