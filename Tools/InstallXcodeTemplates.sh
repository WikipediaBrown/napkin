#!/usr/bin/env sh

# Configuration
XCODE_TEMPLATE_DIR=$HOME'/Library/Developer/Xcode/Templates/File Templates/napkin'
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_NAME="napkin"

# Copy RIBs file templates into the local RIBs template directory
xcodeTemplate () {
  echo "==> Removing previous napkin Xcode file templates."

  if [ -d "$XCODE_TEMPLATE_DIR" ]; then
    rm -R "$XCODE_TEMPLATE_DIR"
  fi
  mkdir -p "$XCODE_TEMPLATE_DIR"

  echo "==> Copying napkin Xcode file templates..."
  cp -R "$SCRIPT_DIR"/"$PROJECT_NAME"/*.xctemplate "$XCODE_TEMPLATE_DIR"
  cp -R "$SCRIPT_DIR"/"$PROJECT_NAME"/"$PROJECT_NAME".xctemplate/ownsView/* "$XCODE_TEMPLATE_DIR/$PROJECT_NAME.xctemplate/ownsViewwithXIB/"
  cp -R "$SCRIPT_DIR"/"$PROJECT_NAME"/"Launch $PROJECT_NAME".xctemplate/ownsView/* "$XCODE_TEMPLATE_DIR/Launch $PROJECT_NAME.xctemplate/ownsViewwithXIB/"
  cp -R "$SCRIPT_DIR"/"$PROJECT_NAME"/"$PROJECT_NAME".xctemplate/ownsView/* "$XCODE_TEMPLATE_DIR/$PROJECT_NAME.xctemplate/ownsViewwithStoryboard/"
  cp -R "$SCRIPT_DIR"/"$PROJECT_NAME"/"Launch $PROJECT_NAME".xctemplate/ownsView/* "$XCODE_TEMPLATE_DIR/Launch $PROJECT_NAME.xctemplate/ownsViewwithStoryboard/"
}

xcodeTemplate

echo "==> Success!"
echo "==> napkins have been set up. In Xcode, select 'New File...' to use napkin templates boss:)"