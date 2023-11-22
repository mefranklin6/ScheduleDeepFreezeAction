<# 

Run this to set (new) passwords.
Passwords will be encrypted on disk
Passwords can only be decrypted by:
    The user that encrypted them,
    on the macine that they were encryped

This is not 100% secure but much better than
saving a plain-text password in a script
(there are times the password is plain-text in RAM,
and this encrypted password can be decrypted back to plain-text)

#>

# Location that the encryped file gets saved to
$DeepFreezePasswordStore = 'C:\Temp\DeepFreezePassword.txt'

Remove-Item $DeepFreezePasswordStore

$DeepFreezePassword = Read-Host "Enter Deep Freeze Password: "
# -AsSecureString can not be used because the Deep Freeze CLI does not support it.

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