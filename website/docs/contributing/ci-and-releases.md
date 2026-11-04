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
with inputs to select targets. CI supports only Windows and Android; other Lime targets
can still be built locally. `fail-fast` is off, so one broken target does not hide the other.

| Job | Runner | Target | Artifact |
|---|---|---|---|
| Windows | `windows-latest` | `windows` | `windowsBuild` |
| Android | `ubuntu-24.04` | `android` | `androidBuild` |

Each job: checkout → target selection check → platform setup (Java 17 and Android SDK/NDK
for Android) → restore haxelib/hxcpp caches → install `hmm.json` dependencies → configure
Android / ensure the MSVC hxcpp checkout → compile hxcpp tools → restore the generated
C++ cache → **compile** → save caches → publish artifacts.

Two steps worth knowing about:

- **`Verify Android APK native libs`** — unzips the APK and fails the build if
  `libc++_shared.so` is missing for any ABI. This is the automated form of the
  [`dlopen` failure](../getting-started/troubleshooting.md#android-dlopen-failed-libc_sharedso-not-found).
  The preceding manifest check also verifies Media3/SAF components and SDK levels.
- **Cache handling** — both the haxelib/hxcpp tools and the generated C++ output are
  cached per target (`cache_name`), with proper `HXCPP_COMPILE_CACHE` detection. Cold
  builds take longer than warm ones.

Windows artifacts contain `build/release/windows/bin`. Android artifacts contain the
APK under `build/release/android/bin/app/build/outputs/apk/debug`: the pinned Lime fork
uses the debug flavor when no signing keystore is configured.

`mobile.yml` was removed because it duplicated this Android build. All Android CI and
mobile releases now use `main.yml`, including its manifest and native-library checks.

## `mobile-release.yml` — Mobile Release

Manual. Select an existing Phoenix release tag explicitly; the workflow validates the
tag and build commit before calling `main.yml` with `buildWindows: false` and
`buildAndroid: true`. It attaches the resulting APK to the existing release. It does not
use GitHub's `latest` redirect, which excludes prereleases.

## `release.yml` — Manual Release

Manual, with `tag_name` and `prerelease` inputs. Validates the version, creates the tag if
needed, calls `main.yml`, and uploads the Windows artifact to a draft release.
GitHub-generated notes and the optional Markdown message become the release body; edit
the release on GitHub to maintain its changelog.

## `release-assets.yml` — Release Assets

Automatic. When a release is published on the Releases page — a brand-new release or a
draft promoted to published — this workflow builds the tagged commit through `main.yml`
with `buildFlags: officialBuild` and attaches `FNF-Phoenix-Engine-windows.zip` and
`FNF-Phoenix-Engine-android.apk` to the release page. Assets already attached to the
release are skipped, so publishing a draft prepared by `release.yml` only builds what is
missing (typically the APK). The `tools/release_version.py` check is advisory here
because the release is already public; the manual workflows above still gate tag creation
on it. A manual dispatch with an explicit `tag_name` backfills or re-attaches artifacts
for an existing release and must be run from the tagged commit. The workflow has to exist
in the commit a release points at, so release from up-to-date `main`.

## `checks.yml` — Checks

Runs the dependency-manifest check, host-JVM Android tests, standalone native
C/C++ smoke tests, and isolated Haxe tests for layout, chart timing, mod imports,
versions and updates. These checks do not require a full game build or the
Android SDK.

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
haxelib run lime build windows -Dcommit
haxelib run lime build android
python3 tools/check_dependencies.py
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
