#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
output_dir="$project_dir/build"
app_dir="$output_dir/ADHDGuard.app"

cd "$project_dir"
swift build -c "$configuration"

binary_path="$(swift build -c "$configuration" --show-bin-path)/ADHDGuard"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_path" "$app_dir/Contents/MacOS/ADHDGuard"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/ADHDGuard.icns" "$app_dir/Contents/Resources/ADHDGuard.icns"

codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
