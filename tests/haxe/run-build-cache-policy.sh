#!/usr/bin/env bash
# Guard the CI cache policy: the shared caches must be reused, not piled up.
#
# GitHub Actions caches are immutable snapshots of the `path` they were saved
# from. If a cache key changes with every commit, every run stores another
# full copy (140-370 MB of objects, 1.6 GB of haxelibs) until the 10 GB quota
# evicts all of them and warm runs stop being warm. These checks pin the
# rolling-key scheme in .github/workflows/main.yml and the hxcpp dependency
# declarations that make a shared object cache safe.
#
#   bash tests/haxe/run-build-cache-policy.sh
#
# Needs only bash and awk. No Haxe, no C++ toolchain.
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
workflow="$root/.github/workflows/main.yml"

[ -f "$workflow" ] || { echo "missing $workflow" >&2; exit 1; }

fail() { echo "FAIL: $*" >&2; exit 1; }

# Print one step body: from `- name: X` up to the next step/comment banner.
step() {
  awk -v want="$1" '
    $0 == "      - name: " want { inside = 1; print; next }
    inside && (/^      - (name:|uses:)/ || /^      # =/) { exit }
    inside { print }
  ' "$workflow"
}

have_step() {
  grep -qxF "      - name: $1" "$workflow" || fail "missing workflow step: $1"
}

# Value of a `with:` field inside a step body.
field() {
  awk -v key="$1" '
    match($0, "^          " key ": ") { print substr($0, RSTART + RLENGTH); found = 1; exit }
    END { if (!found) exit 3 }
  ' <<<"$2" || fail "missing \`$1\` in step"
}

# First restore-key (supports both the inline and the `|` block form).
restore_prefix() {
  local body="$1" inline block
  inline=$(awk '
    /^          restore-keys: [^|]/ {
      sub(/^          restore-keys: /, "")
      print
      exit
    }
  ' <<<"$body")
  if [ -n "$inline" ]; then printf '%s\n' "$inline"; return; fi
  block=$(awk '
    $0 == "          restore-keys: |" { inside = 1; next }
    inside && /^            / { print substr($0, 13); exit }
    inside { exit }
  ' <<<"$body")
  [ -n "$block" ] || fail "missing restore-keys"
  printf '%s\n' "$block"
}

step_if() {
  awk 'match($0, "^        if: ") { print substr($0, RSTART + RLENGTH); exit }' <<<"$1"
}

# ---------------------------------------------------------------------------
# 1. Only hxcpp's own object directory is cached, and never wiped before use.
# ---------------------------------------------------------------------------
have_step "Restore hxcpp object cache"
have_step "Save hxcpp object cache"
restore=$(step "Restore hxcpp object cache")
save=$(step "Save hxcpp object cache")

grep -q "uses: actions/cache/restore@v4" <<<"$restore" || fail "restore step must use actions/cache/restore"
grep -q "uses: actions/cache/save@v4" <<<"$save" || fail "save step must use actions/cache/save"

restore_path=$(field path "$restore")
save_path=$(field path "$save")
[ "$restore_path" = "$save_path" ] || fail "restore and save must cache the same path"
case "$restore_path" in
  *HXCPP_COMPILE_CACHE*) ;;
  *) fail "only hxcpp's object cache may be cached, got: $restore_path" ;;
esac
case "$restore_path" in
  *build/release*|*haxe/*) fail "generated Lime/Haxe output must not be cached: $restore_path" ;;
esac
for name in "Compile (Windows)" "Compile (Android)"; do
  body=$(step "$name")
  if printf '%s\n' "$body" | grep -qE '(rm[[:space:]]+-rf|Remove-Item).*HXCPP_COMPILE_CACHE'; then
    fail "$name deletes the restored object cache before compiling"
  fi
done

# ---------------------------------------------------------------------------
# 2. The save writes the exact key that was looked up.
#    `cache-hit` is only true on an exact match, and a cache found through a
#    restore-key is a miss, so the save step runs on a warm restore too. It
#    must then replace that same entry instead of writing a new key.
# ---------------------------------------------------------------------------
restore_key=$(field key "$restore")
save_key=$(field key "$save")
[ "$restore_key" = "$save_key" ] || fail "save must reuse the restore key"
[ "$restore_key" = "$(restore_prefix "$restore")" ] || fail "restore-key must reconstruct the exact key"
for body in "$save" "$(step 'Save haxelib and hxcpp tools')"; do
  if grep -q "cache-primary-key" <<<"$body"; then
    fail "saves must derive the key from the same expressions, not from cache-primary-key"
  fi
done

# ---------------------------------------------------------------------------
# 3. Keys must not follow the source tree (or the clock).
#    Hashing source/** or project.hxp makes every commit a new full snapshot;
#    a day/run stamp does the same on a schedule. hxcpp itself hashes each
#    translation unit's inputs, so a shared entry is still correct.
# ---------------------------------------------------------------------------
for key in "$restore_key" "$save_key"; do
  case "$key" in
    *source/*|*project.hxp*|*.github/workflows*) fail "cache key must not hash the source tree: $key" ;;
    *GITHUB_RUN_ID*|*github.run_id*) fail "cache key must not be stamped per run: $key" ;;
  esac
done
if grep -q "outputs.day" "$workflow"; then fail "cache keys must not carry a day stamp"; fi
if grep -q "runner-image" "$workflow"; then fail "stale runner-image/day outputs in the cache key"; fi
grep -q "date -u +%F" "$workflow" && fail "pending date command in the cache key"

# ---------------------------------------------------------------------------
# 4. Still isolated by toolchain, target, dependency set and flags; no
#    restore-key may be broader than the key itself (cold beats wrong).
# ---------------------------------------------------------------------------
for token in 'env.CACHE_SCHEMA' 'matrix.cache_name' 'runner.os' 'runner.arch' \
             'env.HAXE_VERSION' "hmm.json" 'setup/windows-msvc-fix.ps1' 'inputs.buildFlags'; do
  case "$restore_key" in
    *"$token"*) ;;
    *) fail "cache key is missing $token: $restore_key" ;;
  esac
done
# An unset input must not alias an explicit flag of the same name.
grep -qF "format('explicit-{0}', inputs.buildFlags) || 'unset'" <<<"$restore_key" \
  || fail "build flags must be namespaced (explicit-<flag> vs unset)"

# ---------------------------------------------------------------------------
# 5. The haxelib cache must be able to hit exactly, or its save uploads
#    ~1.6 GB per target on every single run.
# ---------------------------------------------------------------------------
have_step "Restore haxelib and hxcpp tools"
have_step "Save haxelib and hxcpp tools"
haxelib_restore=$(step "Restore haxelib and hxcpp tools")
haxelib_save=$(step "Save haxelib and hxcpp tools")
haxelib_key=$(field key "$haxelib_restore")
[ "$haxelib_key" = "$(field key "$haxelib_save")" ] || fail "haxelib save must reuse the restore key"
case "$haxelib_key" in
  *'env.CACHE_SCHEMA'*haxelib*'matrix.setup'*'env.HAXE_VERSION'*hashFiles*'hmm.json'*) ;;
  *) fail "haxelib key must be content-derived per target: $haxelib_key" ;;
esac
for name in "Install haxelib dependencies (Android)" "Install haxelib dependencies (Windows)"; do
  step_if "$(step "$name")" | grep -qF "steps.haxelib-cache.outputs.cache-hit != 'true'" \
    || fail "$name must run whenever the exact haxelib key misses"
done

# ---------------------------------------------------------------------------
# 6. Write policy: PR runs are read-only, every other trigger refreshes the
#    shared entry (workflow_call covers the release workflows).
# ---------------------------------------------------------------------------
for name in "Save haxelib and hxcpp tools" "Save hxcpp object cache"; do
  guard=$(step_if "$(step "$name")")
  case "$guard" in
    *"github.event_name != 'pull_request'"*) ;;
    *) fail "$name must be skipped for pull_request runs" ;;
  esac
  case "$guard" in
    *"event_name == 'push'"*) fail "$name must also save from workflow_call/dispatch" ;;
  esac
  case "$guard" in
    *"cache-hit != 'true'"*) ;;
    *) fail "$name must be skipped when the entry already exists" ;;
  esac
done

# hxcpp evicts its own entries above this budget, which would gut a dual-ABI
# Android or a Windows object set before the cache is saved.
grep -q 'HXCPP_CACHE_MB: "2048"' "$workflow" || fail "HXCPP_CACHE_MB must be raised to 2048"
grep -q '.hxcpp_cache/' "$root/.gitignore" || fail ".hxcpp_cache/ must stay gitignored"

# ---------------------------------------------------------------------------
# 7. Every native header must be a declared dependency, or a shared object
#    cache keeps objects compiled against the old header.
# ---------------------------------------------------------------------------
mapfile -t build_files < <(find "$root/source" -name '*build.xml' -print | sort)
[ "${#build_files[@]}" -gt 0 ] || fail "expected native build.xml files"

mapfile -t headers < <(find "$root/source" \( -name '*.h' -o -name '*.hpp' \) -print | sort)
[ "${#headers[@]}" -gt 0 ] || fail "expected native engine headers"

for header in "${headers[@]}"; do
  rel=${header#"$root/source/"}
  name=$(basename "$header")
  header_dir=$(dirname "$header")
  declaring=()
  for build_xml in "${build_files[@]}"; do
    if grep -qF "include/$name\" />" "$build_xml"; then
      declaring+=("$build_xml")
    fi
  done
  [ "${#declaring[@]}" -gt 0 ] \
    || fail "$rel is not declared as a <depend> in any build.xml (cached objects would keep old inline code)"
  # The declaring build file must live next to the header's include/ folder
  # (${this_dir}/include/...), otherwise the <depend> resolves elsewhere.
  ok=0
  for build_xml in "${declaring[@]}"; do
    [ "$(dirname "$build_xml")/include" = "$header_dir" ] && ok=1
    if grep -qE "include/$name\"[^>]*dateOnly=\"true\"" "$build_xml"; then
      fail "$rel is declared dateOnly=\"true\", which defeats content-hash invalidation"
    fi
  done
  [ "$ok" = 1 ] || fail "$rel is declared by a build.xml outside its include/ directory"
done

echo "build cache policy passed"
