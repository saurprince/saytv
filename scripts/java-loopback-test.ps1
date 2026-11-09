# Does Java's internal loopback connection work in this shell? (Gradle needs it.) Read-only: runs a tiny already-compiled test class.
$d = Join-Path $env:TEMP 'looptest'
$jdks = @(
  'C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot\bin',
  'C:\Program Files\Android\Android Studio\jbr\bin'
)
foreach ($b in $jdks) {
  if (Test-Path (Join-Path $b 'java.exe')) {
    Write-Host ("JDK: " + $b)
    & (Join-Path $b 'java.exe') -cp $d P
  }
}
