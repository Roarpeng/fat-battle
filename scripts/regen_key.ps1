# Regenerate deploy key WITHOUT passphrase (previous key got literal '""' as passphrase)
$ErrorActionPreference = 'Stop'
$key = Join-Path $env:USERPROFILE '.ssh\id_ed25519_fatbattle'
if (Test-Path $key) { Remove-Item $key -Force }
if (Test-Path "$key.pub") { Remove-Item "$key.pub" -Force }

# Feed two newlines as empty passphrase (this ssh-keygen rejects -N empty string)
$newlines = "`n`n"
$newlines | & ssh-keygen -t ed25519 -f $key -C 'fatbattle-deploy' -q
if ($LASTEXITCODE -ne 0) { Write-Output "KEYGEN_FAILED"; exit 1 }

Write-Output "=== PUBLIC KEY ==="
Get-Content "$key.pub"
Write-Output "=== ENCRYPTED CHECK ==="
Select-String -Path $key -Pattern 'ENCRYPTED' -SimpleMatch | Out-Null
if ($?) { Write-Output "STILL_ENCRYPTED" } else { Write-Output "UNENCRYPTED_OK" }
