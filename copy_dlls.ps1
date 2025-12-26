# PowerShell script to copy all necessary DLL and data files to the executable directory

# Set the base directory
$baseDir = "g:\javasdk\CascadeProjects\print_assistant_flutter"

# Set the target directories
$releaseDir = "$baseDir\build\windows\x64\runner\Release"
$debugDir = "$baseDir\build\windows\x64\runner\Debug"
$flutterEphemeralDir = "$baseDir\windows\flutter\ephemeral"
$pluginsDir = "$baseDir\build\windows\x64\plugins"
$flutterAssetsDir = "$baseDir\build\flutter_assets"

# Create the target directories if they don't exist
if (!(Test-Path -Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir -Force
}

if (!(Test-Path -Path $debugDir)) {
    New-Item -ItemType Directory -Path $debugDir -Force
}

# Create data directories
$releaseDataDir = "$releaseDir\data"
$debugDataDir = "$debugDir\data"

if (!(Test-Path -Path $releaseDataDir)) {
    New-Item -ItemType Directory -Path $releaseDataDir -Force
}

if (!(Test-Path -Path $debugDataDir)) {
    New-Item -ItemType Directory -Path $debugDataDir -Force
}

# Copy flutter_windows.dll to both directories
Copy-Item -Path "$flutterEphemeralDir\flutter_windows.dll" -Destination $releaseDir -Force
Copy-Item -Path "$flutterEphemeralDir\flutter_windows.dll" -Destination $debugDir -Force

# Copy plugin DLLs to both directories
$pluginDirectories = Get-ChildItem -Path $pluginsDir -Directory
foreach ($pluginDir in $pluginDirectories) {
    $releasePluginDir = "$pluginDir\Release"
    $debugPluginDir = "$pluginDir\Debug"
    
    if (Test-Path -Path $releasePluginDir) {
        Copy-Item -Path "$releasePluginDir\*.dll" -Destination $releaseDir -Force
    }
    
    if (Test-Path -Path $debugPluginDir) {
        Copy-Item -Path "$debugPluginDir\*.dll" -Destination $debugDir -Force
    }
}

# Copy icudtl.dat to data directories
Copy-Item -Path "$flutterEphemeralDir\icudtl.dat" -Destination $releaseDataDir -Force
Copy-Item -Path "$flutterEphemeralDir\icudtl.dat" -Destination $debugDataDir -Force

# Create flutter_assets subdirectories
$releaseFlutterAssetsDir = "$releaseDataDir\flutter_assets"
$debugFlutterAssetsDir = "$debugDataDir\flutter_assets"

if (!(Test-Path -Path $releaseFlutterAssetsDir)) {
    New-Item -ItemType Directory -Path $releaseFlutterAssetsDir -Force
}

if (!(Test-Path -Path $debugFlutterAssetsDir)) {
    New-Item -ItemType Directory -Path $debugFlutterAssetsDir -Force
}

# Copy all flutter assets to flutter_assets subdirectories
if (Test-Path -Path $flutterAssetsDir) {
    Copy-Item -Path "$flutterAssetsDir\*" -Destination $releaseFlutterAssetsDir -Recurse -Force
    Copy-Item -Path "$flutterAssetsDir\*" -Destination $debugFlutterAssetsDir -Recurse -Force
}

# Copy app.so for release build (AOT compiled)
$releaseAppSo = "$baseDir\build\windows\app.so"
if (Test-Path -Path $releaseAppSo) {
    Copy-Item -Path $releaseAppSo -Destination $releaseDataDir -Force
    Write-Host "Copied app.so to release data directory"
}

Write-Host "DLL and data files copied successfully!"
Write-Host "Release directory: $releaseDir"
Write-Host "Debug directory: $debugDir"
Write-Host "DLL files in Release directory:"
Get-ChildItem -Path "$releaseDir\*.dll" | Select-Object -Property Name
Write-Host "DLL files in Debug directory:"
Get-ChildItem -Path "$debugDir\*.dll" | Select-Object -Property Name
Write-Host "Data files in Release data directory:"
Get-ChildItem -Path $releaseDataDir | Select-Object -Property Name
Write-Host "Data files in Debug data directory:"
Get-ChildItem -Path $debugDataDir | Select-Object -Property Name
