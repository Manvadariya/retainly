#!/bin/bash
echo "Applying patch for image_picker_android plugin..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/../patches/image_picker_android_patch.txt"
PLUGIN_FILE="$HOME/AppData/Local/Pub/Cache/hosted/pub.dev/image_picker_android-0.8.13/android/src/main/java/io/flutter/plugins/imagepicker/ImagePickerPlugin.java"

if [ ! -f "$PLUGIN_FILE" ]; then
  echo "Error: Plugin file not found at $PLUGIN_FILE"
  exit 1
fi

patch -p1 "$PLUGIN_FILE" < "$PATCH_FILE"

if [ $? -ne 0 ]; then
  echo "Failed to apply patch."
  exit 1
fi

echo "Patch applied successfully."
exit 0
