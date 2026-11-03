#!/usr/bin/env bash
# Install the Haxe version used by Phoenix Engine CI without sudo or apt.
set -euo pipefail

readonly VERSION=4.3.7
readonly REVISION=95475451f930551a8cdd65c77fcae07513952903
readonly SOURCE_URL=https://github.com/ceramic-engine/haxe-binary.git
readonly HAXE_SHA256=187a9bab4ffbd795d68c980fe7c1d96023fcf9c56862fccafd6c72b832cc1d98
readonly HAXELIB_SHA256=c4da75b350656b066fe3d8233a192aa5ee4f268e922fa31d3ccd88bcf16715a7

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo "This installer was tested on Linux x86_64 only." >&2
  exit 1
fi
for tool in git mktemp install sha256sum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required command not found: $tool" >&2
    exit 1
  fi
done

readonly ROOT="$HOME/.local/opt/phoenix-haxe/$VERSION"
readonly BIN_DIR="$HOME/.local/bin"
LIB_DIR="${HAXELIB_PATH:-$HOME/haxelib}"
mkdir -p "$(dirname "$ROOT")" "$BIN_DIR" "$LIB_DIR"
LIB_DIR=$(cd "$LIB_DIR" && pwd -P)

# Do not replace an unrelated haxe/haxelib command in the user's bin directory.
for tool in haxe haxelib; do
  target="$BIN_DIR/$tool"
  if [[ -e "$target" || -L "$target" ]] && ! grep -q '^# Phoenix Haxe launcher' "$target" 2>/dev/null; then
    echo "Refusing to overwrite $target. Move that existing launcher aside first." >&2
    exit 1
  fi
done

if [[ ! -e "$ROOT" ]]; then
  # The revision is immutable. Sparse checkout downloads Linux x86_64 only;
  # Windows, macOS and ARM binaries are not needed here. Nothing enters the
  # engine repository, and no package-manager or system directory is changed.
  work=$(mktemp -d "$(dirname "$ROOT")/.install.XXXXXX")
  trap 'rm -rf "$work"' EXIT
  source_dir="$work/source"
  git init --quiet "$source_dir"
  git -C "$source_dir" remote add origin "$SOURCE_URL"
  git -C "$source_dir" fetch --quiet --depth=1 --filter=blob:none origin "$REVISION"
  test "$(git -C "$source_dir" rev-parse FETCH_HEAD)" = "$REVISION"
  git -C "$source_dir" sparse-checkout set linux-x86_64
  git -C "$source_dir" checkout --quiet --detach "$REVISION"

  printf '%s  %s\n' "$HAXE_SHA256" "$source_dir/linux-x86_64/haxe/haxe-bin" \
    "$HAXELIB_SHA256" "$source_dir/linux-x86_64/haxe/haxelib-bin" | sha256sum --check --status
  mv "$source_dir/linux-x86_64" "$ROOT"
  rm -rf "$work"
  trap - EXIT
fi

printf '%s  %s\n' "$HAXE_SHA256" "$ROOT/haxe/haxe-bin" \
  "$HAXELIB_SHA256" "$ROOT/haxe/haxelib-bin" | sha256sum --check --status

# Non-login agent shells may not read .bashrc or .profile. Small launchers
# explicitly configure this installation on every invocation instead. Existing
# HAXELIB_PATH/LD_LIBRARY_PATH values are preserved; otherwise haxelib reads
# the repository configured by `haxelib setup`. Neko stays process-local.
for tool in haxe haxelib; do
  launcher=$(mktemp "$BIN_DIR/.$tool.XXXXXX")
  cat > "$launcher" <<'LAUNCHER'
#!/usr/bin/env bash
# Phoenix Haxe launcher (4.3.7)
set -euo pipefail
export HAXEPATH="$HOME/.local/opt/phoenix-haxe/4.3.7/haxe"
export HAXE_STD_PATH="$HAXEPATH/std"
export NEKOPATH="$HOME/.local/opt/phoenix-haxe/4.3.7/neko"
export PATH="$HOME/.local/bin:$NEKOPATH:$PATH"
export LD_LIBRARY_PATH="$NEKOPATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
LAUNCHER
  printf 'exec "$HAXEPATH/%s-bin" "$@"\n' "$tool" >> "$launcher"
  install -m 755 "$launcher" "$BIN_DIR/$tool"
  rm -f "$launcher"
done

test "$("$BIN_DIR/haxe" --version)" = "$VERSION"
"$BIN_DIR/haxelib" setup "$LIB_DIR"
echo "Haxe $("$BIN_DIR/haxe" --version); haxelib $("$BIN_DIR/haxelib" version)"
echo "Compiler: $BIN_DIR/haxe"
echo "Library directory: $LIB_DIR"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Run in each new shell: export PATH="%s:$PATH"\n' "$BIN_DIR" ;;
esac
