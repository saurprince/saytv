# Analyze and test everything that does not need Gradle: core (Dart) and the app's Dart code (Flutter). Safe to run in the assistant's shell.
$env:PATH = 'C:\dev\flutter\bin;C:\dev\flutter\bin\cache\dart-sdk\bin;' + $env:PATH
$env:PUB_CACHE = 'C:\dev\pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$ErrorActionPreference = 'Continue'

Set-Location 'C:\dev\tvvoice\core'
Write-Host '=== core: pub get'
dart pub get 2>&1 | Select-Object -Last 3
Write-Host '=== core: analyze'
dart analyze 2>&1 | Select-Object -Last 15
Write-Host '=== core: test'
dart test 2>&1 | Select-Object -Last 15

Set-Location 'C:\dev\tvvoice\app'
Write-Host '=== app: pub get'
flutter pub get 2>&1 | Select-Object -Last 3
Write-Host '=== app: analyze'
flutter analyze 2>&1 | Select-Object -Last 20
Write-Host '=== app: test'
flutter test 2>&1 | Select-Object -Last 30
