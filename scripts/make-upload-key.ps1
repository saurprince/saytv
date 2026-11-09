# Creates the Android UPLOAD key for Google Play (Play App Signing keeps the real signing key). Refuses to overwrite an existing key.
# The key, its random password and key.properties go to a folder OUTSIDE the project; nothing secret is printed or stored in the project.
# SAYTV_SIGNING_DIR: where the key goes (default: saytv-signing in your user folder). KEYTOOL: path to keytool.exe if it is not on PATH.
# The certificate name below is the publisher's: change -dname to yours.
$dir = if ($env:SAYTV_SIGNING_DIR) { $env:SAYTV_SIGNING_DIR } else { Join-Path $env:USERPROFILE 'saytv-signing' }
$keytool = if ($env:KEYTOOL) { $env:KEYTOOL } else { (Get-Command keytool -ErrorAction Stop).Source }
$ks = Join-Path $dir 'upload.keystore'
$pwFile = Join-Path $dir 'store-password.txt'

if (Test-Path $ks) { Write-Host 'upload.keystore already exists: leaving it alone.'; exit 0 }
New-Item -ItemType Directory -Force $dir | Out-Null

$bytes = New-Object byte[] 24
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$pw = ([Convert]::ToBase64String($bytes)).Replace('+', 'A').Replace('/', 'B').Replace('=', '')
[System.IO.File]::WriteAllText($pwFile, $pw)

& $keytool -genkeypair -keystore $ks -alias upload -keyalg RSA -keysize 2048 -validity 10000 `
  -storetype PKCS12 -storepass:file $pwFile -keypass:file $pwFile `
  -dname 'CN=VISHWAVERSE LLP, OU=Mobile, O=VISHWAVERSE LLP, L=Pune, ST=Maharashtra, C=IN'
if ($LASTEXITCODE -ne 0) { Write-Host 'keytool failed'; exit 1 }

$props = @(
  "storePassword=$pw",
  "keyPassword=$pw",
  'keyAlias=upload',
  ('storeFile=' + $ks.Replace('\', '/'))
)
[System.IO.File]::WriteAllLines((Join-Path $dir 'key.properties'), $props)

Write-Host 'Created:'
Get-ChildItem $dir | Select-Object Name, Length | Format-Table | Out-String | Write-Host
Write-Host 'Certificate (no secrets):'
& $keytool -list -v -keystore $ks -alias upload -storepass:file $pwFile | Select-String 'Alias name|Owner|Valid from|SHA256|SHA-256'
