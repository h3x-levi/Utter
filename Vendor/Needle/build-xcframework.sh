#!/bin/bash
# Rebuilds Needle.xcframework from Cactus's arm64 libneedle.a plus the x86_64 stub, so the universal app links.
# libneedle.a, needle.h: huggingface.co/Cactus-Compute/needle3/resolve/93e88ede867e4311c39151285e74df513e4b835b/macos-arm64/
# Models/whistle.cact:   huggingface.co/Cactus-Compute/whistle/resolve/ca5287601bef25af26dcf2e1b2bdc0843a7c19e5/whistle.cact
set -euo pipefail
cd "$(dirname "$0")"
shasum -a 256 -c CHECKSUMS

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
clang -arch x86_64 -mmacosx-version-min=14.0 -O2 -I. -c needle_stub.c -o "$work/stub.o"
libtool -static -o "$work/stub.a" "$work/stub.o"
lipo -create libneedle.a "$work/stub.a" -output "$work/libneedle.a"
mkdir "$work/Headers"
cp needle.h "$work/Headers/"
printf 'module CNeedle {\n    header "needle.h"\n    export *\n}\n' > "$work/Headers/module.modulemap"

rm -rf Needle.xcframework
xcodebuild -create-xcframework -library "$work/libneedle.a" -headers "$work/Headers" -output Needle.xcframework
