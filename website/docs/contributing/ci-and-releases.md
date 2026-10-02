---
title: CI & releases
sidebar_position: 3
description: The GitHub Actions workflows, the build matrix, caching and how releases are produced.
---

# CI & releases

All workflows live in `.github/workflows/`.

## `main.yml` — Build

The main matrix, triggered on push and manually (`workflow_dispatch`, with inputs to pick
targets). `fail-fast` is off, so one broken target does not hide the others.

| Job | Runner | Target |
|---|---|---|
| Windows | `windows-latest` | `windows` |
| Linux | `ubuntu` | `linux` |
| macOS (Intel) | `macos` | `mac` |
| macOS (ARM) | `macos` | `mac` |
| Android | `ubuntu-24.04` | `android` |
| HTML5 | ubuntu | `html5` |
| Neko | ubuntu | `neko` |
| Flash | ubuntu | `flash` |
| HashLink | ubuntu | `hl` |
| AIR | ubuntu | `air` (downloads the AIR SDK) |

Each job: checkout → target selection check → platform setup (Java 17, Android SDK/NDK,
Linux packages) → restore haxelib/hxcpp caches → install `hmm.json` dependencies →
configure Android / ensure the MSVC hxcpp checkout → compile hxcpp tools → restore the
generated C++ cache → **compile** → save caches → publish artifacts.

Two steps worth knowing about:

- **`Verify Android APK native libs`** — unzips the APK and fails the build if
  `libc++_shared.so` is missing for any ABI. This is the automated form of the
  [`dlopen` failure](../getting-started/troubleshooting.md#android-dlopen-failed-libc_sharedso-not-found).
- **Cache handling** — both the haxelib/hxcpp tools and the generated C++ output are
  cached per target (`cache_name`), with proper `HXCPP_COMPILE_CACHE` detection. Cold
  builds take 5–10 minutes; warm ones are far quicker.

Artifacts are published per target (`windowsBuild`, `androidBuild`, …) from
`build/release/<target>/bin`.

## `mobile.yml` — Mobile

A smaller matrix: Android on `ubuntu-24.04` and iOS on `macos-latest`
(`lime build ios -nosign`). Runs on push and on demand.

## `mobile-release.yml` — Mobile Release

Manual. Resolves the latest tag, builds the mobile targets and attaches them to the
release.

## `release.yml` — Manual Release

Manual, with a `prerelease` input. Ensures the tag exists, builds and publishes the
release.

## `nightly.yml`, `autotriage.yml`, `autolock.yml`

Housekeeping: a comment on pull requests, label cleanup when issues are closed or
commented on, and automatic closing of inactive issues.

## `jekyll-gh-pages.yml`

The original GitHub Pages workflow (currently only `workflow_dispatch` — its push trigger
is commented out). The documentation site in `website/` has its own workflow,
`docs.yml` — see [Documentation](./documentation.md).

## Dependabot

`.github/dependabot.yml` keeps GitHub Actions versions up to date.

## Reproducing CI locally

```bash
# what CI effectively runs per target
sh setup/unix.sh                       # or setup\windows.bat
haxelib run lime build <target> -Dofficial
```

For the SWF targets add `-D disable-version-check` (and `-DAIR_SDK=<path>` for AIR).
For Android make sure `lime setup android` has been run so `ANDROID_NDK_ROOT` resolves.

## Versioning

`VERSION` in `project.hxp` is the single source of truth and is queried at runtime. Bump
it there, tag the commit, then run the release workflow.
