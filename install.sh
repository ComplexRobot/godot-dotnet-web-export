#!/usr/bin/env bash
# Installs the web export files from an extracted release on macOS and Linux.
# This is the equivalent of the install.bat included in the release.
#
# Usage: bash install.sh [release-folder]
#
# The release folder defaults to the folder containing this script, and must contain web_release.zip,
# web_debug.zip and the nuget folder. The Godot version is read from the folder name
# (e.g. Godot_v4.7.2-stable_mono_web_export_win64). Set GODOT_VERSION (e.g. 4.7.2.stable) to override it.

set -euo pipefail

release_dir=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")}" && pwd)

for file in web_release.zip web_debug.zip nuget; do
  if [[ ! -e "$release_dir/$file" ]]; then
    echo "Error: '$release_dir/$file' not found. Pass the extracted release folder as the first argument." >&2
    exit 1
  fi
done

version=${GODOT_VERSION:-}
if [[ -z "$version" ]]; then
  if [[ $(basename "$release_dir") =~ ^Godot_v([0-9.]+)-([^_]+)_ ]]; then
    version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  else
    echo "Error: can't read the Godot version from the folder name '$(basename "$release_dir")'." >&2
    echo "Set it with GODOT_VERSION, e.g.: GODOT_VERSION=4.7.2.stable bash install.sh" >&2
    exit 1
  fi
fi

case "$(uname -s)" in
  Darwin) godot_data_dir="$HOME/Library/Application Support/Godot" ;;
  *) godot_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot" ;;
esac

template_dir="$godot_data_dir/export_templates/$version.mono"
nuget_dir="$HOME/.nuget/NuGet/nuget"

echo "Installing web export files for Godot $version from '$release_dir'..."
echo

echo "Copying export templates to '$template_dir'..."
mkdir -p "$template_dir"
cp -f "$release_dir/web_release.zip" "$release_dir/web_debug.zip" "$template_dir/"

echo
echo "Copying NuGet packages to '$nuget_dir'..."
mkdir -p "$nuget_dir"
cp -f "$release_dir"/nuget/* "$nuget_dir/"

if ! command -v dotnet > /dev/null; then
  echo
  echo "Error: 'dotnet' not found. Install the .NET SDK and run this script again." >&2
  exit 1
fi

# Run dotnet outside the release folder so its global.json doesn't pick the SDK.
cd "$(mktemp -d)"

echo
echo "Adding NuGet source..."
if dotnet nuget list source | grep -qF "$nuget_dir"; then
  echo "'$nuget_dir' is already a NuGet source."
else
  dotnet nuget add source "$nuget_dir" --name NugetSource || echo "Warning: couldn't add the NuGet source." >&2
fi

install_workload() {
  if ! dotnet workload install "$@"; then
    echo "Warning: 'dotnet workload install $*' failed. If the SDK is installed system-wide, run it again with sudo." >&2
  fi
}

# Projects target net9.0. The .NET 10 SDK needs wasm-tools-net9 for that; the .NET 9 SDK uses wasm-tools.
sdk_major=$(dotnet --version | cut -d. -f1)
echo
if (( sdk_major >= 10 )); then
  echo "Installing wasm-tools-net9 for the .NET $(dotnet --version) SDK..."
  install_workload wasm-tools-net9
else
  echo "Installing wasm-tools for the .NET $(dotnet --version) SDK..."
  install_workload wasm-tools
fi

# Also install wasm-tools for a .NET 9 SDK, which the included global.json selects if it is installed.
if (( sdk_major >= 10 )) && [[ -f "$release_dir/global.json" ]] && dotnet --list-sdks | grep -q '^9\.'; then
  echo
  echo "Installing wasm-tools for the .NET 9 SDK..."
  cp "$release_dir/global.json" .
  install_workload wasm-tools
fi

echo
echo "Installation complete!"
echo "If exporting fails with NETSDK1147 although the workload is listed, run 'dotnet workload repair'."
