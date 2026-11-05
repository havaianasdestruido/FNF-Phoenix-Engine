#!/bin/sh
# Port of Register-PhoenixURI.ps1 - keep in sync with the .ps1 / .bat versions.
# phoenix:// is a Windows URL scheme (HKCU registry), so this script can only
# do its job on Windows. Under Git Bash / MSYS2 / Cygwin / WSL it delegates to
# reg.exe or Windows PowerShell; anywhere else it explains that and exits 1.
# Usage: Register-PhoenixURI.sh [path-to-FNF-Phoenix-Engine.exe]
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXE=${1:-"$script_dir/../FNF-Phoenix-Engine.exe"}

case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) ;;
    *)
        if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
            : # WSL: fall through, reg.exe / powershell.exe are reachable.
        else
            echo "Register-PhoenixURI: phoenix:// registration uses the Windows registry (HKCU\\Software\\Classes\\phoenix) and is Windows-only." >&2
            echo "On Windows run Register-PhoenixURI.ps1 or Register-PhoenixURI.bat instead." >&2
            exit 1
        fi
        ;;
esac

# Prefer the sibling PowerShell script: it is the canonical implementation.
ps1="$script_dir/Register-PhoenixURI.ps1"
if command -v powershell.exe >/dev/null 2>&1 && [ -f "$ps1" ]; then
    win_ps1=$(printf '%s' "$ps1" | sed 's|^/\([a-zA-Z]\)/|\1:/|; s|/|\\|g')
    win_exe=$(printf '%s' "$EXE" | sed 's|^/\([a-zA-Z]\)/|\1:/|; s|/|\\|g')
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$win_ps1" -Executable "$win_exe"
fi

if command -v reg.exe >/dev/null 2>&1; then
    win_exe=$(printf '%s' "$EXE" | sed 's|^/\([a-zA-Z]\)/|\1:/|; s|/|\\|g')
    [ -f "$EXE" ] || { echo "Select the Phoenix Engine executable: \"$EXE\" not found." >&2; exit 1; }
    case "$win_exe" in *[eE][xX][eE]) ;; *) echo "Select the Phoenix Engine executable." >&2; exit 1 ;; esac
    key='HKCU\Software\Classes\phoenix'
    expected="\"$win_exe\" \"%1\""
    existing=$(reg.exe query "$key\\shell\\open\\command" /ve 2>/dev/null | sed -n 's/.*REG_SZ[[:space:]]*//p' | tr -d '\r')
    if [ -n "$existing" ] && [ "$existing" != "$expected" ]; then
        echo "Another installation owns phoenix://; refusing to overwrite its registration." >&2
        exit 1
    fi
    reg.exe add "$key" /ve /d "URL:Phoenix Engine Protocol" /f >/dev/null
    reg.exe add "$key" /v "URL Protocol" /d "" /f >/dev/null
    reg.exe add "$key\\DefaultIcon" /ve /d "\"$win_exe\",0" /f >/dev/null
    reg.exe add "$key\\shell\\open\\command" /ve /d "$expected" /f >/dev/null
    echo "Registered phoenix:// for $win_exe. Re-run after moving the game."
    exit 0
fi

echo "Register-PhoenixURI: neither powershell.exe nor reg.exe was found in PATH." >&2
exit 1
