<# 
Run this to set (new) passwords.
Passwords will be encrypted on disk
Passwords can only be decrypted by:
    The user that encrypted them,
    on the macine that they were encryped

This is not 100% secure but much better than
saving a plain-text password in a script
(there are times the password is plain-text in RAM)

#>

# Location that the encryped file gets saved to
$DeepFreezePasswordStore = 'DeepFreezePassword.txt'

Remove-Item $DeepFreezePasswordStore

$DeepFreezePassword = Read-Host "Enter Deep Freeze Password: " -AsSecureString

function EncryptPassword ($pw, $file_path) {
    $secureString = ConvertTo-SecureString -String $pw -AsPlainText -Force
    $encryptedSecret = ConvertFrom-SecureString -SecureString $secureString
    $encryptedSecret | Out-File -FilePath $file_path
}


EncryptPassword $DeepFreezePassword $DeepFreezePasswordStore

if (Test-Path $DeepFreezePasswordStore) {
    Write-Output 'Password Encrypted'
}


<# 
Decrypt example:
Requires Powershell 7+

$loadedEncryptedSecret = Get-Content -Path $DeepFreezePasswordStore
$loadedSecureString = ConvertTo-SecureString -String $loadedEncryptedSecret
$decryptedSecret = (New-Object PSCredential "user", $loadedSecureString).GetNetworkCredential().Password
Write-Output $decryptedSecret

#>