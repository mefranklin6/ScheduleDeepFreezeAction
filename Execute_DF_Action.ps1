Param(
    [Parameter(Mandatory=$true)]
    [string]$PC,

    [Parameter(Mandatory=$true)]
    [string]$DesiredState,

    [Parameter()]                              # ignore intellisense security warnings...
    [string]$EncryptedPasswordLocation = $null # this is the encryped pw location, not the pw

    [Parameter()]
    [string]$LogLocation = "C:\Temp\$PC-DeepFreeze.txt",

    [Parameter()]
    [bool]$Force = $false,

    [Parameter()]
    [int]$RebootTimeout = 60
)


function Log ($message) {
    $LogTime = Get-Date -DisplayHint Time
    $LogTime = $LogTime.ToString()
    Write-Output $message
    $LogStr = "$LogTime  -  $PC  -  $message"
    $LogStr | Out-File "$LogLocation" -Append
}

# measures success of the script
[bool]$ScriptResult = $false

function Quit {
    $script:ScriptResult = $false
    Log "DeepFreezeActionResult: $ScriptResult"
    Exit
    }


#### Verifications ####


if ($PSVersionTable.PSVersion.Major -lt 7) {
    $EncryptedPasswordLocation = $null
    Log "FATAL: Script requires Powershell 7 or above"
    Quit
}

if (!(Test-Connection -ComputerName $PC -Count 1)){
    Log "FATAL: $PC is not online or wrong name!"
    Quit
}


$CommandLookupTable = @{
                    'Frozen' = '/BOOTFROZEN';
                    'Thawed' = '/BOOTTHAWED';
                    'Thawed and Locked' = '/BOOTTHAWEDNOINPUT'            
}

if (!($DesiredState -in $CommandLookupTable.Keys)) {
    Log "FATAL: $DesiredState is not a valid state"
    Log "INFO: Valid States are $CommandLookupTable.Keys"
    Quit
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
    Quit
}
elseif ($null -eq $DFStatus) {
    Log "FATAL: No Deep Freeze detected on $PC"
    Quit
}


if ($Force -ne $true) {
    
    try {
        $LoggedInUser = (Get-CimInstance -Class win32_computersystem -ComputerName $PC).username -split '\\' | Select-Object -Last 1
    }
    catch {
        $LoggedInUser = $null
    }
    
    switch ($LoggedInUser) {
        $null { Log 'FATAL: Can not find logged-in user'; Quit }
        '' { Log "INFO: No one is logged in to $PC" }
        default { Log "WARNING: $LoggedInUser Logged in to $PC" }
    }
    

    $ProcessTable = @{
                    'Chrome' = 'Chrome';
                    'Firefox' = 'Firefox';
                    'Edge' = 'msedge';
                    'PowerPoint' = 'POWERPNT';
                    'Teams' = 'Teams';
                    'Zoom' = 'Zoom';
    }
    
    $AllProcesses = Invoke-Command -ComputerName $PC -ScriptBlock {
        Get-Process
    }

    $ProcessAlerts = @()
    foreach ($running_process in $AllProcesses) {
        foreach ($process_table_value in $ProcessTable.Values) {
            if ($process_table_value -like $running_process.ProcessName) {
                $FoundRunningProcess = $ProcessTable[$running_process.ProcessName]
                if ($FoundRunningProcess -in $ProcessAlerts) {
                    continue
                }
                else{
                    $ProcessAlerts += $FoundRunningProcess
                }
            }
        }
    }

    if ($ProcessAlerts.Count -gt 0) {
        Log "INFO: Found running process(es): $ProcessAlerts"
        Log 'FATAL: $Force set to $false and PC may be in use, exiting'
        Quit
    }
}


#### Load Password ####

if (Test-Path $EncryptedPasswordLocation) {
    $loadedEncryptedPassword = Get-Content -Path $EncryptedPasswordLocation
    $loadedSecureString = ConvertTo-SecureString -String $loadedEncryptedPassword
    $DF_Password = (New-Object PSCredential "user", $loadedSecureString).GetNetworkCredential().Password
}
else {
    Log "FATAL: Could not find encrypted password at $EncryptedPasswordLocation"
    Log "ERROR: Please run PasswordEncrypter.ps1 or fix the path"
    Quit
}


#### Send DF Commands ####

$Command = $CommandLookupTable[$DesiredState]

Log "INFO: Sending Command: $Command"
Log "INFO: Console may show an error when PC Reboots. This is normal"


Invoke-Command -ComputerName "$PC" -ScriptBlock{
    C:\Windows\SysWOW64\.\DFC.exe "$using:DF_Password" "$using:Command"
} # Command will hang while PC prepares to reboot, 
  # then will raise OpenError as connection is lost during the reboot


Log "INFO: Starting Sleep to wait for reboot"
Start-Sleep -Seconds $RebootTimeout


$TestAttempts = 0
function TestOnlineRecurse {
    if (!(Test-Connection -ComputerName $PC -Count 1)) {
        Log "WARNING: $PC not detected online.  Will try again in 15 seconds"
        $script:TestAttempts += 1
        Log "INFO: Ping Attempt $script:TestAttempts of 5"
        if ($script:TestAttempts -lt 5) {
            Start-Sleep -Seconds 15
            TestOnlineRecurse
        }
        else {
            Log "FATAL: $PC did not come back online"
            Quit
        }
    }
}
TestOnlineRecurse


#### Verify DF Status ####

$DFStatus =
Invoke-Command -ComputerName $PC -ScriptBlock {
    (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Faronics\Deep Freeze 6\" -Name "DF Status")."DF Status"
}

if ($DFStatus -eq $DesiredState) {
    $ScriptResult = $true
    Log "INFO: Sucessfully rebooted $DFStatus"
}
else {
    $ScriptResult = $false
    Log "WARNING: Could not verify operation.  State is $DFStatus, Desired State is $DesiredState"
    Log "INFO: Password may be wrong"
    Log 'INFO: PC must be frozen first in order to boot into Thawed or Thawed and Locked states'
}

# Don't change this formatting, it's read by main.py later on
Log "DeepFreezeActionResult: $ScriptResult"
