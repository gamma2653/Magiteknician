#!/usr/bin/env bash
# Builds the game for every platform it is released on, asks each build
# that can be run here whether it is whole, and packs them for download.
#
#   scripts/release/export.sh [folder]
#
# The builds go in <folder>, which is `build` unless you say otherwise,
# and the packed downloads in <folder>/release:
#
#   Magiteknician-v0.1.0-windows-x86_64.zip
#   Magiteknician-v0.1.0-linux-x86_64.tar.gz
#
# Set GODOT to the editor binary if `godot` isn't on your PATH. The export
# templates for that version of Godot have to be installed.
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot="${GODOT:-godot}"
out="${1:-build}"
name="Magiteknician"

if ! command -v "$godot" >/dev/null 2>&1; then
	echo "Could not find Godot at '$godot'. Set GODOT to the editor binary." >&2
	exit 2
fi

cd "$project_dir"
version="$(sed -n 's/^config\/version="\(.*\)"[[:space:]]*$/\1/p' project.godot)"
if [ -z "$version" ]; then
	echo "project.godot has no version." >&2
	exit 1
fi
echo "Building $name $version"

rm -rf "$out"
mkdir -p "$out/windows" "$out/linux" "$out/release"
# Keep Godot from looking through the builds for things to import.
: > "$out/.gdignore"

# Registers new scripts and imports new assets. Its own exit status is not
# meaningful; the exports below are what decide the result.
"$godot" --headless --path . --import >/dev/null 2>&1 || true

# build <preset> <file>
build() {
	echo "  exporting $1"
	# Godot has been known to report success for an export that wrote
	# nothing, so the file is what is believed.
	"$godot" --headless --path . --export-release "$1" "$2" >"$out/export-$1.log" 2>&1 || true
	if [ ! -s "$2" ]; then
		echo "The $1 export wrote nothing. What Godot said:" >&2
		cat "$out/export-$1.log" >&2
		exit 1
	fi
}

# check <file>: runs a build and asks it whether it is whole.
check() {
	echo "  checking $1"
	if ! "$1" --headless -- --self-check >"$1.check.log" 2>&1; then
		echo "$1 is not whole:" >&2
		cat "$1.check.log" >&2
		exit 1
	fi
	grep -E "^(Magiteknician|[0-9]+ spells|self-check)" "$1.check.log" | sed 's/^/    /'
	rm -f "$1.check.log"
}

# pack_zip <archive> <folder> <file>
pack_zip() {
	if command -v zip >/dev/null 2>&1; then
		(cd "$2" && zip -q -9 "$1" "$3")
	else
		# Git Bash has no zip. Python has one built in. On Windows the
		# name python3 can belong to a stub that only offers to install
		# Python, so each is tried before it is trusted.
		local python=""
		for candidate in python3 python; do
			if "$candidate" -c "import zipfile" >/dev/null 2>&1; then
				python="$candidate"
				break
			fi
		done
		if [ -z "$python" ]; then
			echo "Neither zip nor Python was found to pack the Windows build with." >&2
			exit 2
		fi
		(cd "$2" && "$python" -m zipfile -c "$1" "$3")
	fi
}

windows="$out/windows/$name.exe"
linux="$out/linux/$name.x86_64"
build "Windows" "$windows"
build "Linux" "$linux"
chmod +x "$linux"

# A build can only be run on the system it was built for.
case "$(uname -s)" in
	Linux*) check "$linux" ;;
	MINGW* | MSYS* | CYGWIN*) check "$windows" ;;
	*) echo "  neither build can be run on $(uname -s), so neither was checked" ;;
esac

release="$(cd "$out/release" && pwd)"
pack_zip "$release/$name-v$version-windows-x86_64.zip" "$out/windows" "$name.exe"
# tar, not zip, for Linux: it keeps the file executable.
tar -czf "$release/$name-v$version-linux-x86_64.tar.gz" -C "$out/linux" "$name.x86_64"

echo "Packed:"
ls -1 "$release" | sed 's/^/  /'
