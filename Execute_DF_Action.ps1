Param(
    [Parameter(Mandatory = $true)]
    [string]$PC,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Frozen', 'Thawed', 'Thawed and Locked')]
    [string]$DesiredState,

    [Parameter(Mandatory = $true)]        
    [ValidateScript({ Test-Path $_ })]  #Ignore intellisense warnings
    [string]$EncryptedPasswordLocation, # This is not the password but the encrypted file location

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$LogLocation,

    [Parameter(Mandatory = $true)]
    [ValidateSet('True', 'False')]
    [string]$Force
)

$LogLocation = "$LogLocation" + "/$PC.txt"
Write-Output "Log Location: $LogLocation"


function Log ($message) {
    $LogTime = Get-Date -DisplayHint Time
    $LogTime = $LogTime.ToString()
    Write-Output $message
    $LogStr = "$LogTime  -  $PC  -  $message"
    $LogStr | Out-File "$script:LogLocation" -Append
}


# Python can only send strings to Powershell
if ($Force -like 'True') {
    $Force = $true
}
else {
    $Force = $false
}

Log '--------------------------------------------------------------------------'
Log "INFO: $PC"
Log "INFO: Desired State: $DesiredState"
Log "DEBUG: Encrypted Password Location $EncryptedPasswordLocation"
Log "INFO: Force Flag: $Force"


#### Verifications ####


if ($PSVersionTable.PSVersion.Major -lt 7) {
    $EncryptedPasswordLocation = $null
    Log "FATAL: Script requires Powershell 7 or above"
    Exit 1
}

if (!(Test-Connection -ComputerName $PC -Count 1)) {
    Log "FATAL: $PC failed Test-Connection"
    Exit 1
}


$CommandLookupTable = @{
    'Frozen'            = '/BOOTFROZEN';
    'Thawed'            = '/BOOTTHAWED';
    'Thawed and Locked' = '/BOOTTHAWEDNOINPUT'            
}

if (!($DesiredState -in $CommandLookupTable.Keys)) {
    Log "FATAL: $DesiredState is not a valid state"
    Log "INFO: Valid States are $CommandLookupTable.Keys"
    Exit 1
}


try {
    $DFStatus = Invoke-Command -ComputerName $PC -ScriptBlock {
        (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Faronics\Deep Freeze 6\" -Name "DF Status" -ErrorAction Stop)."DF Status"
    }
} 
catch {
    $DFStatus = $null
}


if ($DFStatus -eq $DesiredState) {
    Log "ERROR: $PC is already $DFstatus"
    Exit 1
}
elseif ($null -eq $DFStatus) {
    Log "FATAL: No Deep Freeze detected on $PC"
    Exit 1
}

$CheckProcesses = $true

if ($Force -ne $true) {
    
    try {
        $LoggedInUser = (Get-CimInstance -Class win32_computersystem -ComputerName $PC).username -split '\\' | Select-Object -Last 1
    }
    catch {
        $LoggedInUser = $null
    }
    
    switch ($LoggedInUser) {
        $null { Log 'FATAL: Can not find logged-in user'; Exit 1 }
        '' { Log "INFO: No one is logged in to $PC" ; $CheckProcesses = $false }
        default { Log "WARNING: $LoggedInUser Logged in to $PC" }
    }
}
    
if ($Force -ne $true -and $CheckProcesses -ne $false) {
    $AllProcesses = Invoke-Command -ComputerName $PC -ScriptBlock {
        Get-Process
    }

    # Process Name = Common Name
    # Don't add Edge, it's almost always running
    $ProcessTable = @{
        'Chrome'   = 'Chrome';
        'Firefox'  = 'Firefox';
        'POWERPNT' = 'PowerPoint';
        'Teams'    = 'Teams';
        'Zoom'     = 'Zoom'
    }

    $ProcessAlerts = @()

    foreach ($running_process in $AllProcesses) {
        if ($ProcessTable.ContainsKey($running_process.ProcessName)) {
            $FoundProcess = $ProcessTable[$running_process.ProcessName]
            if ($FoundProcess -in $ProcessAlerts) {
                continue
            }
            else {
                $ProcessAlerts += $FoundProcess
            }
        }
    }

    if ($ProcessAlerts.Count -gt 0) {
        Log "INFO: Found running process(es): $ProcessAlerts"
        Log 'FATAL: $Force set to $false and PC may be in use, exiting'
        Exit 1
    }
}


#### Load DF Password ####

if (Test-Path $EncryptedPasswordLocation) {
    $loadedEncryptedPassword = Get-Content -Path $EncryptedPasswordLocation
    $loadedSecureString = ConvertTo-SecureString -String $loadedEncryptedPassword
    $DF_Password = (New-Object PSCredential "user", $loadedSecureString).GetNetworkCredential().Password
}
else {
    Log "FATAL: Could not find encrypted password at $EncryptedPasswordLocation"
    Log "ERROR: Please run PasswordEncrypter.ps1 or fix the path"
    Exit 1
}

#### Send DF Commands ####

$Command = $CommandLookupTable[$DesiredState]

Log "DEBUG: Sending Command: $Command"
Log "INFO: Console may show an error when PC Reboots. This is normal"


Invoke-Command -ComputerName "$PC" -ScriptBlock {
    C:\Windows\SysWOW64\.\DFC.exe "$using:DF_Password" "$using:Command"
} # Command will hang while PC prepares to reboot, 
# then will raise OpenError as connection is lost during the reboot

Remove-Variable -Name DF_Password


$PingTestAttempts = 0
function TestOnlineRecurse {
    try { 
        Test-Connection -ComputerName $PC -Count 1 -ErrorAction Stop
        Log "INFO: $PC Online after reboot"
    } 
    catch {
        Log "WARNING: $PC not detected online.  Will try again in 15 seconds"
        $script:PingTestAttempts += 1
        Log "INFO: Ping Attempt $script:PingTestAttempts of 5"
        if ($script:PingTestAttempts -lt 5) {
            Start-Sleep -Seconds 15
            TestOnlineRecurse
        }
        else {
            Log "FATAL: $PC did not come back online"
            Exit 1
        }
    }
}


$WinRM_TestAttempts = 0
function TestRemotingRecurse {
    $ReturnsZero = Invoke-Command -ComputerName $PC { 0 }
    if ($ReturnsZero -ne '0') {
        Log "WARNING: WinRM on $PC not ready yet.  Will try again in 15 seconds"
        $script:WinRM_TestAttempts += 1
        Log "INFO: WinRM Attempt $script:WinRM_TestAttempts of 5"
        if ($script:WinRM_TestAttempts -lt 5) {
            ping $PC -n 1 # refresh the IP / ARP table
            Start-Sleep -Seconds 15
            TestRemotingRecurse
        }
        else {
            Log "FATAL: $PC WinRM did not recover"
            Exit 1
        }
    }
    else {
        Log "INFO: $PC WinRM tested sucessfully"
    }
}

Start-Sleep -Seconds 60
Log 'DEBUG: Sleeping for 60 to wait for reboot'

TestOnlineRecurse
TestRemotingRecurse


#### Verify DF Status ####

$DFStatus =
Invoke-Command -ComputerName $PC -ScriptBlock {
    (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Faronics\Deep Freeze 6\" -Name "DF Status")."DF Status"
}

if ($DFStatus -eq $DesiredState) {
    Log "INFO: Sucessfully rebooted $DFStatus"
    Exit 0
}
else {
    Log "WARNING: Could not verify operation.  State is $DFStatus, Desired State is $DesiredState"
    Log "INFO: Password may be wrong"
    Log 'INFO: PC must be frozen first in order to boot into Thawed or Thawed and Locked states'
    Exit 1
}

