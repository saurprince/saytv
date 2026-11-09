# Checks the release files before anyone uploads them. Prints PASS or FAIL for each check; exit code 1 if any failed.
# Safe to run in the assistant's shell (reads files only). Born from a real failure: an incremental build once produced an app with
# an EMPTY flutter_assets folder (it would hang on its loading spinner), so the contents are checked, not just the build's exit code.
param(
  [string]$Apk = 'C:\dev\tvvoice\app\build\app\outputs\flutter-apk\app-release.apk',
  [string]$Aab = 'C:\dev\tvvoice\app\build\app\outputs\bundle\release\app-release.aab',
  [string]$Pubspec = 'C:\dev\tvvoice\app\pubspec.yaml'
)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$bt = if ($env:BUILD_TOOLS) { $env:BUILD_TOOLS } else { Join-Path $sdk 'build-tools\36.1.0' }   # BUILD_TOOLS: folder of the build-tools version to use
$script:failed = 0
function Check($ok, $what) { if ($ok) { Write-Host "PASS  $what" } else { Write-Host "FAIL  $what"; $script:failed++ } }
function ZipHas($zip, $name) {
  $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
  try { return ($z.Entries | Where-Object { $_.FullName -eq $name -and $_.Length -gt 0 } | Measure-Object).Count -gt 0 } finally { $z.Dispose() }
}

Check (Test-Path $Apk) "APK exists"
Check (Test-Path $Aab) "AAB exists"
if (-not ((Test-Path $Apk) -and (Test-Path $Aab))) { exit 1 }

foreach ($f in 'assets/apps.json', 'assets/catalog.json', 'AssetManifest.bin', 'FontManifest.json') {
  Check (ZipHas $Apk "assets/flutter_assets/$f") "APK contains flutter_assets/$f"
  Check (ZipHas $Aab "base/assets/flutter_assets/$f") "AAB contains flutter_assets/$f"
}
Check (ZipHas $Apk 'lib/arm64-v8a/libapp.so') 'APK contains the compiled app (arm64)'
Check (ZipHas $Aab 'base/lib/arm64-v8a/libapp.so') 'AAB contains the compiled app (arm64)'

$version = ((Get-Content $Pubspec | Where-Object { $_ -match '^version:' }) -replace 'version:\s*', '').Trim()
$name, $code = $version.Split('+')
$badging = & "$bt\aapt2.exe" dump badging $Apk
Check ($badging -match "package: name='com.visswaverse.voiceremote' versionCode='$code' versionName='$name'") "APK is com.visswaverse.voiceremote $name ($code), as in pubspec.yaml"
$target = [int](([regex]::Match(($badging -join "`n"), "targetSdkVersion:'(\d+)'")).Groups[1].Value)
Check ($target -ge 35) "target SDK $target is at least 35"
Check (($badging -join "`n") -match "application-label:'SayTV'") 'app label is SayTV'

$cert = (& "$bt\apksigner.bat" verify --print-certs $Apk 2>&1) -join "`n"
Check ($cert -match 'CN=VISHWAVERSE LLP') 'APK is signed with the upload key (not the debug key)'
$bad = & "$bt\zipalign.exe" -c -P 16 -v 4 $Apk 2>&1 | Select-String 'lib/' | Where-Object { $_.Line -notmatch '\(OK' }
Check (-not $bad) 'native libraries are 16 KB aligned'

if ($script:failed -eq 0) { Write-Host 'ALL CHECKS PASSED'; exit 0 } else { Write-Host "$($script:failed) CHECK(S) FAILED"; exit 1 }
