#!/bin/sh
# Port of windows-msvc.bat - keep in sync with windows-msvc.bat / .ps1.
# Installs Microsoft Visual Studio Community (Windows-only). From Git Bash /
# MSYS2 / Cygwin / WSL it downloads and launches the same installer; anywhere
# else it explains that and exits 1.
case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) ;;
    *)
        if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
            : # WSL: Windows executables are reachable.
        else
            echo "windows-msvc: Visual Studio Community can only be installed on Windows." >&2
            echo "On Windows run windows-msvc.bat or windows-msvc.ps1 instead." >&2
            exit 1
        fi
        ;;
esac
command -v curl >/dev/null 2>&1 || command -v curl.exe >/dev/null 2>&1 || { echo "windows-msvc: curl was not found in PATH." >&2; exit 1; }
CURL=$(command -v curl.exe 2>/dev/null || command -v curl)
cd "$(dirname "$0")/.." || exit 1
echo "Installing Microsoft Visual Studio Community (Dependency)"
url="https://download.visualstudio.microsoft.com/download/pr/3105fcfe-e771-41d6-9a1c-fc971e7d03a7/8eb13958dc429a6e6f7e0d6704d43a55f18d02a253608351b6bf6723ffdaf24e/vs_Community.exe"
"$CURL" -# -O "$url"
./vs_Community.exe --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 -p
rm -f vs_Community.exe
echo "Finished."
printf "Press Enter to continue..."
read -r _ || true
