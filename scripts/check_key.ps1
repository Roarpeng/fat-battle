# Check if the deploy private key is passphrase-protected
$key = Join-Path $env:USERPROFILE '.ssh\id_ed25519_fatbattle'
$pub = ssh-keygen -y -P "" -f $key 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Output "KEY_UNPROTECTED"
    Write-Output $pub
} else {
    Write-Output "KEY_PROTECTED_OR_ERROR"
    Write-Output $pub
}
