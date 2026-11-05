#!/bin/sh
# Port of Unregister-PhoenixURI.ps1 - keep in sync with the .ps1 / .bat versions.
# Windows-only (HKCU registry): delegates to reg.exe / Windows PowerShell
# under Git Bash / MSYS2 / Cygwin / WSL, otherwise explains and exits 1.
# Usage: Unregister-PhoenixURI.sh [path-to-FNF-Phoenix-Engine.exe]
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXE=${1:-"$script_dir/../FNF-Phoenix-Engine.exe"}

case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) ;;
    *)
        if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
            : # WSL: fall through.
        else
            echo "Unregister-PhoenixURI: phoenix:// registration lives in the Windows registry and is Windows-only." >&2
            echo "On Windows run Unregister-PhoenixURI.ps1 or Unregister-PhoenixURI.bat instead." >&2
            exit 1
        fi
        ;;
esac

ps1="$script_dir/Unregister-PhoenixURI.ps1"
if command -v powershell.exe >/dev/null 2>&1 && [ -f "$ps1" ]; then
    win_ps1=$(printf '%s' "$ps1" | sed 's|^/\([a-zA-Z]\)/|\1:/|; s|/|\\|g')
    win_exe=$(printf '%s' "$EXE" | sed 's|^/\([a-zA-Z]\)/|\1:/|; s|/|\\|g')
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$win_ps1" -Executable "$win_exe"
fi

if command -v reg.exe >/dev/null 2>&1; then
    win_exe=$(printf '%s' "$EXE" | sed 's|^/\([a-zA-Z]\)/|\1:/|; s|/|\\|g')
    key='HKCU\Software\Classes\phoenix'
    expected="\"$win_exe\" \"%1\""
    existing=$(reg.exe query "$key\\shell\\open\\command" /ve 2>/dev/null | sed -n 's/.*REG_SZ[[:space:]]*//p' | tr -d '\r')
    if [ -n "$existing" ]; then
        if [ "$existing" != "$expected" ]; then
            echo "Another installation owns phoenix://; refusing to remove its registration." >&2
            exit 1
        fi
        reg.exe delete "$key" /f >/dev/null
        echo "Removed Phoenix URI registration."
    fi
    exit 0
fi

echo "Unregister-PhoenixURI: neither powershell.exe nor reg.exe was found in PATH." >&2
exit 1
