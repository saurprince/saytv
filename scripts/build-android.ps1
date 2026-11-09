# Builds the Android debug app. Run it in a normal terminal: Gradle needs Java's loopback networking,
# which is blocked inside the assistant's restricted command environment.
$env:PATH = 'C:\dev\flutter\bin;C:\dev\flutter\bin\cache\dart-sdk\bin;' + $env:PATH
$env:PUB_CACHE = 'C:\dev\pub-cache'
if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
Set-Location 'C:\dev\tvvoice\app'
flutter build apk --debug 2>&1 | Tee-Object -FilePath 'C:\dev\tvvoice\build-android.log'
Write-Host ('BUILD SCRIPT FINISHED, flutter exit code ' + $LASTEXITCODE)
