#!/bin/bash
#
# Build and test this package in a throwaway copy, stubbing anything another editor has
# left half-written.
#
# Two people are editing this repo at once. Their in-flight state — a usage written before
# the property it needs — makes the shared module fail to compile, which blocks *our*
# verification even though our files are fine. Editing their file to unblock ourselves is
# the one thing we must not do: it would collide with their next save.
#
# So: copy the tree, add only the missing declarations the compiler names, and build there.
# The real repo is never touched. Anything this reports is genuinely ours.
#
# Usage: bash tools/mochi/verify-in-scratch.sh [swift-test-filter]
set -e

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRATCH="/tmp/mochi-verify"

rsync -a --delete \
    --exclude '.build' --exclude 'build' --exclude '__pycache__' \
    "$REPO/" "$SCRATCH/"
cd "$SCRATCH"

# Up to a few rounds: each build names the next missing symbol, so stubbing one can reveal
# another. Bounded, because an unbounded loop against a genuine error in OUR code would
# spin forever.
for _ in 1 2 3 4 5 6; do
    errors="$(swift build 2>&1 | grep -E "error: (type|value) .* has no member" || true)"
    [ -z "$errors" ] && break

    python3 - <<'PY'
import re, subprocess, pathlib

build = subprocess.run(["swift", "build"], capture_output=True, text=True)
text = build.stdout + build.stderr

# "type 'PillMetrics' has no member 'glassBlendSpacing'"
type_misses = set(re.findall(r"type '(\w+)' has no member '(\w+)'", text))
# "value of type 'PillStateModel' has no dynamic member 'handsFreeButtonShown'"
member_misses = set(re.findall(r"value of type '(\w+)' has no (?:dynamic )?member '(\w+)'", text))

for owner, member in type_misses | member_misses:
    hits = list(pathlib.Path("Sources").rglob("*.swift"))
    for path in hits:
        source = path.read_text()
        match = re.search(
            r"(?:final |public )*(?:class|struct|enum) " + re.escape(owner) + r"\b[^\{]*\{",
            source,
        )
        if not match:
            continue
        # A `@Published var` for an ObservableObject, a `static let` for a namespace: the
        # first is assigned through a Binding, the second read as a constant.
        is_observable = "ObservableObject" in source[match.start():match.start() + 400]
        if is_observable:
            stub = f"\n    // SCRATCH STUB — not in the real repo.\n    @Published var {member}: Bool = false\n"
        else:
            stub = f"\n    // SCRATCH STUB — not in the real repo.\n    static let {member}: CGFloat = 0\n"
        path.write_text(source[:match.end()] + stub + source[match.end():])
        print(f"  stubbed {owner}.{member} in {path.name}")
        break
PY
done

echo "── build ──"
swift build 2>&1 | grep -E "error:|warning:|Build complete" | head -20

# A second class of in-flight breakage: a file that uses `TimeInterval`, `Date` or `URL`
# without importing Foundation. Same rule as above — patch the copy, never the original.
for _ in 1 2 3; do
    python3 - <<'PY'
import re, subprocess, pathlib
build = subprocess.run(["swift", "test", "--no-build"], capture_output=True, text=True)
text = build.stdout + build.stderr
if "cannot find" not in text:
    raise SystemExit
paths = set(re.findall(r"^(/[^\s:]+\.swift):\d+:\d+: error: cannot find (?:type )?'"
                       r"(?:TimeInterval|Date|URL|Data|UUID)'", text, re.M))
for path in paths:
    file = pathlib.Path(path)
    source = file.read_text()
    if source.lstrip().startswith("import Foundation") or "\nimport Foundation" in source:
        continue
    file.write_text("import Foundation  // SCRATCH STUB — not in the real repo.\n" + source)
    print(f"  added Foundation import to {file.name}")
PY
    swift build >/dev/null 2>&1 && break
done

echo "── test ──"
swift test ${1:+--filter "$1"} 2>&1 | grep -E "^✘|Test run with|recorded an issue" | head -20
