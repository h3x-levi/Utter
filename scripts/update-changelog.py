#!/usr/bin/env python3
"""
Insert a release entry into both WhatsNewView.swift and CHANGELOG.md
if the given version doesn't already have one. Idempotent — re-running for the
same version is a no-op so you can edit the stub between builds without losing
your manual changes.

Usage:
    python3 scripts/update-changelog.py <version>
    python3 scripts/update-changelog.py <version> --bullet "Did a thing" --bullet "Did another"

If no --bullet flags are passed, a single default bullet is used. The default
is intentionally honest so portfolio-grade releases don't ship with a
generated-looking changelog — edit the entry manually for real releases.
"""
from __future__ import annotations
import argparse
import datetime
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
def _find(name):
    """Locate a source file under Sources/, wherever it has been filed.

    Sources/ is grouped into subfolders, so a hardcoded path breaks whenever a
    file moves — which it did, silently, leaving the release notes unwritten.
    """
    for base, _dirs, files in os.walk(os.path.join(ROOT, "Sources")):
        if name in files:
            return os.path.join(base, name)
    return os.path.join(ROOT, "Sources", name)


WHATS_NEW = _find("WhatsNewView.swift")
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")



def month_year(now: datetime.datetime | None = None) -> str:
    now = now or datetime.datetime.now()
    return now.strftime("%B %Y")


# ─── WhatsNewView.swift ────────────────────────────────────────────────────

def whats_new_entry(version: str, date: str, bullets: list[str]) -> str:
    """Build the Swift VersionEntry literal for insertion."""
    indented_bullets = ",\n".join(
        f'            {swift_string(b)}' for b in bullets
    )
    return (
        f'        Release(version: "{version}", date: "{date}", highlights: [\n'
        f'{indented_bullets},\n'
        f'        ]),\n'
    )


def swift_string(s: str) -> str:
    """Quote a Python string as a Swift string literal."""
    escaped = (
        s.replace("\\", "\\\\")
         .replace('"', '\\"')
    )
    return f'"{escaped}"'


def update_whats_new(version: str, date: str, bullets: list[str]) -> str:
    if not os.path.exists(WHATS_NEW):
        return f"⚠️  {WHATS_NEW} not found — skipping"

    with open(WHATS_NEW, "r", encoding="utf-8") as f:
        content = f.read()

    # Already documented? Match `id: "X.X.X"` exactly.
    pattern = rf'version:\s*"{re.escape(version)}"'
    if re.search(pattern, content):
        return f"✓ WhatsNewView already has v{version}"

    # Insert immediately after the array opening: `versions: [VersionEntry] = [`
    anchor = "static let releases: [Release] = ["
    idx = content.find(anchor)
    if idx == -1:
        return f"⚠️  Could not find versions array in {WHATS_NEW}"

    insert_at = idx + len(anchor) + 1  # +1 to land after the trailing newline
    # If there's no newline after the bracket, add one.
    if insert_at - 1 >= len(content) or content[insert_at - 1] != "\n":
        prefix = content[:idx + len(anchor)] + "\n"
        suffix = content[idx + len(anchor):]
        content = prefix + suffix
        insert_at = idx + len(anchor) + 1

    entry = whats_new_entry(version, date, bullets)
    new_content = content[:insert_at] + entry + content[insert_at:]

    with open(WHATS_NEW, "w", encoding="utf-8") as f:
        f.write(new_content)

    return f"✓ WhatsNewView: inserted v{version} stub"


# ─── CHANGELOG.md ──────────────────────────────────────────────────────────

def changelog_entry(version: str, date: str, bullets: list[str]) -> str:
    body = "\n".join(f"- {b}" for b in bullets)
    return f"## [{version}] - {date}\n\n{body}\n\n"


def update_changelog(version: str, date: str, bullets: list[str]) -> str:
    if not os.path.exists(CHANGELOG):
        return f"⚠️  {CHANGELOG} not found — skipping"

    with open(CHANGELOG, "r", encoding="utf-8") as f:
        content = f.read()

    # Already documented? Match the version header.
    pattern = rf'^##\s+\[{re.escape(version)}\]'
    if re.search(pattern, content, flags=re.MULTILINE):
        return f"✓ CHANGELOG already has v{version}"

    # Insert before the FIRST `## [` header. If none exists, append after
    # the document intro.
    match = re.search(r'^##\s+\[', content, flags=re.MULTILINE)
    new_block = changelog_entry(version, date, bullets)
    if match:
        idx = match.start()
        new_content = content[:idx] + new_block + content[idx:]
    else:
        # Append at the end with a blank line separator if needed.
        sep = "" if content.endswith("\n\n") else ("\n" if content.endswith("\n") else "\n\n")
        new_content = content + sep + new_block

    with open(CHANGELOG, "w", encoding="utf-8") as f:
        f.write(new_content)

    return f"✓ CHANGELOG: inserted v{version} stub"


# ─── Main ──────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="Target release version, e.g. 2.0.7")
    parser.add_argument(
        "--bullet",
        action="append",
        default=None,
        help="Add a bullet point (can be passed multiple times). "
             "If omitted, a default placeholder bullet is used.",
    )
    parser.add_argument(
        "--date",
        default=None,
        help='Override the date string (defaults to "<Month> <Year>").',
    )
    args = parser.parse_args()

    if not args.bullet:
        print(f"No release notes for v{args.version}; What's New and CHANGELOG left unchanged")
        return 0
    bullets = args.bullet
    date = args.date or month_year()

    print(update_whats_new(args.version, date, bullets))
    print(update_changelog(args.version, date, bullets))
    return 0


if __name__ == "__main__":
    sys.exit(main())
