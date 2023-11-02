Param(
    [Parameter(Mandatory=$true)]
    [string]$PC,

    [Parameter(Mandatory=$true)]
    [string]$DesiredState,

    [Parameter(Mandatory = $true)]
    [string]$EncryptedPasswordLocation,

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
elseif ($DFStatus -eq $null) {
    Log "FATAL: No Deep Freeze detected on $PC"
    Quit
}


if ($Force -ne $true) {

    $LoggedInUser = $null
    $LoggedInUser = Get-CimInstance -Class win32_computersystem -ComputerName $PC | Select-Object username
    $LoggedInUser = $LoggedInUser -split '\\'
    $LoggedInUser = $LoggedInUser[1] -replace '}'


    if ($LoggedInUser -eq '') {
        Log "INFO: No one is logged in to $PC"
    }
    elseif ($null -eq $LoggedInUser) {
        Log 'FATAL: Can not find logged-in user'
        Quit
    }
    else {
        Log "WARNING: $LoggedInUser Logged in to $PC"
    }


    function GetRunningProcess ($process_name) {
        Invoke-Command -ComputerName $PC -ScriptBlock {
            try {
                Get-Process $using:process_name -ErrorAction Stop
            }
            catch {
                $false
            }
        }
    }


    $Chrome = GetRunningProcess 'Chrome'
    $Firefox = GetRunningProcess 'Firefox'
    $Edge = GetRunningProcess 'Edge'
    $PowerPoint = GetRunningProcess 'POWERPNT'
    $Teams = GetRunningProcess 'Teams'
    $Zoom = GetRunningProcess 'Zoom'

    $ProcessList = @(
        $Chrome, 
        $Firefox, 
        $Edge, 
        $PowerPoint, 
        $Teams, 
        $Zoom
    )


    foreach ($Process in $ProcessList) {
        if ($Process) {
            Log "FATAL: Something is Running! $PC May Be In Use! Stopping!"
            Log 'INFO: Set Param $Force to $true to ignore this warning'
            Quit
        }
    }
}


#### Load Password ####

$loadedEncryptedPassword = Get-Content -Path $EncryptedPasswordLocation
$loadedSecureString = ConvertTo-SecureString -String $loadedEncryptedPassword
$DF_Password = (New-Object PSCredential "user", $loadedSecureString).GetNetworkCredential().Password


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

Log "DeepFreezeActionResult: $ScriptResult"
