#!/usr/bin/env sh
set -eu

# Configuration
XCODE_TEMPLATE_DIR=$HOME'/Library/Developer/Xcode/Templates/File Templates/napkin'
# Resolve this script's directory portably. The previous version used
# ${BASH_SOURCE[0]} under a `#!/usr/bin/env sh` shebang — empty under a
# real POSIX sh, which silently made SCRIPT_DIR the caller's cwd and copied
# the wrong (or no) files while still reporting success. `$0` + dirname
# works under both sh and bash, from any working directory. (Analogous to
# uber/ribs-ios#37 — install scripts that fail silently on an unexpected
# environment.)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_NAME="napkin"

# Copy napkin file templates into the local napkin template directory
xcodeTemplate () {
  SRC="$SCRIPT_DIR/$PROJECT_NAME"
  if [ ! -d "$SRC" ]; then
    echo "==> ERROR: template source not found at: $SRC" >&2
    echo "    Run this script from a checkout of the napkin repo." >&2
    exit 1
  fi

  echo "==> Removing previous napkin Xcode file templates."
  if [ -d "$XCODE_TEMPLATE_DIR" ]; then
    rm -R "$XCODE_TEMPLATE_DIR"
  fi
  mkdir -p "$XCODE_TEMPLATE_DIR"

  echo "==> Copying napkin Xcode file templates..."
  # With `set -e` any failed cp (bad permissions, missing source, read-only
  # destination) aborts the script with a non-zero status instead of
  # falling through to "==> Success!".
  cp -R "$SRC"/*.xctemplate "$XCODE_TEMPLATE_DIR"
  cp -R "$SRC/$PROJECT_NAME.xctemplate/ownsView/"* "$XCODE_TEMPLATE_DIR/$PROJECT_NAME.xctemplate/ownsViewwithXIB/"
  cp -R "$SRC/Launch $PROJECT_NAME.xctemplate/ownsView/"* "$XCODE_TEMPLATE_DIR/Launch $PROJECT_NAME.xctemplate/ownsViewwithXIB/"
  cp -R "$SRC/$PROJECT_NAME.xctemplate/ownsView/"* "$XCODE_TEMPLATE_DIR/$PROJECT_NAME.xctemplate/ownsViewwithStoryboard/"
  cp -R "$SRC/Launch $PROJECT_NAME.xctemplate/ownsView/"* "$XCODE_TEMPLATE_DIR/Launch $PROJECT_NAME.xctemplate/ownsViewwithStoryboard/"

  # Strip cruft that can exist in a working copy: macOS metadata and Xcode's
  # " 2" duplicate files. These are git-ignored (see .gitignore `* 2.*`) so they
  # never show in `git status`, but `cp -R` would otherwise install them and
  # Xcode would emit them as duplicate sources (e.g. a stray `LaunchComponent 2`).
  find "$XCODE_TEMPLATE_DIR" \( -name "* 2.*" -o -name ".DS_Store" \) -delete
}

xcodeTemplate

echo "==> Success!"
echo "==> napkins have been set up. In Xcode, select 'New File...' to use napkin templates boss:)"
