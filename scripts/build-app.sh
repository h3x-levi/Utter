#!/bin/bash
#
# Utter — Complete DMG Build Script
# Builds, bundles, and packages everything into a ready-to-install DMG.
#
# Usage: bash scripts/build-app.sh [--keep-permissions] [--no-dmg] [--version=X.Y.Z]
#
# Every build resets system permissions, preferences and caches, and moves the app's
# data aside, so the DMG it produces installs like a first install. That is the point
# of building one here, and having to ask for it each time was friction with no payoff.
#
#   --keep-permissions   Skip that. Use it when you are iterating on the build itself
#                        and do not want to re-grant Microphone and Accessibility —
#                        Utter is signed with an Apple Development certificate, so a
#                        grant survives being replaced in /Applications, and this flag
#                        is how you take advantage of that.
#
#   --no-dmg             Build and sign the .app, then stop. For iterating on the app
#                        itself, and for packaging the installer separately.
#
# `--clean` is still accepted, and now does nothing beyond what happens anyway.
#
set -e

if [ -z "$SDKROOT" ] && [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

APP_NAME="Utter"

# The name of the built binary, i.e. the executable target in `Package.swift`.
#
# One variable because it is used three times — the `.build/release/` path, the
# filename copied into `Contents/MacOS/`, and `CFBundleExecutable` in the generated
# Info.plist — and it used to be three separate literals. Changing one and missing
# another produces a bundle that signs, verifies and reports success, then refuses to
# launch because `CFBundleExecutable` names a binary that is not in `Contents/MacOS`.
EXEC_NAME="Utter"

# The bundle identifier. Not reverse-DNS, deliberately: this is a personal
# open-source project with no domain behind it, and `com.utter.app` or `io.github.…`
# would each assert ownership of something the author does not own. The leading
# component is the project name — not a TLD — so the identifier claims nothing and
# still reads as one namespace. Every macOS use of it (TCC, `defaults`, saved state,
# caches) treats it as an opaque unique string.
#
# It has changed with each rename: `com.awsflow.app` in the internal-tool days, then
# `lumen.dictation.app`, now this. Changing it abandons
# everything macOS keys on it: Microphone, Accessibility, Screen Recording and system
# Audio Capture must be granted again, and all `UserDefaults` (onboarding, saved pill
# and companion positions, selected model tier, purged-model list) resets. Notes,
# dictation history and crash logs are unaffected — they live in
# `Application Support/Utter`, which is found by folder name, not by bundle id — and
# `AppDirectory` migrates both older folder names into it.
# Step 0 below resets all of that on every build anyway unless `--keep-permissions`.
BUNDLE_ID="utter.dictation.app"
# ─── Signing identity ──────────────────────────────────────────────────────────
# Prefer a real certificate over ad-hoc.
#
# This is not cosmetic. macOS binds a TCC grant (Accessibility, Microphone,
# Screen Recording) to the app's code signature. An ad-hoc signature has no team
# identity, so the grant is keyed to the *cdhash* — which changes on every build.
# Replacing Utter.app therefore silently invalidated every permission: System
# Settings still showed the toggle on, but it applied to the old binary, so
# hotkeys stopped working with no visible cause and no prompt.
#
# Signing with the Apple Development certificate gives a stable TeamIdentifier
# and a designated requirement, which is what lets a grant survive a reinstall.
SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -oE '"Apple Development: [^"]+"' | head -1 | tr -d '"')
if [ -z "$SIGN_ID" ]; then
    SIGN_ID="-"
    echo "   ⚠️  No Apple Development certificate found — signing ad-hoc."
    echo "      Permissions will need re-granting after every reinstall."
else
    echo "   ✓ Signing identity: $SIGN_ID"
fi

# Generate unique build ID
# ─── Flags ───
# Scanned across all arguments rather than testing `$1`, so `--keep-permissions
# --no-dmg` works in either order. `$1` is still honoured below for the permissions
# check, which is what every existing invocation passes.
KEEP_PERMISSIONS=0
MAKE_DMG=1
SET_VERSION=""
for arg in "$@"; do
    case "$arg" in
        --keep-permissions) KEEP_PERMISSIONS=1 ;;
        # Build and sign the .app and stop there. For iterating on the app itself,
        # and for anyone who packages the DMG separately.
        --no-dmg) MAKE_DMG=0 ;;
        # Build exactly this version instead of bumping the patch.
        #
        # The auto-increment below can only ever add one to the patch, so it cannot express a
        # major or minor bump at all: going from 2.0.105 to 3.0.0 is not reachable by adding 1
        # to anything. Without this the only routes were editing `.version` to 3.0.-1, which is
        # not a version, or accepting 3.0.1 and pretending that was the intent.
        --version=*) SET_VERSION="${arg#*=}" ;;
        --clean) ;;
        *) echo "⚠️  Unknown argument: $arg" ;;
    esac
done

# Version resolution. Order matters twice over, and both orderings were got wrong once:
#
#   * it must come AFTER the flag loop, because `--version=` sets `SET_VERSION`. Above the loop that
#     variable is still empty, so the flag was silently ignored and the patch auto-incremented —
#     a flag that appears to work, changes nothing, and leaves the version one higher than asked.
#   * it must come BEFORE the banner, the changelog call and `DMG_NAME`, all of which interpolate
#     `$VERSION`. Below them the DMG came out named `Utter-.dmg` and the changelog was handed an
#     empty version.
VERSION_FILE="$PROJECT_ROOT/.version"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    VERSION="1.1.0"
fi

if [ -n "$SET_VERSION" ]; then
    # Explicit version. Validated rather than trusted: this string becomes the DMG name, the
    # bundle's CFBundleShortVersionString and the changelog heading, and a typo in it is a
    # release nobody can find again.
    if [[ ! "$SET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "❌ --version must be X.Y.Z (got '$SET_VERSION')"
        exit 1
    fi
    VERSION="$SET_VERSION"
    echo "$VERSION" > "$VERSION_FILE"
    echo "📌 Version pinned to $VERSION (--version)"
else
    # Auto-increment patch version
    IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
    PATCH=$((PATCH + 1))
    VERSION="$MAJOR.$MINOR.$PATCH"
    echo "$VERSION" > "$VERSION_FILE"
fi

# Named here, not with the other paths above, because it interpolates `$VERSION` and the version is
# not known until the flags have been read. Assigning it earlier produced `Utter-.dmg`.
DMG_NAME="$APP_NAME-$VERSION.dmg"


BUILD_ID=$(date +%Y%m%d%H%M%S)
echo "$BUILD_ID" > "$PROJECT_ROOT/.buildid"
APP_DIR="build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     Utter Build System v$VERSION        ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Print changelog status (after the banner so it's visible).
if [ -f "$PROJECT_ROOT/scripts/update-changelog.py" ]; then
    CHANGELOG_STATUS=$(python3 "$PROJECT_ROOT/scripts/update-changelog.py" "$VERSION" 2>&1 || true)
    if [ -n "$CHANGELOG_STATUS" ]; then
        echo "📝 Release notes:"
        echo "$CHANGELOG_STATUS" | sed 's/^/   /'
        echo ""
    fi
fi


# ─── Step 0: Reset permissions and app data, unless asked not to ───
if [[ "$KEEP_PERMISSIONS" -eq 1 ]]; then
    echo "🔒 Keeping permissions, preferences and app data (--keep-permissions)"
    echo ""
else
    echo "🧹 Resetting permissions and app data for a fresh install..."

    # Move the app's data aside rather than deleting it.
    #
    # `Application Support/Utter` is not a cache: it holds `notes.json` — the only
    # copy of anything the user has dictated into Utter — plus their dictation history
    # and crash logs. This step used to `rm -rf` it, so testing a fresh install cost
    # you your notes, silently and every time. A timestamped move gives the same clean
    # slate and keeps the data one `mv` away.
    #
    # All three names are handled. The app has been renamed twice — `AWSFlow`, then `Lumen`,
    # now `Utter` — so a machine that has not launched the current build yet still has an older
    # folder that `AppDirectory` has not migrated.
    #
    # The `Lumen` and `AWSFlow` literals below are deliberate historical data, not leftover
    # branding, and must survive any future rename — they are the twin of
    # `AppDirectory.legacyNames`. Deleting one means a fresh-install test silently skips that
    # folder and leaves an older user's notes sitting un-backed-up while the app migrates them.
    # Do not "finish the job".
    for SUPPORT_DIR in "$HOME/Library/Application Support/Utter" \
                       "$HOME/Library/Application Support/Lumen" \
                       "$HOME/Library/Application Support/AWSFlow"; do
        if [ -d "$SUPPORT_DIR" ]; then
            BACKUP_DIR="$SUPPORT_DIR-backup-$(date +%Y%m%d%H%M%S)"
            mv "$SUPPORT_DIR" "$BACKUP_DIR"
            echo "   ✓ App data moved aside → $(basename "$BACKUP_DIR")"
        fi

        # Keep the three newest backups of THIS folder and delete the rest.
        #
        # Now that this runs on every build rather than on request, an unpruned scheme
        # would leave one directory per build sitting in Application Support forever. Three
        # is enough to recover from a mistake noticed a couple of builds later, and the
        # newest — the one holding whatever you had before this build — is always kept.
        #
        # Inside the loop, deliberately. It used to sit just after `done`, where
        # `$SUPPORT_DIR` still held the *last* iteration's value — so only the final name's
        # backups were ever pruned and the others accumulated one per build forever. It matters
        # more after each rename: the old names stop being created, while the current one is
        # the only one that grows.
        #
        # The `-n "$SUPPORT_DIR"` guard is belt-and-braces on an `rm -rf`: the loop can only
        # set it to one of three literal absolute paths, but an empty value would turn the glob
        # into a relative `-backup-*` and delete from the current directory.
        if [ -n "$SUPPORT_DIR" ]; then
            ls -dt "$SUPPORT_DIR"-backup-* 2>/dev/null | tail -n +4 | while read -r old; do
                rm -rf "$old"
                echo "   ✓ Pruned an older backup → $(basename "$old")"
            done
        fi
    done

    # Every service the app actually asks for. ScreenCapture was missing: meeting
    # capture was added after this block was written, so a "clean" run left Screen
    # Recording granted and the first-run path for it untested. The app does not use
    # the Speech framework (whisper runs locally), so SpeechRecognition is not listed.
    for service in Microphone Accessibility ScreenCapture; do
        tccutil reset "$service" $BUNDLE_ID >/dev/null 2>&1 || true
    done
    # Terminal too: a binary run straight from a shell inherits the *terminal's*
    # grants, not its own, so a dev run leaves them attached there. Note this touches
    # an app that is not ours — other tools you run from Terminal will ask again.
    for service in Microphone Accessibility; do
        tccutil reset "$service" com.apple.Terminal >/dev/null 2>&1 || true
    done

    defaults delete $BUNDLE_ID 2>/dev/null || true
    rm -rf ~/Library/Saved\ Application\ State/$BUNDLE_ID.savedState 2>/dev/null || true
    rm -rf ~/Library/Caches/$BUNDLE_ID 2>/dev/null || true
    echo "   ✓ Permissions reset, preferences and caches cleared"
    echo ""
fi

# ─── Step 1: Generate icon if needed ───
# Regenerate when the source art or the generator is newer than the .icns.
# "Exists" is not the same as "current": editing the artwork used to leave the old
# icon in place, so a new design silently never shipped.
ICON_STALE=0
if [ ! -f "AppIcon.icns" ]; then
    ICON_STALE=1
elif [ "Assets/AppIconSource.png" -nt "AppIcon.icns" ]; then
    ICON_STALE=1
elif [ "scripts/generate_icon.py" -nt "AppIcon.icns" ]; then
    ICON_STALE=1
fi

if [ "$ICON_STALE" -eq 1 ]; then
    echo "🎨 Generating app icon..."
    python3 scripts/generate_icon.py
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
    echo "   ✓ Icon generated"
else
    echo "🎨 Icon: AppIcon.icns (current)"
fi

# ─── Step 2: Generate sounds if missing or stale ───
# "Exists" is not the same as "current": editing the generator used to leave the
# old assets in place, so a sound redesign silently shipped the previous set.
# Regenerate whenever the script is newer than what it produced.
SOUNDS_STALE=0
if [ ! -f "Sounds/start.wav" ]; then
    SOUNDS_STALE=1
elif [ "scripts/generate_sounds.py" -nt "Sounds/start.wav" ]; then
    SOUNDS_STALE=1
fi

# The companion's voice is generated by its own script, so it needs its own check —
# otherwise a change to the cat sounds ships the previous set, which is the exact
# failure the UI-sound check above exists to prevent.
CAT_SOUNDS_STALE=0
if [ ! -f "Sounds/cat-meow.wav" ]; then
    CAT_SOUNDS_STALE=1
elif [ "scripts/generate_cat_sounds.py" -nt "Sounds/cat-meow.wav" ]; then
    CAT_SOUNDS_STALE=1
fi

if [ "$CAT_SOUNDS_STALE" -eq 1 ]; then
    echo "🐱 Generating the companion's voice..."
    python3 scripts/generate_cat_sounds.py
fi

for companion_sound in \
    Sounds/cat-meow-natural.wav \
    Sounds/cat-purr-natural.wav \
    Sounds/dog-bark.wav \
    Sounds/dog-pant.wav \
    Sounds/ATTRIBUTION.md; do
    if [ ! -f "$companion_sound" ]; then
        echo "❌ Required companion sound missing: $companion_sound"
        exit 1
    fi
done

if [ "$SOUNDS_STALE" -eq 1 ]; then
    echo "🔊 Generating sounds..."
    python3 scripts/generate_sounds.py
else
    echo "🔊 Sounds: $(ls Sounds/*.wav | wc -l | tr -d ' ') files (current)"
fi

# ─── Step 3: Confirm no credentials are bundled ───
# Utter is fully on-device. Nothing secret should ever enter the bundle; a
# stray .env here would ship a real key to every user.
if [ -f ".env" ]; then
    echo "❌ A .env file is present. Utter no longer uses any cloud service."
    echo "   Delete it before building — bundling it would leak credentials."
    exit 1
fi
echo "🔒 No credentials to bundle (fully on-device)"

# ─── Step 4: Build Swift binary (release) ───
echo ""
echo "🔨 Building $APP_NAME (release)..."

# Patch version into ConfigManager default
# Locate the file rather than hardcoding its path: Sources/ is grouped into
# subfolders, and a hardcoded "Sources/ConfigManager.swift" broke silently when
# the files moved.
CONFIG_MANAGER=$(find Sources -name "ConfigManager.swift" -type f | head -1)
if [ -z "$CONFIG_MANAGER" ]; then
    echo "❌ ConfigManager.swift not found under Sources/"
    exit 1
fi
sed -i '' "s/var appVersion: String = \".*\"/var appVersion: String = \"$VERSION\"/" "$CONFIG_MANAGER"

swift build -c release
if [ ! -f ".build/release/$EXEC_NAME" ]; then
    echo "❌ Build failed"
    exit 1
fi
echo "   ✓ Binary built"

# ─── Step 5: Create app bundle ───
echo ""
echo "📦 Creating app bundle..."
rm -rf build/
mkdir -p "$MACOS" "$RESOURCES"

# Binary
cp ".build/release/$EXEC_NAME" "$MACOS/$EXEC_NAME"
echo "   ✓ Binary copied"

# whisper.framework is linked via @rpath but SwiftPM only emits @loader_path
# (i.e. Contents/MacOS). Add the standard bundle framework location, or the app
# dies at launch with "Library not loaded: @rpath/whisper.framework".
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/$EXEC_NAME" 2>/dev/null || true
echo "   ✓ Framework search path added"

# Icon
cp AppIcon.icns "$RESOURCES/AppIcon.icns"
echo "   ✓ Icon bundled"

# Sounds
cp -r Sounds "$RESOURCES/Sounds"
echo "   ✓ Sounds bundled ($(ls Sounds/*.wav | wc -l | tr -d ' ') files)"

# Menu bar icon. A template image derived from the same artwork as the app icon,
# so the status item matches the app and macOS can tint it for light and dark.
# Regenerated on the same staleness rule as the app icon.
MENUBAR_STALE=0
if [ ! -f "MenuBarIcon/menubar-icon.png" ]; then
    MENUBAR_STALE=1
elif [ "Assets/AppIconSource.png" -nt "MenuBarIcon/menubar-icon.png" ]; then
    MENUBAR_STALE=1
elif [ "scripts/generate_menubar_icon.py" -nt "MenuBarIcon/menubar-icon.png" ]; then
    MENUBAR_STALE=1
fi
if [ "$MENUBAR_STALE" -eq 1 ]; then
    python3 scripts/generate_menubar_icon.py >/dev/null
fi
# User-authored companion packs. The four built-ins are rendered in Swift and must not
# be copied as PNG packs; SpritePackStore reserves those ids and always uses the code path.
if [ -d "Companions" ]; then
    # Copy the pack folders only. `Companions/README.md` documents how the packs are
    # regenerated, which belongs in the repository and not inside a shipped app — the
    # loader skips non-directories so it did no harm, but it referenced local source
    # paths and read as an oversight in the bundle.
    mkdir -p "$RESOURCES/Companions"
    find Companions -mindepth 1 -maxdepth 1 -type d \
        ! -name dog \
        ! -name panda \
        ! -name pixel-cat-gray \
        ! -name pixel-cat-orange \
        ! -name 'Dog sound' \
        ! -name 'Cat Sound effects' \
        -exec cp -R {} "$RESOURCES/Companions/" \;
    PACK_COUNT=$(find "$RESOURCES/Companions" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    echo "   ✓ Code-rendered companions: 4; optional image packs bundled: $PACK_COUNT"
fi

if find "$RESOURCES" -type f -iname '*.mp3' -print -quit | grep -q .; then
    echo "❌ Raw MP3 source audio reached the app bundle"
    exit 1
fi

if [ -d "MenuBarIcon" ]; then
    cp -r MenuBarIcon "$RESOURCES/MenuBarIcon"
    echo "   ✓ Menu bar icon bundled (template, adapts to light/dark)"
fi

# Speech models — shipped inside the bundle so transcription works offline on
# first launch with no download step. These are the bulk of the DMG size.
#   small = universal default, comfortable on 8 GB Macs, keeps the DMG small.
# Larger models are offered as downloads in the app instead of bundled: the
# weights are already quantized, so compressing them saves only ~7% and shipping
# every tier would have made the installer ~670 MB.
WHISPER_MODELS=("ggml-small.en-q5_1.bin")
REQUIRED_MODEL="ggml-small.en-q5_1.bin"
mkdir -p "$RESOURCES/Models"
for WM in "${WHISPER_MODELS[@]}"; do
    if [ -f "Models/$WM" ]; then
        cp "Models/$WM" "$RESOURCES/Models/$WM"
        echo "   ✓ Speech model bundled: $WM ($(du -h "Models/$WM" | cut -f1 | tr -d ' '))"
    elif [ "$WM" = "$REQUIRED_MODEL" ]; then
        echo "❌ Missing Models/$WM — the app cannot transcribe without it."
        echo "   Fetch it with:"
        echo "     curl -L -o Models/$WM \\"
        echo "       https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$WM"
        exit 1
    else
        echo "   ⚠️  Optional model missing, will be offered as a download: $WM"
    fi
done

# whisper.cpp dylib — SwiftPM links the prebuilt xcframework, so the built
# binary needs the framework alongside it inside the bundle.
WHISPER_FRAMEWORK=$(find .build -type d -name "whisper.framework" -path "*macos*" 2>/dev/null | head -1)
if [ -n "$WHISPER_FRAMEWORK" ]; then
    mkdir -p "$CONTENTS/Frameworks"
    cp -R "$WHISPER_FRAMEWORK" "$CONTENTS/Frameworks/"
    echo "   ✓ whisper.framework bundled"
else
    echo "⚠️  whisper.framework not found in .build — app may fail to launch"
fi

# Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION.$BUILD_ID</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$EXEC_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Utter needs microphone access to transcribe your speech into text.</string>
    <!-- Meeting capture, on the CoreAudio process-tap route (SystemAudioCapture ->
         ProcessTapCapture). Apple documents this key as "A message that tells people why
         your app is requesting access to capture system audio on macOS", macOS 14.2+, and
         it is what makes the "would like access to record your system audio" prompt appear
         instead of the request being dropped. Without it the tap route is dead and every
         meeting silently falls back to ScreenCaptureKit and Screen Recording.

         This is a *different* permission from Screen Recording: kTCCServiceAudioCapture,
         not kTCCServiceScreenCapture, with its own prompt. Screen Recording has no usage
         description key at all - it is granted in System Settings - which is why only one
         line appears here for two capture routes. -->
    <key>NSAudioCaptureUsageDescription</key>
    <string>Utter records the audio of a meeting so it can transcribe what the other participants say into a note. Audio is transcribed on this Mac and never saved.</string>
    <!-- No NSSpeechRecognitionUsageDescription: Utter does not use Apple's Speech
         framework (whisper runs locally), so advertising that capability would be
         a usage string for a permission the app never requests. -->
    <key>LSMinimumSystemVersion</key>
    <string>13.3</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <!-- Launch as a menu-bar app, with no Dock icon and no menu bar.

         Without this the app starts .regular and shows a Dock icon for the few frames
         before applicationDidFinishLaunching flips it to .accessory — visible on every
         launch, and wrong for anyone who has "Show in Dock" switched off. LSUIElement
         only sets the *initial* policy: setActivationPolicy(.regular) at runtime still
         adds the icon when the preference asks for it. -->
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF
echo "   ✓ Info.plist created"

# Ensure write permissions and clean any extended attributes or AppleDouble files before bundle signing
chmod -R u+w "$APP_DIR" 2>/dev/null || true
xattr -cr "$APP_DIR" 2>/dev/null || true
find build -name "._*" -delete 2>/dev/null || true

# If on a non-APFS volume (such as an external drive where macOS creates ._* files),
# stage in /tmp (APFS) for clean codesigning.
STAGING_DIR="/tmp/Utter-staging-$$"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
find "$STAGING_DIR" -name "._*" -delete 2>/dev/null || true

# Sign embedded frameworks first if present
if [ -d "$STAGING_DIR/$APP_NAME.app/Contents/Frameworks/whisper.framework" ]; then
    codesign --force --sign "$SIGN_ID" "$STAGING_DIR/$APP_NAME.app/Contents/Frameworks/whisper.framework" 2>/dev/null || true
fi

# Code sign the entire bundle. Fatal on failure, and verified.
if ! codesign --force --deep --sign "$SIGN_ID" "$STAGING_DIR/$APP_NAME.app"; then
    echo "   ❌ Signing the app bundle failed with identity: $SIGN_ID"
    rm -rf "$STAGING_DIR"
    exit 1
fi
if ! codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME.app" 2>/dev/null; then
    echo "   ❌ The signed bundle does not verify — permissions would not persist."
    rm -rf "$STAGING_DIR"
    exit 1
fi

rm -rf "$APP_DIR"
cp -R "$STAGING_DIR/$APP_NAME.app" "$APP_DIR"
rm -rf "$STAGING_DIR"
echo "   ✓ App bundle signed and verified"

# ─── Step 6: Create DMG ───
if [ "$MAKE_DMG" -eq 0 ]; then
    echo ""
    echo "✅ App built and signed: $APP_NAME.app  (--no-dmg, so no installer was made)"
    exit 0
fi

echo ""
echo "💿 Creating DMG installer..."

# ─── Who can actually open this installer ───
#
# Signing succeeding is not the same as the installer being openable elsewhere. Gatekeeper requires
# a *notarized* app for anything that arrives on another Mac with a quarantine flag, and notarization
# needs a `Developer ID Application` certificate — which a free Apple account cannot issue. An
# `Apple Development` identity signs perfectly well and is refused by Gatekeeper on every machine but
# this one, so the failure appears at the far end, to whoever was sent the file.
#
# The build is not stopped: an unnotarized DMG is a legitimate way to move the app between machines
# you control. This only makes the limitation visible here rather than in someone else's Downloads.
case "$SIGN_ID" in
    "Developer ID Application"*)
        echo "   ✓ Signed for distribution — notarize with notarytool and staple before sharing"
        ;;
    "-")
        echo "   ⚠️  Ad-hoc signed. This installer will be BLOCKED on every other Mac, and TCC"
        echo "      grants (Microphone, Accessibility) will not survive a reinstall even here."
        ;;
    *)
        echo "   ⚠️  Signed with a development identity, not Developer ID."
        echo "      This installer WILL be blocked on another Mac: Gatekeeper refuses anything"
        echo "      unnotarized, and notarization needs a paid Developer ID certificate."
        echo "      To open it elsewhere, see docs/INSTALLING-ON-ANOTHER-MAC.md"
        ;;
esac

# Generate the branded background PNG (1x + @2x retina).
echo "🎨 Rendering DMG background…"
python3 scripts/generate_dmg_background.py >/dev/null
BG_1X="build_assets/dmg-background.png"
BG_2X="build_assets/dmg-background@2x.png"
if [ ! -f "$BG_1X" ]; then
    echo "⚠️  Background generation failed, falling back to plain DMG"
fi

# Detach any volume already mounted under our own name.
#
# This is why a DMG occasionally came out with a plain white installer window.
# create-dmg records the background as a *volume-name-qualified* Finder path —
# "Utter:.background:dmg-background@2x.png" — so when a previous Utter.dmg is still
# mounted, that name is ambiguous: several mounted volumes answer to "Utter", the
# lookup can resolve to the stale one, and the new volume's icon-view settings end up
# with a background *colour* and no image. Finder then paints white, the PNG sits
# unused in .background/, and nothing reports a failure. Verified by inspecting
# .DS_Store: the white DMG had no `backgroundImageAlias` key at all.
#
# Detaching first removes the ambiguity rather than hoping the race falls our way.
for stale in /Volumes/"$APP_NAME" /Volumes/"$APP_NAME "[0-9]*; do
    [ -d "$stale" ] || continue
    echo "   ⚠️  Detaching a stale volume that would make the name ambiguous: $stale"
    hdiutil detach "$stale" -force -quiet 2>/dev/null || true
done

# Use create-dmg for a polished, non-resizable installer window.
# create-dmg handles: background, icon positions, window size, text size,
# and critically — sets the window to NOT be resizable.
rm -f "build/$DMG_NAME"
DMG_IS_PLAIN=0

if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "AppIcon.icns" \
        --window-pos 200 140 \
        --window-size 720 480 \
        --background "$BG_2X" \
        --icon-size 128 \
        --text-size 16 \
        --icon "${APP_NAME}.app" 188 250 \
        --app-drop-link 532 250 \
        --hide-extension "${APP_NAME}.app" \
        --no-internet-enable \
        --hdiutil-quiet \
        "build/$DMG_NAME" \
        "$APP_DIR" \
        2>&1 | grep -v "^$" || true
fi

if [ ! -f "build/$DMG_NAME" ]; then
    echo "   🎨 Building branded DMG via native macOS Finder layout..."
    APP_SIZE_MB=$(du -sm "$APP_DIR" | cut -f1)
    DMG_SIZE_MB=$(( APP_SIZE_MB + 150 ))
    rm -f "build/Utter-rw.dmg"
    hdiutil create -size "${DMG_SIZE_MB}m" -fs HFS+ -volname "$APP_NAME" -ov "build/Utter-rw.dmg" -quiet

    MOUNT_OUTPUT=$(hdiutil attach "build/Utter-rw.dmg" -readwrite -noverify -noautoopen)
    DEV_NAME=$(echo "$MOUNT_OUTPUT" | egrep '^/dev/' | head -n1 | awk '{print $1}')
    MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -n1)

    if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
        ditto "$APP_DIR" "$MOUNT_POINT/${APP_NAME}.app"
        ln -s /Applications "$MOUNT_POINT/Applications"
        mkdir -p "$MOUNT_POINT/.background"
        cp "$BG_1X" "$MOUNT_POINT/.background/dmg-background.png" 2>/dev/null || true
        cp "$BG_2X" "$MOUNT_POINT/.background/dmg-background@2x.png" 2>/dev/null || true

        if [ -f "AppIcon.icns" ]; then
            cp "AppIcon.icns" "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
            SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
        fi
        SetFile -a V "$MOUNT_POINT/.background" 2>/dev/null || true

        osascript -e "
            tell application \"Finder\"
                tell disk \"$APP_NAME\"
                    open
                    set current view of container window to icon view
                    set toolbar visible of container window to false
                    set statusbar visible of container window to false
                    set the bounds of container window to {200, 140, 920, 620}
                    set theViewOptions to the icon view options of container window
                    set arrangement of theViewOptions to not arranged
                    set icon size of theViewOptions to 128
                    set text size of theViewOptions to 16
                    try
                        set background picture of theViewOptions to file \".background:dmg-background.png\"
                    end try
                    set position of item \"${APP_NAME}.app\" of container window to {188, 250}
                    set position of item \"Applications\" of container window to {532, 250}
                    close
                    open
                    update without registering applications
                    delay 1
                end tell
            end tell
        " 2>/dev/null || true

        sync
        hdiutil detach "$DEV_NAME" -force -quiet 2>/dev/null || true
        sleep 1

        hdiutil convert "build/Utter-rw.dmg" -format UDZO -imagekey zlib-level=9 -o "build/$DMG_NAME" -ov -quiet
        rm -f "build/Utter-rw.dmg"
        echo "   ✓ Branded DMG created with custom background and layout"
    fi
fi

if [ ! -f "build/$DMG_NAME" ]; then
    echo "   ⚠️  Fallback to basic DMG layout"
    DMG_IS_PLAIN=1
    DMG_STAGING_DIR=$(mktemp -d)
    trap 'rm -rf "$DMG_STAGING_DIR"' EXIT
    ditto "$APP_DIR" "$DMG_STAGING_DIR/${APP_NAME}.app"
    ln -s /Applications "$DMG_STAGING_DIR/Applications"
    if ! hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$DMG_STAGING_DIR" \
        -format UDZO \
        -ov \
        "build/$DMG_NAME" \
        -quiet; then
        echo "❌ DMG creation failed"
        exit 1
    fi
    rm -rf "$DMG_STAGING_DIR"
    trap - EXIT
fi

# Recompress with LZMA. Quantized model weights are near-incompressible (LZMA
# saves only ~7% on the raw file), but it costs nothing at build time and macOS
# 10.15+ mounts ULMO natively.
if hdiutil convert "build/$DMG_NAME" -format ULMO -o "build/.$DMG_NAME.lzma" -quiet 2>/dev/null; then
    BEFORE=$(stat -f%z "build/$DMG_NAME")
    AFTER=$(stat -f%z "build/.$DMG_NAME.lzma.dmg" 2>/dev/null || stat -f%z "build/.$DMG_NAME.lzma")
    if [ -n "$AFTER" ] && [ "$AFTER" -lt "$BEFORE" ]; then
        mv -f "build/.$DMG_NAME.lzma.dmg" "build/$DMG_NAME" 2>/dev/null \
          || mv -f "build/.$DMG_NAME.lzma" "build/$DMG_NAME"
        echo "   ✓ Recompressed with LZMA ($(( (BEFORE - AFTER) / 1048576 )) MB saved)"
    else
        rm -f "build/.$DMG_NAME.lzma" "build/.$DMG_NAME.lzma.dmg"
    fi
fi

DMG_SIZE=$(du -h "build/$DMG_NAME" | cut -f1 | tr -d ' ')
if [ "$DMG_IS_PLAIN" -eq 1 ]; then
    echo "   ✓ DMG created ($DMG_SIZE) — plain Finder layout"
else
    echo "   ✓ DMG created ($DMG_SIZE) — non-resizable window"
fi

# Confirm the installer window will actually show its background.
#
# The detach above removes the one cause we identified, but the failure mode is what
# makes this worth a check: nothing in the build reports it, the PNG is present in the
# image, and the only symptom is a plain white window the first time a user opens the
# DMG. Reading the shipped .DS_Store is the only way to know before they do.
DMG_CHECK_MOUNT=$(mktemp -d)
if hdiutil attach "build/$DMG_NAME" -nobrowse -readonly -mountpoint "$DMG_CHECK_MOUNT" -quiet 2>/dev/null; then
    if [ ! -d "$DMG_CHECK_MOUNT/${APP_NAME}.app" ] || [ ! -L "$DMG_CHECK_MOUNT/Applications" ]; then
        echo "❌ The DMG mounted, but its app or Applications link is missing"
        hdiutil detach "$DMG_CHECK_MOUNT" -force -quiet 2>/dev/null || true
        exit 1
    elif [ "$DMG_IS_PLAIN" -eq 1 ]; then
        echo "   ✓ Plain installer contents verified"
    elif strings -a "$DMG_CHECK_MOUNT/.DS_Store" 2>/dev/null | grep -q "backgroundImageAlias"; then
        echo "   ✓ Installer background verified"
    else
        echo "   ⚠️  The DMG has no background image set — the installer window will be white."
        echo "      Check for other volumes named '$APP_NAME' and rebuild."
    fi
    hdiutil detach "$DMG_CHECK_MOUNT" -force -quiet 2>/dev/null || true
else
    echo "   ⚠️  Could not mount the DMG to verify its background"
fi
rmdir "$DMG_CHECK_MOUNT" 2>/dev/null || true

# ─── Summary ───
echo ""
echo "╔══════════════════════════════════════╗"
echo "║           Build Complete             ║"
echo "╠══════════════════════════════════════╣"
echo "║  App:  build/$APP_NAME.app"
echo "║  DMG:  build/$DMG_NAME"
echo "║  Size: $DMG_SIZE"
echo "║  Build: $BUILD_ID"
echo "╠══════════════════════════════════════╣"
echo "║  Install:                            ║"
echo "║  1. Double-click $DMG_NAME"
echo "║  2. Drag Utter to Applications       ║"
echo "║  3. Open from Spotlight or Launchpad ║"
echo "╚══════════════════════════════════════╝"
echo ""
