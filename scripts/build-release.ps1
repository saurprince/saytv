# Builds the Android release files: a signed APK (to try on a phone or emulator) and the signed app bundle (what Google Play takes),
# checks what is inside them (verify-release.ps1), and only then copies them to the release folder with their SHA-256 sums.
#
# Why it looks like this (each point cost a broken build on this PC; the project path contains a space):
#  - Flutter's asset step works in a CLEAN build folder and leaves the asset folder EMPTY when it runs a second time in the same
#    build folder. An app without its assets hangs on its loading spinner. So the APK and the bundle are built in two separate clean builds.
#  - `flutter build appbundle` always fails here with "failed to strip debug symbols", so the bundle comes from Gradle directly.
#  - verify-release.ps1 looks inside both files; nothing is released unless it passes.
# Run it in a normal terminal: Gradle needs Java's loopback networking, which the assistant's restricted environment blocks.
# The upload key lives outside the project (see make-upload-key.ps1); SAYTV_KEY_PROPERTIES tells Gradle where its key.properties is.
# Paths: set these environment variables to match your PC; the defaults are the layout used by the author.
#   FLUTTER_HOME (default C:\dev\flutter), PUB_CACHE (default C:\dev\pub-cache), ANDROID_HOME (default: the Android Studio SDK folder),
#   SAYTV_SIGNING_DIR (the folder that holds key.properties; keep it OUTSIDE the project), SAYTV_RELEASE_DIR (where the finished files go),
#   SAYTV_ROOT (a short path to this project without spaces, default C:\dev\tvvoice: make a junction to the project folder).
$flutterHome = if ($env:FLUTTER_HOME) { $env:FLUTTER_HOME } else { 'C:\dev\flutter' }
$root = if ($env:SAYTV_ROOT) { $env:SAYTV_ROOT } else { 'C:\dev\tvvoice' }
$env:PATH = "$flutterHome\bin;$flutterHome\bin\cache\dart-sdk\bin;" + $env:PATH
if (-not $env:PUB_CACHE) { $env:PUB_CACHE = 'C:\dev\pub-cache' }
if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$signing = if ($env:SAYTV_SIGNING_DIR) { $env:SAYTV_SIGNING_DIR } else { Join-Path $env:USERPROFILE 'saytv-signing' }
$env:SAYTV_KEY_PROPERTIES = Join-Path $signing 'key.properties'
$log = "$root\build-release.log"
$stage = 'C:\dev\saytv-out'
$release = if ($env:SAYTV_RELEASE_DIR) { $env:SAYTV_RELEASE_DIR } else { Join-Path $env:USERPROFILE 'saytv-release-1.0.0' }
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage | Out-Null
Set-Location "$root\app"

'=== 1/2 clean + APK' | Tee-Object -FilePath $log
flutter clean 2>&1 | Tee-Object -FilePath $log -Append
flutter build apk --release 2>&1 | Tee-Object -FilePath $log -Append
$apk = $LASTEXITCODE
Copy-Item "$root\app\build\app\outputs\flutter-apk\app-release.apk" "$stage\SayTV-1.0.0-release.apk" -Force -ErrorAction SilentlyContinue

'=== 2/2 clean + app bundle (Gradle directly)' | Tee-Object -FilePath $log -Append
flutter clean 2>&1 | Tee-Object -FilePath $log -Append
flutter pub get 2>&1 | Tee-Object -FilePath $log -Append
& "$root\app\android\gradlew.bat" -p "$root\app\android" ':app:bundleRelease' '--console=plain' 2>&1 | Tee-Object -FilePath $log -Append
$aab = $LASTEXITCODE
Copy-Item "$root\app\build\app\outputs\bundle\release\app-release.aab" "$stage\SayTV-1.0.0-release.aab" -Force -ErrorAction SilentlyContinue

'=== verify' | Tee-Object -FilePath $log -Append
& "$root\scripts\verify-release.ps1" -Apk "$stage\SayTV-1.0.0-release.apk" -Aab "$stage\SayTV-1.0.0-release.aab" 2>&1 | Tee-Object -FilePath $log -Append
$ver = $LASTEXITCODE
if ($ver -eq 0) {
  New-Item -ItemType Directory -Force $release | Out-Null
  Copy-Item "$stage\SayTV-1.0.0-release.apk", "$stage\SayTV-1.0.0-release.aab" $release -Force
  Get-ChildItem $release -File | Where-Object { $_.Name -like 'SayTV-*' } |
    ForEach-Object { (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() + '  ' + $_.Name } | Set-Content "$release\SHA256.txt"
  Write-Host "Copied to $release"
}
Write-Host ('RELEASE BUILD FINISHED, apk exit code ' + $apk + ', appbundle exit code ' + $aab + ', verify exit code ' + $ver)
