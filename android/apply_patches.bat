@echo off
echo Applying patch for image_picker_android plugin...

set PATCH_FILE=%~dp0\..\patches\image_picker_android_patch.txt
set PLUGIN_FILE=%USERPROFILE%\AppData\Local\Pub\Cache\hosted\pub.dev\image_picker_android-0.8.13\android\src\main\java\io\flutter\plugins\imagepicker\ImagePickerPlugin.java

if not exist "%PLUGIN_FILE%" (
  echo Error: Plugin file not found at %PLUGIN_FILE%
  exit /b 1
)

type "%PATCH_FILE%" | patch -p1 "%PLUGIN_FILE%"

if %ERRORLEVEL% NEQ 0 (
  echo Failed to apply patch.
  exit /b 1
)

echo Patch applied successfully.
exit /b 0
